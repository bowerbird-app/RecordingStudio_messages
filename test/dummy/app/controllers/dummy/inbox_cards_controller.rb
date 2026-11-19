# frozen_string_literal: true

module Dummy
  class InboxCardsController < ApplicationController
    def show
      @actor = Current.actor || current_user
      @mount = DummyCatalog.inbox_mount_recording
    end
  end
end
