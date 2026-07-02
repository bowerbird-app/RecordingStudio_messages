# frozen_string_literal: true

module RecordingStudioMessages
  class RecipientsController < ApplicationController
    before_action :require_create_group_authorization!

    def index
      results = RecipientSearch.new(
        messages_config: messages_config,
        query: params[:q],
        actor: current_actor_record,
        container_recording: container_recording,
        controller: self
      ).results
      render json: { recipients: results }
    end
  end
end
