# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    class << self
      private

      def account_for(email)
        existing = RecordingStudioUser.config.user_class.find_by(email: email)
        return new_registration_account(email) if existing.nil?
        return registration_account(existing) unless existing.confirmed?
        return login_account(existing) if existing.active_for_authentication?

        raise Error, TAKEN_EMAIL
      end

      def new_registration_account(email)
        require_otp!(:registration)
        [RecordingStudioUser.create_unconfirmed_user!(email: email), "registration"]
      rescue ActiveRecord::RecordNotUnique
        raise Error, TAKEN_EMAIL
      end

      def registration_account(user)
        require_otp!(:registration)
        [user, "registration"]
      end

      def login_account(user)
        require_otp!(:login)
        [user, "login"]
      end

      def require_otp!(kind)
        return if otp_kind_enabled?(kind)

        raise Error, USERS_REQUIRED
      end

      def otp_kind_enabled?(kind)
        return RecordingStudioUser.config.otp_login_enabled? if kind == :login

        RecordingStudioUser.config.otp_registration_enabled?
      end

      def users_otp_ready?
        defined?(RecordingStudioUser) && RecordingStudioUser.config.otp_enabled?
      end

      def issue_otp!(user:, purpose:, request:, session:, rate_limit_scope:)
        call_users_otp do
          RecordingStudioUser.issue_otp!(
            user: user, purpose: purpose, request: request, session: session, rate_limit_scope: rate_limit_scope
          )
        end
      end

      def call_users_otp
        yield
      rescue RecordingStudioUser::RateLimited
        raise Error, RATE_LIMITED
      end
    end
  end
end
