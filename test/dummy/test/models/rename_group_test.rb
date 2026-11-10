# frozen_string_literal: true

require "test_helper"

class RenameGroupTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @group = DummyCatalog.support_group_recording
    Current.actor = @staff
  end

  teardown do
    Current.actor = nil
  end

  test "revises the conversation title instead of mutating the snapshot" do
    original = @group.recordable
    renamed = RecordingStudioMessages.rename_group(
      group_recording: @group,
      title: "  New name  ",
      actor: @staff
    )

    assert_equal "New name", renamed.recordable.title
    assert_not_equal original.id, renamed.recordable_id
    assert RecordingStudioMessages::MessageGroup.exists?(id: original.id)
    assert_equal "Studio help", original.reload.title
    assert_equal "updated", renamed.events.first.action
  end

  test "rejects a view-only actor" do
    viewer = User.create!(
      email: "rename-model-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Viewer",
      confirmed_at: Time.current
    )
    result = RecordingStudioAccessible.grant_access(
      recording: @group,
      actor: viewer,
      role: :view,
      manager_actor: @staff
    )
    raise result.error if result.failure?

    assert_raises(RecordingStudioMessages::NotAuthorized) do
      RecordingStudioMessages.rename_group(
        group_recording: @group,
        title: "Nope",
        actor: viewer
      )
    end
    assert_equal "Studio help", @group.reload.recordable.title
  end
end
