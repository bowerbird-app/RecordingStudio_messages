# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    SESSION_KEY = :recording_studio_messages_public_contact_intent_id
    TAKEN_EMAIL = "That email already has an account. Try signing in."
    RATE_LIMITED = "Give it a minute, then try again."
    USERS_REQUIRED = "Public contact needs Recording Studio Users email codes."
    NO_RECIPIENT = "Nobody can receive this message."

    Outcome = Struct.new(:intent, :group_recording, keyword_init: true) do
      def awaiting_verification?
        intent.present? && group_recording.blank?
      end
    end

    module_function

    def enabled?(mount_recording)
      return false if mount_recording.blank?
      return false unless mount_recording.recordable_type == MESSAGE_MOUNT_TYPE

      key = mount_recording.recordable&.key.to_s
      parent = mount_recording.parent_recording
      return false if key.blank? || parent.blank?

      public_contact_keys_for(parent.recordable_type).include?(key)
    end

    def begin(mount_recording:, name:, email:, body:, current_actor:, request:, session:)
      raise Error, "Public contact is not enabled on this mount." unless enabled?(mount_recording)

      text = normalize_body(body)
      if current_actor.present?
        group = fulfill!(
          mount: mount_recording,
          contact: current_actor,
          title: signed_in_title(current_actor),
          body: text,
          recipients: recipients_for(mount_recording, current_actor)
        )
        return Outcome.new(group_recording: group)
      end

      raise Error, USERS_REQUIRED unless users_otp_ready?

      submitted_name = normalize_name(name)
      normalized_email = normalize_email(email)
      user, purpose = account_for(normalized_email)
      recipients = recipients_for(mount_recording, user)
      raise Error, NO_RECIPIENT if opener_among(mount_recording, recipients).nil?

      issued = issue_otp!(user: user, purpose: purpose, request: request, session: session, rate_limit_scope: :issue)
      intent = PublicContactIntent.create!(
        mount_recording_id: mount_recording.id,
        user_id: user.id,
        otp_challenge_id: issued.challenge.id,
        email: normalized_email,
        submitted_name: submitted_name,
        body: text,
        expires_at: PublicContactIntent::LIFETIME.from_now
      )
      session[SESSION_KEY] = intent.id
      Outcome.new(intent: intent)
    end

    def submit_code!(intent:, code:, session:)
      return finish(intent, session) if intent.fulfilled?

      challenge = RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id)
      result = RecordingStudioUser.verify_otp!(
        challenge_id: intent.otp_challenge_id,
        code: code,
        purpose: challenge.purpose,
        session: session
      )
      unless result.success?
        intent.reload
        return finish(intent, session) if intent.fulfilled?

        raise Error, "That code did not match."
      end

      group = complete(intent: intent, actor: result.user)
      session.delete(SESSION_KEY)
      group
    end

    def resend!(intent:, request:, session:)
      intent.with_lock do
        raise Error, "That message was already sent." if intent.fulfilled?
        raise Error, "That contact form expired. Send it again." if intent.expired?

        user = RecordingStudioUser.config.user_class.find(intent.user_id)
        challenge = RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id)
        issued = issue_otp!(
          user: user,
          purpose: challenge.purpose,
          request: request,
          session: session,
          rate_limit_scope: :resend
        )
        intent.update!(otp_challenge_id: issued.challenge.id)
      end
      intent
    end

    def complete(intent:, actor:)
      intent.with_lock do
        raise NotAuthorized, "You cannot send this message." unless actor_matches?(intent, actor)
        return intent.group_recording if intent.fulfilled?
        raise Error, "That contact form expired. Send it again." if intent.expired? || !intent.open?

        challenge = consumed_challenge!(intent, actor)
        provision_registration!(actor, intent, challenge) if registration_profile?(actor, challenge)

        mount = RecordingStudio::Recording.find(intent.mount_recording_id)
        group = fulfill!(
          mount: mount,
          contact: actor,
          title: intent.submitted_name,
          body: intent.body,
          recipients: recipients_for(mount, actor)
        )
        intent.update!(message_group_id: group.id, body: nil)
        group
      end
    end

    class << self
      private

      def finish(intent, session)
        session.delete(SESSION_KEY)
        intent.group_recording
      end

      def users_otp_ready?
        defined?(RecordingStudioUser) && RecordingStudioUser.config.otp_enabled?
      end

      def account_for(email)
        existing = RecordingStudioUser.config.user_class.find_by(email: email)
        if existing.nil?
          require_otp!(:registration)
          begin
            return [RecordingStudioUser.create_unconfirmed_user!(email: email), "registration"]
          rescue ActiveRecord::RecordNotUnique
            raise Error, TAKEN_EMAIL
          end
        end

        if !existing.confirmed? && existing.registered_with_otp?
          require_otp!(:registration)
          return [existing, "registration"]
        end

        if existing.confirmed? && existing.active_for_authentication?
          require_otp!(:login)
          return [existing, "login"]
        end

        raise Error, TAKEN_EMAIL
      end

      def require_otp!(kind)
        enabled = if kind == :login
          RecordingStudioUser.config.otp_login_enabled?
        else
          RecordingStudioUser.config.otp_registration_enabled?
        end
        return if enabled

        raise Error, USERS_REQUIRED
      end

      def issue_otp!(user:, purpose:, request:, session:, rate_limit_scope:)
        RecordingStudioUser.issue_otp!(
          user: user,
          purpose: purpose,
          request: request,
          session: session,
          rate_limit_scope: rate_limit_scope
        )
      rescue RecordingStudioUser::Services::OtpRateLimiter::RateLimited
        raise Error, RATE_LIMITED
      end

      def fulfill!(mount:, contact:, title:, body:, recipients:)
        opener = opener_among(mount, recipients)
        raise Error, NO_RECIPIENT if opener.nil?

        group = nil
        ActiveRecord::Base.transaction do
          RecordingStudioMessages.allow_membership_change do
            group = RecordingStudioMessages.create_group(
              mount,
              title: title.to_s.truncate(120),
              actor: opener
            )
            # A second grant at :edit would replace the opener's :admin.
            grant_edit!(group, contact, opener) unless same_actor?(contact, opener)
            granted_ids = []
            Array(recipients).each do |recipient|
              next if same_actor?(recipient, opener) || same_actor?(recipient, contact)
              next if granted_ids.include?(recipient.id.to_s)

              grant_edit!(group, recipient, opener)
              granted_ids << recipient.id.to_s
            end
          end

          RecordingStudioMessages.send_message(
            group_recording: group,
            body: body,
            actor: contact,
            files: [],
            notify: true,
            url: RecordingStudioMessages::Engine.routes.url_helpers.message_group_path(group)
          )
        end
        group
      end

      def recipients_for(mount, actor)
        resolver = RecordingStudioMessages.configuration.public_contact_recipient_resolver
        return [] unless resolver.respond_to?(:call)

        Array(resolver.call(mount_recording: mount, actor: actor)).compact
      end

      def opener_among(mount, recipients)
        Array(recipients).find do |recipient|
          RecordingStudioAccessible.authorized?(actor: recipient, recording: mount, role: :admin)
        end
      end

      def grant_edit!(group, actor, manager)
        result = RecordingStudioAccessible.grant_access(
          recording: group,
          actor: actor,
          role: :edit,
          manager_actor: manager
        )
        return if result.success?

        raise Error, result.error.to_s
      end

      def consumed_challenge!(intent, actor)
        challenge = RecordingStudioUser::OtpChallenge.find_by(id: intent.otp_challenge_id)
        usable = challenge&.consumed? &&
                 !challenge.revoked? &&
                 challenge.user_id.to_s == actor.id.to_s &&
                 (challenge.registration? || challenge.login?)
        raise Error, "Confirm the email code first." unless usable

        challenge
      end

      def registration_profile?(actor, challenge)
        !actor.confirmed? && actor.registered_with_otp? && challenge.registration?
      end

      def provision_registration!(actor, intent, challenge)
        RecordingStudioUser.complete_registration!(user: actor, challenge: challenge)
        first_name, last_name = split_name(intent.submitted_name)
        RecordingStudioUser.record_profile!(
          actor,
          actor: actor,
          first_name: first_name,
          last_name: last_name,
          time_zone: "UTC"
        )
      end

      def split_name(submitted_name)
        first_name, last_name = submitted_name.to_s.strip.split(/\s+/, 2)
        [first_name.presence || "Member", last_name.presence || "Member"]
      end

      def actor_matches?(intent, actor)
        return false if actor.blank? || !actor.respond_to?(:id) || !actor.respond_to?(:email)

        actor.id.to_s == intent.user_id.to_s &&
          actor.email.to_s.strip.downcase == intent.email.to_s
      end

      def signed_in_title(actor)
        named = actor.name.to_s.strip if actor.respond_to?(:name)
        named = nil if named.blank?
        named ||= email_local_title(actor)
        (named.presence || "Message").truncate(120)
      end

      def email_local_title(actor)
        return unless actor.respond_to?(:email)

        actor.email.to_s.split("@").first.to_s.titleize.presence
      end

      def normalize_body(body)
        text = body.to_s.strip
        raise Error, "Write a message." if text.blank?
        raise Error, "That message is too long." if text.length > 10_000

        text
      end

      def normalize_name(name)
        submitted = name.to_s.strip
        raise Error, "Enter your name." if submitted.blank?
        raise Error, "That name is too long." if submitted.length > 120

        submitted
      end

      def normalize_email(email)
        normalized = email.to_s.strip.downcase
        local, domain = normalized.split("@", 2)
        invalid = normalized.blank? ||
                  normalized.count("@") != 1 ||
                  local.blank? ||
                  domain.blank? ||
                  !domain.include?(".")
        raise Error, "Enter an email address." if invalid

        normalized
      end

      def same_actor?(left, right)
        return false if left.blank? || right.blank?

        left.instance_of?(right.class) && left.id.to_s == right.id.to_s
      end

      def public_contact_keys_for(parent_type)
        options = RecordingStudio.capability_options(:messages, for: parent_type) || {}
        flag = options[:public_contact]
        return [] if flag.blank? || flag == false
        return Array(options[:keys] || options[:key]).map(&:to_s) if flag == true

        Array(flag).map(&:to_s)
      end
    end
  end
end
