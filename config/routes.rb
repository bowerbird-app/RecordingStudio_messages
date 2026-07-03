# frozen_string_literal: true

RecordingStudioMessages::Engine.routes.draw do
  root "home#index"

  scope "/messages/:messages_key" do
    resources :message_groups, only: %i[index new create show] do
      member do
        get :history
      end
      resources :messages, only: :create
    end
    resources :recipients, only: :index
  end
end
