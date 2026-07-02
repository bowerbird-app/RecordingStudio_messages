# frozen_string_literal: true

module RecordingStudioMessages
  class MessageHistoryPaginator
    attr_reader :page, :per_page

    def initialize(message_group_recording:, page: 1, per_page: nil)
      @message_group_recording = message_group_recording
      @page = [page.to_i, 1].max
      @per_page = (per_page || RecordingStudioMessages.configuration.message_page_size).to_i
    end

    def records
      @records ||= RecordingStudio::Recording.unscoped.where(
        parent_recording_id: @message_group_recording.id,
        recordable_type: "RecordingStudioMessages::Message"
      ).order(created_at: :desc).limit(per_page + 1).offset((page - 1) * per_page).includes(:recordable).to_a
    end

    def page_records = records.first(per_page).reverse
    def older_page = has_more? ? page + 1 : nil
    def has_more? = records.size > per_page
  end
end
