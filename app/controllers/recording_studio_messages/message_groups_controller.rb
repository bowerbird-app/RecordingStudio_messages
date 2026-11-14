# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupsController < ApplicationController
    include MessageGroupsRename

    PAGE_SIZE = 50

    rescue_from RecordingStudioMessages::NotAuthorized, with: :handle_not_authorized

    def index
      @mount_recording = find_mount_recording
      load_inbox
    end

    def show
      @group_recording = find_group_recording
      authorize_group!(:view)
      @mount_recording = @group_recording.parent_recording
      RecordingStudioMessages.mark_read(group_recording: @group_recording, actor: current_messages_actor)
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
      load_inbox(selected: @group_recording) unless turbo_frame_request?
      render layout: false if turbo_frame_request?
    end

    def create
      @mount_recording = find_mount_recording!
      authorize_start!
      redirect_to message_group_path(started_conversation), notice: Copy.t("flashes.sent")
    rescue RecordingStudioMessages::Error => e
      redirect_back_or_to(message_groups_path(mount_id: @mount_recording&.id), alert: e.message)
    end

    def contacts
      @mount_recording = find_mount_recording!
      authorize_start!
      contacts = RecordingStudioMessages::Contacts.search(
        mount: @mount_recording,
        actor: current_messages_actor,
        query: params[:q].to_s
      )
      render json: { items: contact_select_items(contacts) }
    end

    private

    def find_mount_recording
      return if params[:mount_id].blank?

      recording = RecordingStudio::Recording.find(params[:mount_id])
      raise ActiveRecord::RecordNotFound, "Desk not found" unless recording.recordable_type == MESSAGE_MOUNT_TYPE

      authorize_mount_parent!(recording)
      recording
    end

    def find_mount_recording!
      find_mount_recording || raise(ActiveRecord::RecordNotFound, "Desk not found")
    end

    def authorize_start!
      return if RecordingStudioMessages::Contacts.can_start?(
        mount: @mount_recording,
        actor: current_messages_actor
      )

      raise RecordingStudioMessages::NotAuthorized, Copy.t("errors.cannot_start")
    end

    def started_conversation
      RecordingStudioMessages.create_group(
        @mount_recording,
        title: conversation_params[:title],
        actor: current_messages_actor,
        recipients: submitted_recipients,
        body: conversation_params[:body]
      )
    end

    def conversation_params
      params.permit(:title, :body, :mount_id)
    end

    def submitted_recipients
      raw = params[:recipients]
      return [] if raw.blank?

      items = raw.is_a?(Array) ? raw : raw.to_unsafe_h.values
      items.filter_map { |item| submitted_recipient(item) }
    end

    def submitted_recipient(item)
      return if item.blank?
      return item if item.is_a?(String)

      permitted = item.respond_to?(:permit) ? item.permit(:type, :id) : item
      permitted.to_h.symbolize_keys
    end

    def contact_select_items(contacts)
      contacts.filter_map do |actor|
        next if actor.blank?

        { value: RecordingStudioMessages::Contacts.token(actor), label: helpers.message_sender_name(actor) }
      end
    end

    def authorize_mount_parent!(mount_recording)
      parent = mount_recording.parent_recording
      return if parent.present? && RecordingStudioAccessible.authorized?(
        actor: current_messages_actor,
        recording: parent,
        role: :view
      )

      raise ActiveRecord::RecordNotFound, "Messages mount not found"
    end

    def load_inbox(selected: nil)
      page = inbox_page
      @unread_filter = unread_filter?
      @older_href = older_href_for(page)
      @group_recordings = page
      @group_recording = selected || selected_group_from_params || first_ready_group
      return if @group_recording.blank?

      authorize_group!(:view)
      prepend_selected_row
      assign_thread_messages
    end

    def assign_thread_messages
      return if defined?(@message_recordings) && @message_recordings

      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    def inbox_page
      RecordingStudioMessages.viewable_group_recordings(
        actor: current_messages_actor,
        mount_recording: @mount_recording,
        unread: unread_filter?,
        after: after_recording,
        limit: PAGE_SIZE
      )
    end

    def unread_filter?
      ActiveModel::Type::Boolean.new.cast(params[:unread])
    end

    def after_recording
      raw = params[:after_id].presence
      return if raw.blank?

      recording = RecordingStudio::Recording.find_by(id: raw)
      return unless mount_member?(recording)

      recording
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def older_href_for(page)
      return if page.length < PAGE_SIZE

      query = { after_id: page.last.id, mount_id: @mount_recording&.id }
      query[:unread] = 1 if unread_filter?
      message_groups_path(query)
    end

    def selected_group_from_params
      id = params[:id].presence
      return if id.blank?

      @group_recordings.find { |group| group.id.to_s == id.to_s }
    end

    def prepend_selected_row
      return if @group_recording.blank?
      return if @group_recordings.any? { |group| group.id.to_s == @group_recording.id.to_s }
      return unless mount_member?(@group_recording)

      @group_recordings = [@group_recording] + @group_recordings
    end

    def mount_member?(recording)
      return false if @mount_recording.blank? || recording.blank?
      return false unless recording.recordable_type == MESSAGE_GROUP_TYPE
      return false unless recording.parent_recording_id == @mount_recording.id
      return false unless RecordingStudio::Recording.unscoped.kept.exists?(id: recording.id)

      RecordingStudioAccessible.authorized?(
        actor: current_messages_actor,
        recording: recording,
        role: :view
      )
    end

    def first_ready_group
      @group_recordings.find { |group| ready_inbox_group?(group) }
    end

    def ready_inbox_group?(group)
      group.recordable&.title.to_s.strip.present? &&
        RecordingStudioMessages.message_recordings(group).last.present?
    end
  end
end
