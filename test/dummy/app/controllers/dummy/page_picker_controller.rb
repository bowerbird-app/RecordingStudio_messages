# frozen_string_literal: true

module Dummy
  class PagePickerController < ApplicationController
    layout false

    def show
      @mount = find_mount
      return head :not_found if @mount.blank?

      @query = params[:q].to_s
      @pages = helpers.dummy_attachable_pages(actor: current_user, mount: @mount, query: @query)
    end

    private

    def find_mount
      mount = RecordingStudio::Recording.unscoped.find_by(id: params[:mount_id])
      return if mount.blank?
      return unless mount.recordable_type == RecordingStudioMessages::MESSAGE_MOUNT_TYPE
      return unless mount.recordable&.key.to_s == DummyCatalog::SUPPORT_KEY
      return unless RecordingStudioAccessible.authorized?(
        actor: current_user,
        recording: mount,
        role: :view
      )

      mount
    end
  end
end
