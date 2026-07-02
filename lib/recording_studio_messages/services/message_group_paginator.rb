# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupPaginator
    attr_reader :page, :per_page

    def initialize(messages_config:, actor:, container_recording:, page: 1)
      @messages_config = messages_config
      @actor = actor
      @container_recording = container_recording
      @page = [page.to_i, 1].max
      @per_page = (messages_config.page_size || RecordingStudioMessages.configuration.default_page_size).to_i
    end

    def records
      @records ||= MessageGroupFinder.new(
        messages_config: @messages_config,
        actor: @actor,
        container_recording: @container_recording,
        limit: per_page + 1,
        offset: (page - 1) * per_page
      ).groups
    end

    def page_records = records.first(per_page)
    def next_page = has_more? ? page + 1 : nil
    def has_more? = records.size > per_page
  end
end
