class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport
  include RecordingStudio::UsesDefaultLayout
  include HtmlRoundedTheme

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Devise keeps layouts/application. Every other host page uses core default layout.
  layout :application_layout

  before_action :authenticate_user!
  before_action :set_current_actor

  private

  def application_layout
    return "application" if devise_controller?

    "recording_studio/default_layout"
  end

  def set_current_actor
    Current.actor = current_user
  end
end
