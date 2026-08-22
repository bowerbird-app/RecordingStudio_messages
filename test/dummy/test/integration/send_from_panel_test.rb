# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SendFromPanelTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
  end

  test "staff can send a follow-up from the desk panel" do
    sign_in @staff
    group = DummyCatalog.support_group_recording

    assert_difference -> { RecordingStudioMessages.message_recordings(group).count }, +1 do
      post recording_studio_messages.message_group_messages_path(group), params: {
        message: { body: "Trying a quieter type scale next." },
        return_to: staff_desk_path
      }
    end

    assert_redirected_to "/staff/desk"
    follow_redirect!
    assert_includes response.body, "Trying a quieter type scale next."
    assert_includes response.body, "Sent."
  end

  test "staff send replaces the desk thread over turbo without a full visit" do
    sign_in @staff
    group = DummyCatalog.support_group_recording
    body = "The charcoal bubble should land in place."

    assert_difference -> { RecordingStudioMessages.message_recordings(group).count }, +1 do
      post recording_studio_messages.message_group_messages_path(group),
           params: {
             message: { body: body },
             return_to: staff_desk_path
           },
           as: :turbo_stream
    end

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(turbo-stream action="replace" target="conversation-#{group.id}-messages")
    assert_includes response.body, %(turbo-stream action="replace" target="conversation-#{group.id}-composer")
    assert_includes response.body, body
    refute_includes response.body, "Sent."
  end
end
