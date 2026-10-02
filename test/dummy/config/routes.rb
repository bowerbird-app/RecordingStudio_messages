Rails.application.routes.draw do
  devise_for :users,
             skip: %i[sessions registrations passwords]

  recording_studio_user_auth_for :users

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Keep legacy links working by redirecting the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"
  mount RecordingStudioMessages::Engine, at: "/recording_studio_messages"
  mount RecordingStudioAccessible::Engine, at: "/recording_studio_accessible"
  mount RecordingStudioAccessible::Engine, at: "/admin/access", as: :recording_studio_admin_access
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
  mount RecordingStudioSiteSettings::Engine, at: "/recording_studio_site_settings"
  mount RecordingStudioTermsAndConditions::Engine, at: "/recording_studio_terms_and_conditions"
  mount RecordingStudioPublishable::Engine, at: "/", as: :recording_studio_publishable
  recording_studio_admin_for :admin, at: "/admin", root_section: :site_settings

  namespace :staff do
    resource :desk, only: :show
  end
  get "/inbox", to: "customer/inboxes#show", as: :inbox

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  mount RecordingStudioUser::Engine => RecordingStudioUser.config.mount_path, as: :recording_studio_users
end
