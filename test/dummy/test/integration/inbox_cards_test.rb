# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class InboxCardsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @reader = User.find_by!(email: "jules@example.com")
  end

  test "staff sees a mine card and a team card side by side" do
    sign_in @staff
    get dummy_inbox_cards_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "[data-inbox-card=mine]", text: /My messages/
    assert_select "[data-inbox-card=mine]", text: /Studio help/
    assert_select "[data-inbox-card=mount]", text: /Team inbox/
    assert_select "[data-inbox-card=mount]", text: /Site inbox/
    assert_select "[data-inbox-card=mine] a[href=?]", recording_studio_messages.my_messages_path
    assert_select "[data-inbox-card=mount] a[href=?]",
                  recording_studio_messages.message_groups_path(mount_id: DummyCatalog.inbox_mount_recording.id)
    assert_select ".grid.md\\:grid-cols-2"
  end

  test "a person with only direct grants sees the mine card" do
    sign_in @reader
    get dummy_inbox_cards_path

    assert_response :success
    assert_select "[data-inbox-card=mine]", text: /Studio help/
    assert_select "[data-inbox-card=mount]", count: 0
    refute_includes response.body, "Team inbox"
    refute_includes response.body, "Did the press stills land?"
    refute_includes response.body, "Site inbox"
  end
end
