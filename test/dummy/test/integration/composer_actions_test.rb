# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ComposerActionsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_actor = Current.actor
    @staff = User.create!(
      email: "composer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Ada Staff",
      confirmed_at: Time.current
    )
    Current.actor = @staff
    @workspace = Workspace.create!(name: "Composer #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @staff)
    @mount = @root.ensure_message_mount("support", actor: @staff)
    @group = RecordingStudioMessages.create_group(@mount, title: "Studio help", actor: @staff)
    @page = RecordingStudio.record!(
      action: "created",
      recordable: Page.create!(title: "Brand notes"),
      root_recording: @root,
      parent_recording: @root,
      actor: @staff
    ).recording
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "support desk plus menu includes the dummy attach-page item and picker" do
    sign_in @staff

    get recording_studio_messages.message_group_path(@group)

    assert_response :success
    assert_includes response.body, "Attach a page"
    assert_includes response.body, "Brand notes"
    assert_includes response.body, "messages-composer-action-attach_page"
    assert_includes response.body, "recording-studio-messages--composer"
  end

  test "composer post writes indexed references from hidden fields" do
    sign_in @staff

    assert_difference -> { RecordingStudioMessages::MessageReference.count }, +1 do
      post recording_studio_messages.message_group_messages_path(@group), params: {
        message: {
          body: "Check this page.",
          references: {
            "0" => {
              recording_id: @page.id,
              title: "Brand notes",
              url: "/pages/#{@page.id}"
            }
          }
        }
      }
    end

    message = RecordingStudioMessages.message_recordings(@group).last
    row = RecordingStudioMessages::MessageReference.find_by!(message_recording_id: message.id)
    assert_equal @page.id, row.target_recording_id
    assert_includes message.recordable.body, "Brand notes"
  end

  test "a referenced page renders as a card and http urls become links" do
    Current.actor = @staff
    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "See https://ok.example",
      actor: @staff,
      references: [{
        recording_id: @page.id,
        title: "Brand notes",
        url: "/pages/#{@page.id}"
      }],
      notify: false
    )
    lines = RecordingStudioMessages.message_recordings(@group)
    visible = RecordingStudioMessages.visible_message_references(lines, actor: @staff)
    assert visible.values.flatten.any?, "expected visible refs for staff, got #{visible.inspect}"

    sign_in @staff

    get recording_studio_messages.message_group_path(@group)

    assert_response :success
    assert_includes response.body, "Brand notes"
    assert_includes response.body, "fp-card"
    assert_includes response.body, "https://ok.example"
    assert_includes response.body, "noopener noreferrer nofollow"
  end
end
