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

      def send_challenge!(email, request)
        result = RecordingStudioUser.start_otp_challenge!(request: request, email: email)
        return result if result.issued?
        raise Error, Copy.t("errors.rate_limited") if result.throttled?

        raise Error, Copy.t("errors.users_required")
      end
    end
  end
end
