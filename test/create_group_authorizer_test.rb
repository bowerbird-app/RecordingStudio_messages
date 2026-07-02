# frozen_string_literal: true

require "test_helper"

class CreateGroupAuthorizerTest < Minitest::Test
  FakeConfig = Struct.new(:key, :container_type, :authorization, keyword_init: true) do
    def effective_create_group_authorization = authorization
  end

  def test_default_container_access_calls_authorized_with_edit_role
    config = FakeConfig.new(key: :support, container_type: "SupportMessages", authorization: { type: :container_access, role: :edit })
    calls = []

    RecordingStudioAccessible.stub(:authorized?, ->(**kwargs) { calls << kwargs; true }) do
      assert RecordingStudioMessages::CreateGroupAuthorizer.new(
        messages_config: config,
        actor: :actor,
        container_recording: :recording
      ).authorized?
    end

    assert_equal [{ actor: :actor, recording: :recording, role: :edit }], calls
  end

  def test_action_mode_calls_authorized_action_with_context
    config = FakeConfig.new(
      key: :site,
      container_type: "SiteMessages",
      authorization: { type: :action, action: :"recording_studio_messages.create_group" }
    )
    calls = []

    RecordingStudioAccessible.stub(:authorized_action?, ->(**kwargs) { calls << kwargs; true }) do
      assert RecordingStudioMessages::CreateGroupAuthorizer.new(
        messages_config: config,
        actor: :actor,
        container_recording: :recording,
        controller: :controller
      ).authorized?
    end

    assert_equal :"recording_studio_messages.create_group", calls.first[:action]
    assert_equal({ messages_key: :site, container_type: "SiteMessages", child_type: "RecordingStudioMessages::MessageGroup" }, calls.first[:context])
  end

  def test_missing_action_policy_fails_closed
    config = FakeConfig.new(key: :site, container_type: "SiteMessages", authorization: { type: :action, action: :missing })

    RecordingStudioAccessible.stub(:authorized_action?, ->(**) { false }) do
      refute RecordingStudioMessages::CreateGroupAuthorizer.new(
        messages_config: config,
        actor: :actor,
        container_recording: :recording
      ).authorized?
    end
  end
end
