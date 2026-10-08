# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class CustomerI18nTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    sign_in @staff
  end

  test "language selector sits in the dummy top nav" do
    get "/"

    assert_response :success
    assert_select "form[action='/recording_studio_internationalization/locale']"
    assert_includes response.body, "English"
    assert_includes response.body, "Français"
    assert_select "html[lang='en']"
    assert_select ".dummy-language-selector"
    assert_select "nav.flat-pack-page-nav .dummy-language-selector"
  end

  test "contact form and conversation views stay English until the host locale changes" do
    sign_out @staff
    get recording_studio_messages.public_contact_path(mount_id: DummyCatalog.inbox_mount_recording.id)

    assert_response :success
    assert_includes response.body, "Send message"
    assert_includes response.body, "Name"
    assert_includes response.body, "Contact"
    assert_select "html[lang='en']"

    sign_in @staff
    get staff_desk_path

    assert_response :success
    assert_includes response.body, "Write a message"
    assert_includes response.body, "Studio help"
    assert_select "html[lang='en']"
  end

  test "dummy French locale renders the contact form and conversation views" do
    sign_out @staff
    switch_to_french

    get recording_studio_messages.public_contact_path(mount_id: DummyCatalog.inbox_mount_recording.id)

    assert_response :success
    assert_select "html[lang='fr']"
    assert_includes response.body, "Envoyer"
    assert_includes response.body, "Nom"
    refute_includes response.body, "Send message"

    post recording_studio_messages.public_contact_path(mount_id: DummyCatalog.inbox_mount_recording.id),
         params: { name: "", email: "ada@example.com", body: "Bonjour" }

    assert_response :unprocessable_entity
    assert_includes response.body, "Entrez votre nom."
    refute_includes response.body, "Enter your name."

    sign_in @staff
    switch_to_french
    get staff_desk_path

    assert_response :success
    assert_includes response.body, "Écrire un message"
    assert_includes response.body, "Studio help"
    refute_includes response.body, "Write a message"
  end

  test "public contact helper text overrides still win" do
    html = HomeController.render(
      inline: "<%= public_contact_form(@mount, title: 'Write to us', submit_label: 'Ship it') %>",
      assigns: { mount: DummyCatalog.inbox_mount_recording },
      layout: false
    )

    assert_includes html, "Write to us"
    assert_includes html, "Ship it"
    refute_includes html, "Send message"
  end

  private

  def switch_to_french
    patch "/recording_studio_internationalization/locale", params: { locale: "fr", return_to: "/" }
    follow_redirect!
  end
end
