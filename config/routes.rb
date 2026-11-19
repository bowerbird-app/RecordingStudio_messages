# frozen_string_literal: true

RecordingStudioMessages::Engine.routes.draw do
  resources :message_groups, only: %i[index show create] do
    get :contacts, on: :collection
    patch :rename, on: :member
    resources :messages, only: [:create]
  end

  resources :my_messages, only: %i[index show]

  get "/public_contact", to: "public_contacts#show", as: :public_contact
  post "/public_contact", to: "public_contacts#create"
  get "/public_contact/return", to: "public_contacts#finish", as: :public_contact_return
  post "/public_contact/return", to: "public_contacts#complete_return"
  get "/public_contact/sent", to: "public_contacts#sent", as: :public_contact_sent
end
