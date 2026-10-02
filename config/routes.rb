# frozen_string_literal: true

RecordingStudioMessages::Engine.routes.draw do
  resources :message_groups, only: %i[index show] do
    resources :messages, only: [:create]
  end

  get "/public_contact", to: "public_contacts#show", as: :public_contact
  post "/public_contact", to: "public_contacts#create"
  get "/public_contact/verify", to: "public_contacts#verify", as: :public_contact_verify
  post "/public_contact/verify", to: "public_contacts#submit_verification"
  post "/public_contact/resend", to: "public_contacts#resend", as: :public_contact_resend
  get "/public_contact/sent", to: "public_contacts#sent", as: :public_contact_sent
end
