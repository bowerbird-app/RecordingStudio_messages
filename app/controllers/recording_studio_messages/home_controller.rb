# frozen_string_literal: true

module RecordingStudioMessages
  class HomeController < ApplicationController
    skip_before_action :set_messages_config, :set_current_actor, :set_container_recording

    def index
      head :ok
    end
  end
end
