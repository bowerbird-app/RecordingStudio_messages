# frozen_string_literal: true

require "test_helper"

class InboxPageTest < ActiveSupport::TestCase
  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Owner"
    )
    @viewer = User.create!(
      email: "viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Viewer"
    )
    Current.actor = @owner
    @mount = support_mount
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "latest message, actors, and readiness match per-group lookups" do
    groups = Array.new(3) do |index|
      group = RecordingStudioMessages.create_group(@mount, title: "Ready #{index}", actor: @owner)
      grant_view!(group, @viewer)
      RecordingStudioMessages.send_message(
        group_recording: group,
        body: "Line #{index}",
        actor: @owner,
        notify: false
      )
      group
    end
    page = RecordingStudioMessages::Services::InboxPage.new(groups)

    groups.each do |group|
      expected_latest = RecordingStudioMessages.message_recordings(group).last
      expected_actors = RecordingStudioMessages.granted_actors(group).map(&:id).sort

      assert_equal expected_latest.id, page.latest_for(group).id
      assert_equal expected_actors, page.actors_for(group).map(&:id).sort
      assert page.ready?(group)
    end
  end

  test "query count stays flat as the page grows" do
    groups = Array.new(4) do |index|
      group = RecordingStudioMessages.create_group(@mount, title: "Q#{index}", actor: @owner)
      grant_view!(group, @viewer)
      RecordingStudioMessages.send_message(
        group_recording: group,
        body: "Body #{index}",
        actor: @owner,
        notify: false
      )
      group
    end

    snapshot_query_count(groups.take(2))
    small = snapshot_query_count(groups.take(2))
    large = snapshot_query_count(groups)

    assert_equal small, large
  end

  private

  def support_mount
    workspace = Workspace.create!(name: "Inbox page #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
    raise result.error if result.failure?

    root.ensure_message_mount("support", actor: @owner)
  end

  def grant_view!(recording, actor)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :view,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end

  def snapshot_query_count(groups)
    count = 0
    callback = lambda do |*_args, payload|
      name = payload[:name].to_s
      next unless name.end_with?(" Load")
      next if name.include?("SCHEMA")
      next if name == "CACHE"

      count += 1
    end
    page = nil
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      page = RecordingStudioMessages::Services::InboxPage.new(groups)
      groups.each do |group|
        page.latest_for(group)
        page.actors_for(group)
        page.ready?(group)
      end
    end
    count
  end
end
