class HomeController < ApplicationController
  helper RecordingStudioMessages::PublicContactHelper

  def index
    @public_contact_mount = inbox_public_contact_mount
  end

  private

  def inbox_public_contact_mount
    mount = DummyCatalog.inbox_mount_recording
    mount if RecordingStudioMessages.public_contact_enabled?(mount)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
