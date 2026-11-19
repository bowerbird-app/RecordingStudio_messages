# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    class << self
      private

      def account_for(email)
        existing = RecordingStudioUser.config.user_class.find_by(email: email)
        return new_registration_account(email) if existing.nil?
        return registration_account(existing) if registration_pending?(existing)
        return login_account(existing) if existing.confirmed? && existing.active_for_authentication?
        raise Error, Copy.t("errors.confirm_email") unless existing.confirmed?

        raise Error, Copy.t("errors.taken_email")
      end

      def registration_pending?(user)
        user.respond_to?(:registered_with_otp?) && user.registered_with_otp? && !user.confirmed?
      end

      def new_registration_account(email)
        require_otp!(:registration)
        RecordingStudioUser.create_unconfirmed_user!(email: email)
      rescue ActiveRecord::RecordNotUnique
        raise Error, Copy.t("errors.taken_email")
      end

      def registration_account(user)
        require_otp!(:registration)
        user
      end

      def login_account(user)
        require_otp!(:login)
        user
      end

      def require_otp!(kind)
        return if otp_kind_enabled?(kind)

        raise Error, Copy.t("errors.users_required")
      end

      def otp_kind_enabled?(kind)
        return RecordingStudioUser.config.otp_login_enabled? if kind == :login

        RecordingStudioUser.config.otp_registration_enabled?
      end

      def users_otp_ready?
        defined?(RecordingStudioUser) &&
          RecordingStudioUser.respond_to?(:start_otp_challenge!) &&
          RecordingStudioUser.config.otp_enabled?
      end

      def send_challenge!(email, request, source: nil)
        result = RecordingStudioUser.start_otp_challenge!(**challenge_arguments(email, request, source))
        return result if result.issued?
        raise Error, Copy.t("errors.rate_limited") if result.throttled?

        raise Error, Copy.t("errors.users_required")
      end

      def challenge_arguments(email, request, source)
        arguments = { request: request, email: email }
        arguments[:source] = source if !source.nil? && users_accepts?(:start_otp_challenge!, :source)
        arguments
      end

      def users_accepts?(method_name, keyword)
        method = RecordingStudioUser.method(method_name)
        return true if listed_keyword?(method, keyword)
        return false unless method.parameters.any? { |kind, _name| kind == :keyrest }

        users_signup_source?
      end

      def listed_keyword?(method, keyword)
        method.parameters.any? { |kind, name| name == keyword && %i[key keyreq].include?(kind) }
      end

      def users_signup_source?
        version = Gem.loaded_specs["recording_studio_user"]&.version
        version.present? && version >= Gem::Version.new("0.39.0")
      end
    end
  end
end
