Rails.application.routes.draw do
  devise_for :users

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Keep legacy links working by redirecting the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"
  mount RecordingStudioMessages::Engine, at: "/recording_studio_messages"
  mount RecordingStudioAccessible::Engine, at: "/recording_studio_accessible"
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"

  namespace :staff do
    resource :desk, only: :show
  end
  get "/inbox", to: "customer/inboxes#show", as: :inbox

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
