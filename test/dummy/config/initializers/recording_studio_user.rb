# frozen_string_literal: true

# Route configuration must load before Rails draws routes.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/recording_studio_users"
  config.profile_route_path = "profile"
  config.admin_route_path = "admin"
  # Profile and sign-in-method screens are product pages, so they use core's
  # default layout. The gem's auth screens keep their own centered layout.
  config.layout = "recording_studio/default_layout"
  config.additional_profile_attributes = []
  config.require_password_confirmation = false
  # Devise login page heading (host sessions#new). Default "Welcome back".
  # config.login_title = "Welcome back"
  # OmniAuth. Leave this empty: Continue-with buttons appear only for providers
  # whose secrets are present in Rails credentials (`omniauth:`). Commented or
  # blank credential keys stay hidden. Do not use ENV or OmniAuth test mode in
  # the app. Add the YAML below with `bin/rails credentials:edit`.
  #
  # omniauth:
  #   google_oauth2:
  #     client_id: your-google-client-id
  #     client_secret: your-google-client-secret
  #   microsoft_graph:
  #     client_id: your-microsoft-client-id
  #     client_secret: your-microsoft-client-secret
  #   apple:
  #     client_id: your-apple-client-id
  #     client_secret: ""
  #     team_id: your-apple-team-id
  #     key_id: your-apple-key-id
  #     pem: |
  #       -----BEGIN PRIVATE KEY-----
  #       ...
  #       -----END PRIVATE KEY-----
  #   linkedin:
  #     client_id: your-linkedin-client-id
  #     client_secret: your-linkedin-client-secret
  #   instagram:
  #     client_id: your-instagram-client-id
  #     client_secret: your-instagram-client-secret
  #
  # Email caveats (Users requires email on first login — MissingEmailError fail-closed):
  # - Automatic matching-email links reject provider emails explicitly marked unverified.
  #   If User supports Devise Confirmable, the existing email must also be confirmed.
  # - Instagram often returns no email. Connect while signed in still works; do not invent emails.
  # - Apple may send email only once (or a private relay). Later visits match Identity by uid.
  # Instagram uses omniauth-instagram-api (Instagram Login client id/secret).
  # Apple often uses client_secret: "" with team_id / key_id / pem options.
  config.omniauth_providers = {}
  # When false, unknown provider emails do not create a User (fail closed).
  config.omniauth_create_account = true
  # Optional email OTP. Leave false unless the host has run OTP migrations
  # and installed recording_studio_notifications.
  config.otp_enabled = false
end

# Host Devise must skip sessions/registrations/passwords and mount Users auth.
# Add the omniauth_callbacks controller only when OmniAuth providers are
# configured and User is :omniauthable.
#   devise_for :users,
#              skip: %i[sessions registrations passwords]
#   recording_studio_user_auth_for :users
#
# Register RecordingStudioUser::People and RecordingStudioUser::Profile in
# RecordingStudio.configure { |c| c.recordable_types = [...] }, then run:
#   bin/rails generate recording_studio_user:migrations
#   bin/rails db:migrate
