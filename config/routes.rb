# frozen_string_literal: true

RecordingStudioMessages::Engine.routes.draw do
  resources :message_groups, only: [:show] do
    resources :messages, only: [:create]
  end
end
