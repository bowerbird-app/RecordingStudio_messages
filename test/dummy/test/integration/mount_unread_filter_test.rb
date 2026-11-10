# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class MountUnreadFilterTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
    @mount = DummyCatalog.support_mount_recording
  end

  test "mount inbox unread filter lists only unread conversations on that mount" do
    Current.actor = @staff
    unread = seeded_unread_conversation("Still unread")
    read = seeded_unread_conversation("Already opened")
    RecordingStudioMessages.mark_read(group_recording: read, actor: @staff)
    elsewhere = seeded_unread_conversation("Other desk", mount: DummyCatalog.inbox_mount_recording)

    sign_in @staff
    get recording_studio_messages.message_groups_path(mount_id: @mount.id, unread: 1)

    assert_response :success
    assert_includes response.body, "Still unread"
    refute_includes response.body, "Already opened"
    refute_includes response.body, "Other desk"
    refute_includes response.body, elsewhere.recordable.title
    assert_select "a[href=?][data-turbo-frame=?]",
                  recording_studio_messages.message_group_path(unread),
                  "messages-desk-panel"
    assert_select "a[aria-label=?][title=?][aria-current=page]",
                  "Show all",
                  "Show all"
    assert_select "svg[data-flat-pack--icon-name-value=?][data-flat-pack--icon-variant-value=?]",
                  "bell-alert",
                  "solid"
  end

  test "mount unread toggle drops after_id, keeps other query params, and stays on the mount" do
    sign_in @staff
    get recording_studio_messages.message_groups_path(
      mount_id: @mount.id,
      after_id: DummyCatalog.support_group_recording.id,
      foo: "1"
    )

    assert_response :success
    assert_select "a[aria-label=?][href*='unread=1']", "Show unread only"
    assert_select "a[aria-label=?][href*='foo=1']", "Show unread only"
    assert_select "a[aria-label=?][href*='mount_id=#{@mount.id}']", "Show unread only"
    refute_select "a[aria-label=?][href*='after_id']", "Show unread only"
  end

  test "full html show keeps the unread param on the list toggle" do
    Current.actor = @staff
    unread = seeded_unread_conversation("Open unread")

    sign_in @staff
    get recording_studio_messages.message_group_path(unread, unread: 1, mount_id: @mount.id)

    assert_response :success
    assert_includes response.body, "Open unread"
    assert_select "a[aria-label=?]", "Show all"
    refute_select "a[aria-label=?][href*='unread=1']", "Show all"
    assert_select "turbo-frame#messages-desk-panel"
  end

  test "after_id paging while filtered stays on unread conversations for that mount" do
    Current.actor = @staff
    older = seeded_unread_conversation("Older unread")
    newer = seeded_unread_conversation("Newer unread")
    stamp_last_message_at!(older, Time.zone.parse("2026-06-01 12:00:00"))
    stamp_last_message_at!(newer, Time.zone.parse("2026-06-01 13:00:00"))
    RecordingStudioMessages.mark_read(
      group_recording: DummyCatalog.support_group_recording,
      actor: @staff
    )
    RecordingStudioMessages.mark_read(
      group_recording: DummyCatalog.launch_group_recording,
      actor: @staff
    )

    sign_in @staff
    get recording_studio_messages.message_groups_path(
      mount_id: @mount.id,
      unread: 1,
      after_id: newer.id
    )

    assert_response :success
    assert_includes response.body, "Older unread"
    refute_includes response.body, "Newer unread"
    assert_select "a[aria-label=?]", "Show all"
  end

  private

  def seeded_unread_conversation(title, mount: @mount)
    group = RecordingStudioMessages.create_group(mount, title: title, actor: @staff)
    grant_view!(group, @customer)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: "#{title} body",
      actor: @customer,
      notify: false
    )
    group
  end

  def grant_view!(recording, actor)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :edit,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  def stamp_last_message_at!(recording, time)
    RecordingStudioMessages::MessageGroup.unscoped.where(id: recording.recordable_id).update_all(
      last_message_at: time
    )
    recording.recordable.reload
  end
end
