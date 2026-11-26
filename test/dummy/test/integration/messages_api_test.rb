# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class MessagesApiTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = user("owner")
    @editor = user("editor")
    @viewer = user("viewer")
    @stranger = user("stranger")
    Current.actor = @owner
    @workspace = owned_root(Workspace.create!(name: "Studio Workspace"))
    @other = owned_root(Workspace.create!(name: "Other message center #{SecureRandom.hex(4)}"), actor: @stranger)
    @mount = @workspace.ensure_message_mount("support", actor: @owner)
    @other_mount = @other.ensure_message_mount("support", actor: @stranger)
    @mailbox = Mailbox.create!(name: "Press desk #{SecureRandom.hex(3)}")
    @mailbox_recording = RecordingStudio.record!(
      action: "created",
      recordable: @mailbox,
      root_recording: @workspace,
      parent_recording: @workspace,
      actor: @owner
    ).recording
    @inbox = @mailbox_recording.ensure_message_mount("inbox", actor: @owner)
    @group = RecordingStudioMessages.create_group(@mount, title: "API thread", actor: @owner)
    @inbox_group = RecordingStudioMessages.create_group(@inbox, title: "Press thread", actor: @owner)
    @other_group = RecordingStudioMessages.create_group(@other_mount, title: "Elsewhere", actor: @stranger)
    RecordingStudioMessages.send_message(
      group_recording: @group, body: "Hello from the message center.", actor: @owner, notify: false
    )
    RecordingStudioMessages.send_message(
      group_recording: @inbox_group, body: "Hello from the press desk.", actor: @owner, notify: false
    )
    @editor_access = grant!(@workspace, @editor, :edit)
    @viewer_access = grant!(@workspace, @viewer, :view)
    @editor_token, @editor_client = token_for(@editor_access)
    @viewer_token, @viewer_client = token_for(@viewer_access)
    @admin_token, @admin_client = token_for(owner_access, role: :admin)
  end

  teardown { Current.actor = @previous_actor }

  test "support reply goes through send_message and stays on that mount" do
    sent = call(:post, "/support/conversations/#{@group.id}/send_message", @editor_token, body: "Quiet crop on the way.")
    assert_response :success, response.body
    assert_equal "Quiet crop on the way.", sent.fetch("body")
    assert_equal @group.id, sent.fetch("parent_id")
    assert_equal "Quiet crop on the way.", RecordingStudioMessages.message_recordings(@group).last.recordable.body

    call(:post, "/support/conversations/#{@inbox_group.id}/send_message", @editor_token, body: "Wrong mount")
    assert_response :not_found, response.body
    call(:get, "/support/conversations/#{@other_group.id}/messages", @editor_token)
    assert_response :not_found, response.body
  end

  test "support list and press list stay on their own message centers" do
    listed = call(:get, "/support/conversations", @editor_token)
    assert_response :success, response.body
    ids = listed.fetch("records").map { |row| row.fetch("id") }
    assert_includes ids, @group.id
    refute_includes ids, @inbox_group.id

    press = call(:get, "/press_centers/#{@mailbox_recording.id}/conversations", @editor_token)
    assert_response :success, response.body
    press_ids = press.fetch("records").map { |row| row.fetch("id") }
    assert_includes press_ids, @inbox_group.id
    refute_includes press_ids, @group.id
  end

  test "list read and send return created_at as UTC ISO 8601" do
    listed = call(:get, "/support/conversations", @editor_token)
    assert_response :success, response.body
    conversation = listed.fetch("records").find { |row| row.fetch("id") == @group.id }
    assert_utc_iso8601 conversation.fetch("created_at"), @group.created_at

    thread = call(:get, "/support/conversations/#{@group.id}/messages", @editor_token)
    assert_response :success, response.body
    message = RecordingStudioMessages.message_recordings(@group).last
    row = thread.fetch("records").find { |record| record.fetch("id") == message.id }
    assert_utc_iso8601 row.fetch("created_at"), message.created_at

    sent = call(
      :post, "/support/conversations/#{@group.id}/send_message", @editor_token, body: "Timestamp check."
    )
    assert_response :success, response.body
    sent_message = RecordingStudioMessages.message_recordings(@group).last
    assert_equal "Timestamp check.", sent.fetch("body")
    assert_utc_iso8601 sent.fetch("created_at"), sent_message.created_at
  end

  test "support list pages after_id without overlap" do
    page_size = RecordingStudioMessages::MessageGroupsController::PAGE_SIZE
    extra = Array.new(page_size) do |index|
      group = RecordingStudioMessages.create_group(@mount, title: "Page #{index} #{SecureRandom.hex(2)}", actor: @owner)
      RecordingStudioMessages.send_message(group_recording: group, body: "Line #{index}", actor: @owner, notify: false)
      group
    end

    default_page = call(:get, "/support/conversations", @editor_token)
    assert_response :success, response.body
    default_ids = default_page.fetch("records").map { |row| row.fetch("id") }
    assert_equal page_size, default_ids.size
    assert_equal default_ids.last, default_page.fetch("after_id")

    clamped = call(:get, "/support/conversations", @editor_token, limit: page_size + 25)
    assert_response :success, response.body
    assert_equal default_ids, clamped.fetch("records").map { |row| row.fetch("id") }

    page_one = call(:get, "/support/conversations", @editor_token, limit: 2)
    first_ids = page_one.fetch("records").map { |row| row.fetch("id") }
    assert_equal 2, first_ids.size
    assert_nil page_one.fetch("after_id")

    page_two = call(:get, "/support/conversations", @editor_token, limit: 2, after_id: first_ids.last)
    second_ids = page_two.fetch("records").map { |row| row.fetch("id") }
    assert_empty first_ids & second_ids
    assert_includes(extra.map(&:id) + [@group.id], first_ids.first)

    zero = call(:get, "/support/conversations", @editor_token, limit: 0)
    assert_equal 1, zero.fetch("records").size
  end

  test "press center reads sends renames and marks read through the parent id" do
    thread = call(
      :get, "/press_centers/#{@mailbox_recording.id}/messages", @editor_token, conversation_id: @inbox_group.id
    )
    assert_response :success, response.body
    assert_includes thread.fetch("records").map { |row| row["body"] }, "Hello from the press desk."

    sent = call(
      :post, "/press_centers/#{@mailbox_recording.id}/send_message", @editor_token,
      conversation_id: @inbox_group.id, body: "A line for the desk."
    )
    assert_response :success, response.body
    assert_equal "A line for the desk.", sent.fetch("body")

    renamed = call(
      :post, "/press_centers/#{@mailbox_recording.id}/rename_group", @editor_token,
      conversation_id: @inbox_group.id, title: "Renamed press thread"
    )
    assert_response :success, response.body
    assert_equal "Renamed press thread", renamed.fetch("title")
    assert_equal "Renamed press thread", @inbox_group.reload.recordable.title

    marked = call(
      :post, "/press_centers/#{@mailbox_recording.id}/mark_read", @editor_token, conversation_id: @inbox_group.id
    )
    assert_response :success, response.body
    assert_equal @inbox_group.id, marked.fetch("id")

    call(:post, "/support/conversations/#{@group.id}/rename_group", @editor_token, title: "Nope")
    assert_response :not_found, response.body
  end

  test "open request and start conversation go through create_group" do
    created = call(:post, "/support/conversations", @admin_token, title: "New API request")
    assert_response :success, response.body
    assert_equal "New API request", created.fetch("title")
    assert_equal @mount.id, created.fetch("parent_id")

    press = call(
      :post, "/press_centers/#{@mailbox_recording.id}/conversations", @editor_token,
      title: "New press conversation",
      body: "Opening line.",
      recipients: [ { type: "User", id: @viewer.id.to_s } ]
    )
    assert_response :success, response.body
    assert_equal @inbox.id, press.fetch("parent_id")
    assert_equal "Opening line.", first_message_body(press.fetch("id"))
  end

  test "press center start rejects a missing list, an empty list, and a missing body" do
    path = "/press_centers/#{@mailbox_recording.id}/conversations"
    person = { type: "User", id: @viewer.id.to_s }

    started = call(:post, path, @editor_token, body: "The first line.", recipients: [person])
    assert_response :success, response.body
    assert_equal @inbox.id, started.fetch("parent_id")
    assert_equal "The first line.", first_message_body(started.fetch("id"))

    assert_no_difference -> { groups_under(@inbox) } do
      missing = call(:post, path, @editor_token, title: "Dropped", body: "Do not save this.")
      assert_response :unprocessable_entity, missing.to_s
      assert_includes response.body, "Pick who this goes to."

      empty = call(:post, path, @editor_token, body: "Do not save this.", recipients: [])
      assert_response :unprocessable_entity, empty.to_s
      assert_includes response.body, "Pick who this goes to."

      no_body = call(:post, path, @editor_token, title: "No opening line", recipients: [person])
      assert_response :unprocessable_entity, no_body.to_s
      assert_includes response.body, "Write a message."

      denied = call(:post, path, @viewer_token, body: "Nope.", recipients: [person])
      assert_response :forbidden, denied.to_s
    end
  end

  test "support still opens a title-only request and rejects a body with no recipients" do
    opened = call(:post, "/support/conversations", @admin_token, title: "Title only request")
    assert_response :success, response.body
    assert_equal "Title only request", opened.fetch("title")
    assert_empty RecordingStudioMessages.message_recordings(RecordingStudio::Recording.find(opened.fetch("id")))

    assert_no_difference -> { groups_under(@mount) } do
      dropped = call(
        :post, "/support/conversations", @admin_token, title: "Needs people", body: "The request text."
      )
      assert_response :unprocessable_entity, dropped.to_s
      assert_includes response.body, "Pick who this goes to."
    end
  end

  test "unread count follows the conversation list for that message center" do
    support_unread = RecordingStudioMessages.viewable_group_recordings(
      actor: @editor_client, mount_recording: @mount, unread: true
    )
    inbox_unread = RecordingStudioMessages.viewable_group_recordings(
      actor: @editor_client, mount_recording: @inbox, unread: true
    )

    support_count = call(:get, "/support/unread_count", @editor_token)
    inbox_count = call(:get, "/press_centers/#{@mailbox_recording.id}/unread_count", @editor_token)
    assert_response :success, response.body
    assert_equal support_unread.size, support_count.fetch("unread_count")
    assert_equal inbox_unread.size, inbox_count.fetch("unread_count")
    assert_includes support_unread.map(&:id), @group.id
    refute_includes support_unread.map(&:id), @inbox_group.id
    assert_includes inbox_unread.map(&:id), @inbox_group.id
    marked = call(:post, "/support/conversations/#{@group.id}/mark_read", @editor_token)
    assert_response :success, response.body
    assert_equal @group.id, marked.fetch("id")
    after = call(:get, "/support/unread_count", @editor_token)
    assert_equal support_unread.size - 1, after.fetch("unread_count")
  end

  test "view can read and cannot reply open or rename" do
    call(:get, "/support/conversations", @viewer_token)
    assert_response :success, response.body
    call(:get, "/support/conversations/#{@group.id}/messages", @viewer_token)
    assert_response :success, response.body
    call(:post, "/support/conversations/#{@group.id}/mark_read", @viewer_token)
    assert_response :success, response.body
    call(:get, "/support/unread_count", @viewer_token)
    assert_response :success, response.body

    call(:post, "/support/conversations/#{@group.id}/send_message", @viewer_token, body: "Nope")
    assert_response :forbidden, response.body
    call(:post, "/support/conversations", @viewer_token, title: "Nope")
    assert_response :forbidden, response.body
    call(
      :post, "/press_centers/#{@mailbox_recording.id}/rename_group", @viewer_token,
      conversation_id: @inbox_group.id, title: "Nope"
    )
    assert_response :forbidden, response.body
  end

  test "a wrong type a trashed conversation and a missing parent are not found" do
    call(:get, "/support/conversations/#{@mount.id}/messages", @editor_token)
    assert_response :not_found, response.body
    call(:get, "/press_centers/#{@group.id}/conversations", @editor_token)
    assert_response :not_found, response.body

    @group.update_columns(trashed_at: Time.current)
    call(:get, "/support/conversations/#{@group.id}/messages", @editor_token)
    assert_response :not_found, response.body
  end

  test "bad input is unprocessable and a shared mount key is rejected" do
    call(:post, "/support/conversations/#{@group.id}/send_message", @editor_token, body: "")
    assert_response :unprocessable_entity, response.body
    call(:post, "/support/conversations", @editor_token, title: "")
    assert_response :unprocessable_entity, response.body
    call(
      :post, "/press_centers/#{@mailbox_recording.id}/rename_group", @editor_token,
      conversation_id: @inbox_group.id, title: ""
    )
    assert_response :unprocessable_entity, response.body
    call(:get, "/support/conversations", @editor_token, after_id: @other_group.id)
    assert_response :unprocessable_entity, response.body
    assert_includes response.body, "after_id is not a conversation on this message center"
    call(:get, "/press_centers/#{@mailbox_recording.id}/messages", @editor_token)
    assert_response :unprocessable_entity, response.body

    RecordingStudioMessages::Api.place(
      api: :public, at: :shared_support, mount: :support, actions: %i[list_conversations]
    )
    shared = call(:get, "/shared_support/conversations", @editor_token)
    assert_response :unprocessable_entity, response.body
    assert_includes shared.fetch("error").fetch("message"), "Mount key support matches"
  end

  test "placed endpoints replace the blanket registration" do
    refute RecordingStudioApi.registered_endpoint(:messages_send_message)
    refute RecordingStudioApi.registered_endpoint(:messages_unread_count)
    message = RecordingStudioMessages.message_recordings(@group).last
    [message, @group, @mount].each do |recording|
      registration = RecordingStudioApi.recordable_registration_for(recording.recordable_type)
      assert_equal %i[show], registration.operations
      %i[create update destroy].each do |operation|
        refute registration.supports_operation?(operation)
      end
    end

    refused = call(:post, "/messages", @editor_token, parent_id: @group.id, body: "Sneaked in.")
    assert_response :unprocessable_entity, response.body
    assert_equal "unsupported_action", refused.dig("error", "code")
    call(:patch, "/messages/#{message.id}", @editor_token, body: "Rewritten")
    assert_response :unprocessable_entity, response.body
    call(:delete, "/messages/#{message.id}", @editor_token)
    assert_response :unprocessable_entity, response.body

    reply = RecordingStudioApi.registered_endpoint(:support_reply)
    listed = RecordingStudioApi.registered_endpoint(:press_centers_list_conversations)
    assert_equal ["Support"], reply.openapi_tags
    assert_equal "Reply", reply.openapi.fetch(:title)
    assert_equal "support/conversations/:id/send_message", reply.path
    marked = RecordingStudioApi.registered_endpoint(:press_centers_mark_read)
    counted = RecordingStudioApi.registered_endpoint(:press_centers_unread_count)
    assert_equal ["Press Center Messages"], listed.openapi_tags
    assert_equal({ group: "Press Center" }, listed.openapi[:tag])
    assert_equal "Mark conversation read", marked.openapi.fetch(:title)
    assert_equal "Count unread conversations", counted.openapi.fetch(:title)
    assert_equal "press_centers/:id/conversations", listed.path
    assert_equal "Mailbox", listed.recordable_type
    assert_nil RecordingStudioApi.registered_endpoint(:support_rename_conversation)
  end

  test "my messages omits membership-locked support-center threads from the list and unread count" do
    mine = granted_conversation("Desk line", @editor_client, :edit, mount: @inbox)
    ticket = granted_conversation("Support ticket", @editor_client, :view)
    original = RecordingStudio.capability_options(:messages, for: Workspace)
    RecordingStudio.set_capability_options(
      :messages,
      on: Workspace,
      keys: [:support],
      membership_locked: [:support],
      contacts: DummyCatalog::CONTACTS
    )

    listed = call(:get, "/my_messages/conversations", @editor_token)
    ids = listed.fetch("records").map { |row| row.fetch("id") }
    counted = call(:get, "/my_messages/unread_count", @editor_token)

    assert_response :success, response.body
    assert_includes ids, mine.id
    refute_includes ids, ticket.id
    assert_equal(
      RecordingStudioMessages.unread_count(actor: @editor_client),
      counted.fetch("unread_count")
    )
    call(:get, "/my_messages/conversations/#{ticket.id}/messages", @editor_token)
    assert_response :not_found, response.body
  ensure
    if original
      RecordingStudio.set_capability_options(:messages, on: Workspace, **original)
    else
      RecordingStudio.set_capability_options(
        :messages, on: Workspace, keys: [:support], contacts: DummyCatalog::CONTACTS
      )
    end
  end

  test "press_center_messages start works for a press contact when the parent has no contacts list" do
    original = RecordingStudio.capability_options(:messages, for: Mailbox)
    RecordingStudio.set_capability_options(
      :messages,
      on: Mailbox,
      keys: [:inbox],
      public_contact: [:inbox]
    )
    RecordingStudioMessages::Api.place(
      api: :public,
      at: :press_center_messages,
      mount: { recordable_type: "Mailbox", key: :inbox },
      preset: :press_center
    )
    press = user("press")
    press_access = grant!(@mailbox_recording, press, :edit)
    press_token, = token_for(press_access, role: :edit)

    started = call(
      :post, "/press_center_messages/#{@mailbox_recording.id}/conversations", press_token,
      body: "Can we use the stills next week?"
    )

    assert_response :success, started.to_s
    assert_equal @inbox.id, started.fetch("parent_id")
    assert_equal "Can we use the stills next week?", first_message_body(started.fetch("id"))
    assert_includes(
      RecordingStudioMessages.my_group_recordings(actor: press).map(&:id),
      started.fetch("id")
    )
  ensure
    if original
      RecordingStudio.set_capability_options(:messages, on: Mailbox, **original)
    else
      RecordingStudio.set_capability_options(
        :messages,
        on: Mailbox,
        keys: [:inbox],
        public_contact: [:inbox],
        access: :inherited,
        contacts: DummyCatalog::CONTACTS
      )
    end
  end

  test "my messages list pages direct grants and skips other roots" do
    mine = granted_conversation("Mine", @editor_client, :edit)
    second = granted_conversation("Second", @editor_client, :view)
    third = granted_conversation("Third", @editor_client, :view)
    RecordingStudioMessages.mark_read(group_recording: third, actor: @editor_client)

    listed = call(:get, "/my_messages/conversations", @editor_token)
    assert_response :success, response.body
    ids = listed.fetch("records").map { |row| row.fetch("id") }
    assert_includes ids, mine.id
    assert_includes ids, second.id
    assert_includes ids, third.id
    refute_includes ids, @group.id
    refute_includes ids, @inbox_group.id
    refute_includes ids, @other_group.id
    row = listed.fetch("records").find { |record| record.fetch("id") == mine.id }
    assert_utc_iso8601 row.fetch("created_at"), mine.created_at

    page = call(:get, "/my_messages/conversations", @editor_token, limit: 2)
    assert_response :success, response.body
    first_ids = page.fetch("records").map { |record| record.fetch("id") }
    assert_equal 2, first_ids.size
    assert_equal first_ids.last, page.fetch("after_id")

    rest = call(:get, "/my_messages/conversations", @editor_token, limit: 2, after_id: first_ids.last)
    assert_response :success, response.body
    rest_ids = rest.fetch("records").map { |record| record.fetch("id") }
    assert_empty first_ids & rest_ids

    clamped = call(:get, "/my_messages/conversations", @editor_token, limit: 0)
    assert_equal 1, clamped.fetch("records").size

    unread = call(:get, "/my_messages/conversations", @editor_token, unread: true)
    unread_ids = unread.fetch("records").map { |record| record.fetch("id") }
    assert_includes unread_ids, mine.id
    refute_includes unread_ids, third.id

    call(:get, "/my_messages/conversations", @editor_token, after_id: @other_group.id)
    assert_response :unprocessable_entity, response.body
    assert_includes response.body, "after_id is not a conversation in My Messages"
  end

  test "my messages read mark and send follow view and edit" do
    mine = granted_conversation("Desk line", @editor_client, :edit)
    grant!(mine, @viewer_client, :view)
    before = RecordingStudioMessages.message_recordings(mine).size

    thread = call(:get, "/my_messages/conversations/#{mine.id}/messages", @viewer_token)
    assert_response :success, response.body
    assert_includes thread.fetch("records").map { |row| row.fetch("body") }, "Hello Desk line"
    message = thread.fetch("records").find { |row| row.fetch("body") == "Hello Desk line" }
    assert_utc_iso8601 message.fetch("created_at"), RecordingStudioMessages.message_recordings(mine).last.created_at

    call(:get, "/my_messages/conversations/#{@other_group.id}/messages", @editor_token)
    assert_response :not_found, response.body
    call(:post, "/my_messages/conversations/#{@other_group.id}/send_message", @editor_token, body: "Leak")
    assert_response :not_found, response.body
    call(:post, "/my_messages/conversations/#{@other_group.id}/mark_read", @editor_token)
    assert_response :not_found, response.body

    call(:post, "/my_messages/conversations/#{mine.id}/send_message", @viewer_token, body: "Nope")
    assert_response :forbidden, response.body
    assert_equal before, RecordingStudioMessages.message_recordings(mine).size

    sent = call(:post, "/my_messages/conversations/#{mine.id}/send_message", @editor_token, body: "From the inbox")
    assert_response :success, response.body
    assert_equal "From the inbox", sent.fetch("body")
    assert_equal mine.id, sent.fetch("parent_id")
    assert_equal "From the inbox", RecordingStudioMessages.message_recordings(mine).last.recordable.body
    assert_utc_iso8601 sent.fetch("created_at"), RecordingStudioMessages.message_recordings(mine).last.created_at

    marked = call(:post, "/my_messages/conversations/#{mine.id}/mark_read", @viewer_token)
    assert_response :success, response.body
    assert_equal mine.id, marked.fetch("id")
    refute RecordingStudioMessages.unread?(group_recording: mine, actor: @viewer_client)
  end

  test "count unread my messages matches the html inbox for that actor" do
    kept = granted_conversation("Keep unread", @editor, :edit)
    opened = granted_conversation("Opened", @editor, :edit)
    grant!(kept, @editor_client, :view)
    grant!(opened, @editor_client, :view)
    RecordingStudioMessages.mark_read(group_recording: opened, actor: @editor)
    RecordingStudioMessages.mark_read(group_recording: opened, actor: @editor_client)
    RecordingStudioMessages.send_message(
      group_recording: @other_group, body: "Other root", actor: @stranger, notify: false
    )

    expected = RecordingStudioMessages.unread_count(actor: @editor)
    sign_in @editor
    get recording_studio_messages.my_messages_path
    assert_response :success
    assert_select "turbo-frame#messages-unread-badge", text: expected.to_s
    sign_out @editor

    counted = call(:get, "/my_messages/unread_count", @editor_token)
    assert_response :success, response.body
    assert_equal RecordingStudioMessages.unread_count(actor: @editor_client), counted.fetch("unread_count")
    assert_equal expected, counted.fetch("unread_count")
    refute_includes(
      RecordingStudioMessages.my_group_recordings(actor: @editor_client, unread: true).map(&:id),
      @other_group.id
    )
  end

  private

  def groups_under(mount)
    RecordingStudio::Recording.where(
      parent_recording_id: mount.id,
      recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE
    ).count
  end

  def first_message_body(id)
    group = RecordingStudio::Recording.find(id)
    RecordingStudioMessages.message_recordings(group).last.recordable.body
  end

  def granted_conversation(title, actor, role, mount: @mount)
    group = RecordingStudioMessages.create_group(mount, title: title, actor: @owner)
    RecordingStudioMessages.send_message(
      group_recording: group, body: "Hello #{title}", actor: @owner, notify: false
    )
    grant!(group, actor, role)
    group
  end

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: name.titleize
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.create_root_recording!(recordable, actor: actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor:)
    raise result.error if result.failure?

    root
  end

  def grant!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(recording:, actor:, role:, manager_actor: @owner)
    raise result.error if result.failure?

    result.value
  end

  def owner_access
    RecordingStudioAccessible.access_recordings_for_actor(recording: @workspace, actor: @owner).first
  end

  def token_for(access_recording, role: nil)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: @owner,
      role: role || access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
  end

  def assert_utc_iso8601(stamp, time)
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, stamp)
    assert_equal time.utc.change(usec: 0), Time.iso8601(stamp)
  end

  def call(method, path, token, params = {})
    send(method, "#{BASE}#{path}", params:, headers: {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json"
    }, as: :json)
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end
end
