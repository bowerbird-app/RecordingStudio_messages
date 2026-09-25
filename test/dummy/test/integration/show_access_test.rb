# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ShowAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
  end

  test "default panel header still renders access control markup" do
    sign_in @staff
    get recording_studio_messages.message_group_path(DummyCatalog.empty_group_recording)

    assert_response :success
    assert_includes response.body, "+ Access"
  end

  test "show_access false omits plus access and avatars from the panel header" do
    Current.actor = @staff

    empty_group = DummyCatalog.empty_group_recording
    support_group = DummyCatalog.support_group_recording

    empty_shown = render_panel(empty_group, show_access: true)
    empty_hidden = render_panel(empty_group, show_access: false)
    support_shown = render_panel(support_group, show_access: true)
    support_hidden = render_panel(support_group, show_access: false)

    assert_includes empty_shown, "+ Access"
    refute_includes empty_hidden, "+ Access"

    assert_includes support_shown, "Manage access"
    refute_includes support_hidden, "+ Access"
    refute_includes support_hidden, "Manage access"
    refute_match(/flat-pack--avatar/i, support_hidden)
  end

  private

  def render_panel(group_recording, show_access:)
    RecordingStudioMessages::MessageGroupsController.render(
      partial: "recording_studio_messages/message_groups/panel",
      locals: {
        group_recording: group_recording,
        message_recordings: RecordingStudioMessages.message_recordings(group_recording),
        current_actor: @staff,
        show_access: show_access
      }
    )
  end
end
