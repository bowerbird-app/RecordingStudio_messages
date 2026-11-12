# frozen_string_literal: true

require "test_helper"

class MessagesApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = user("owner")
    @editor = user("editor")
    @viewer = user("viewer")
    @stranger = user("stranger")
    Current.actor = @owner
    @workspace = owned_root(Workspace.create!(name: "API Desk #{SecureRandom.hex(4)}"))
    @other = owned_root(Workspace.create!(name: "Other desk #{SecureRandom.hex(4)}"), actor: @stranger)
    @mount = @workspace.ensure_message_mount("support", actor: @owner)
    @other_mount = @other.ensure_message_mount("support", actor: @stranger)
    @group = RecordingStudioMessages.create_group(@mount, title: "API thread", actor: @owner)
    @other_group = RecordingStudioMessages.create_group(@other_mount, title: "Elsewhere", actor: @stranger)
    RecordingStudioMessages.send_message(
      group_recording: @group, body: "Hello from the desk.", actor: @owner, notify: false
    )
    @editor_access = grant!(@workspace, @editor, :edit)
    @viewer_access = grant!(@workspace, @viewer, :view)
    @editor_token, @editor_client = token_for(@editor_access)
    @viewer_token, = token_for(@viewer_access)
    @admin_token, @admin_client = token_for(owner_access, role: :admin)
  end

  teardown { Current.actor = @previous_actor }

  test "send_message goes through RecordingStudioMessages.send_message" do
    sent = call(
      :post,
      "/conversations/#{@group.id}/send_message",
      @editor_token,
      body: "Quiet crop on the way."
    )
    assert_response :success, response.body
    assert_equal "Quiet crop on the way.", sent.fetch("body")
    assert_equal @group.id, sent.fetch("parent_id")
    assert_equal "Quiet crop on the way.", RecordingStudioMessages.message_recordings(@group).last.recordable.body
  end

  test "list_conversations goes through viewable_group_recordings" do
    listed = call(:get, "/desks/#{@mount.id}/conversations", @editor_token)
    assert_response :success, response.body
    ids = listed.fetch("records").map { |row| row.fetch("id") }
    assert_includes ids, @group.id
  end

  test "list_conversations pages after_id without overlap" do
    page_size = RecordingStudioMessages::MessageGroupsController::PAGE_SIZE
    extra = Array.new(page_size) do |index|
      group = RecordingStudioMessages.create_group(@mount, title: "Page #{index} #{SecureRandom.hex(2)}", actor: @owner)
      RecordingStudioMessages.send_message(
        group_recording: group, body: "Line #{index}", actor: @owner, notify: false
      )
      group
    end

    default_page = call(:get, "/desks/#{@mount.id}/conversations", @editor_token)
    assert_response :success, response.body
    default_ids = default_page.fetch("records").map { |row| row.fetch("id") }
    assert_equal page_size, default_ids.size
    assert_equal default_ids.last, default_page.fetch("after_id")

    clamped = call(:get, "/desks/#{@mount.id}/conversations", @editor_token, limit: page_size + 25)
    assert_response :success, response.body
    clamped_ids = clamped.fetch("records").map { |row| row.fetch("id") }
    assert_equal page_size, clamped_ids.size
    assert_equal default_ids, clamped_ids
    assert_equal default_ids.last, clamped.fetch("after_id")

    page_one = call(:get, "/desks/#{@mount.id}/conversations", @editor_token, limit: 2)
    assert_response :success, response.body
    first_ids = page_one.fetch("records").map { |row| row.fetch("id") }
    assert_equal 2, first_ids.size
    assert_nil page_one.fetch("after_id")

    page_two = call(
      :get,
      "/desks/#{@mount.id}/conversations",
      @editor_token,
      limit: 2,
      after_id: first_ids.last
    )
    assert_response :success, response.body
    second_ids = page_two.fetch("records").map { |row| row.fetch("id") }
    refute_empty second_ids
    assert_empty first_ids & second_ids
    assert_includes(extra.map(&:id) + [ @group.id ], first_ids.first)
    assert_nil page_two.fetch("after_id")

    remainder = call(
      :get,
      "/desks/#{@mount.id}/conversations",
      @editor_token,
      after_id: default_ids.last
    )
    assert_response :success, response.body
    leftover_ids = remainder.fetch("records").map { |row| row.fetch("id") }
    assert_operator leftover_ids.size, :<, page_size
    assert_empty default_ids & leftover_ids
    assert_nil remainder.fetch("after_id")
  end

  test "read_thread goes through message_recordings" do
    thread = call(:get, "/conversations/#{@group.id}/messages", @editor_token)
    assert_response :success, response.body
    bodies = thread.fetch("records").map { |row| row["body"] }
    assert_includes bodies, "Hello from the desk."
  end

  test "create_group goes through RecordingStudioMessages.create_group" do
    created = call(
      :post,
      "/desks/#{@mount.id}/create_group",
      @admin_token,
      title: "New API conversation"
    )
    assert_response :success, response.body
    assert_equal "New API conversation", created.fetch("title")
    assert_equal @mount.id, created.fetch("parent_id")
    listed = RecordingStudioMessages.viewable_group_recordings(
      actor: @admin_client,
      mount_recording: @mount
    ).map(&:id)
    assert_includes listed, created.fetch("id")
  end

  test "rename_group mark_read and unread_count wrap public helpers" do
    renamed = call(
      :post,
      "/conversations/#{@group.id}/rename_group",
      @editor_token,
      title: "Renamed API thread"
    )
    assert_response :success, response.body
    assert_equal "Renamed API thread", renamed.fetch("title")
    assert_equal "Renamed API thread", @group.reload.recordable.title

    marked = call(:post, "/conversations/#{@group.id}/mark_read", @editor_token)
    assert_response :success, response.body
    assert_equal @group.id, marked.fetch("id")

    count = call(:get, "/unread_count", @editor_token)
    assert_response :success, response.body
    assert count.fetch("unread_count").is_a?(Integer)
  end

  test "unread_count does not include another workspace" do
    workspace_b = owned_root(Workspace.create!(name: "Unread B #{SecureRandom.hex(4)}"))
    mount_b = workspace_b.ensure_message_mount("support", actor: @owner)
    group_b = RecordingStudioMessages.create_group(mount_b, title: "B unread", actor: @owner)
    grant!(@group, @editor_client, :edit)
    grant!(group_b, @editor_client, :edit)
    RecordingStudioMessages.send_message(
      group_recording: @group, body: "Unread in A", actor: @owner, notify: false
    )
    RecordingStudioMessages.send_message(
      group_recording: group_b, body: "Unread in B", actor: @owner, notify: false
    )

    global = RecordingStudioMessages.unread_count(actor: @editor_client)
    count = call(:get, "/unread_count", @editor_token)
    assert_response :success, response.body
    assert_operator global, :>=, 2
    assert_equal 1, count.fetch("unread_count")
  end

  test "view is forbidden from edit actions and can read" do
    call(:get, "/desks/#{@mount.id}/conversations", @viewer_token)
    assert_response :success, response.body

    call(:get, "/conversations/#{@group.id}/messages", @viewer_token)
    assert_response :success, response.body

    call(:post, "/conversations/#{@group.id}/mark_read", @viewer_token)
    assert_response :success, response.body

    call(:get, "/unread_count", @viewer_token)
    assert_response :success, response.body

    call(:post, "/conversations/#{@group.id}/send_message", @viewer_token, body: "Nope")
    assert_response :forbidden, response.body

    call(:post, "/desks/#{@mount.id}/create_group", @viewer_token, title: "Nope")
    assert_response :forbidden, response.body

    call(:post, "/conversations/#{@group.id}/rename_group", @viewer_token, title: "Nope")
    assert_response :forbidden, response.body
  end

  test "a conversation in another workspace is not found" do
    call(:post, "/conversations/#{@other_group.id}/send_message", @editor_token, body: "Nope")
    assert_response :not_found, response.body

    call(:get, "/conversations/#{@other_group.id}/messages", @editor_token)
    assert_response :not_found, response.body

    call(:post, "/conversations/#{@other_group.id}/rename_group", @editor_token, title: "Nope")
    assert_response :not_found, response.body

    call(:post, "/conversations/#{@other_group.id}/mark_read", @editor_token)
    assert_response :not_found, response.body

    call(:get, "/desks/#{@other_mount.id}/conversations", @editor_token)
    assert_response :not_found, response.body

    call(:post, "/desks/#{@other_mount.id}/create_group", @editor_token, title: "Nope")
    assert_response :not_found, response.body
  end

  test "bad input is unprocessable" do
    call(:post, "/conversations/#{@group.id}/send_message", @editor_token, body: "")
    assert_response :unprocessable_entity, response.body

    call(:post, "/desks/#{@mount.id}/create_group", @editor_token, title: "")
    assert_response :unprocessable_entity, response.body

    call(:post, "/conversations/#{@group.id}/rename_group", @editor_token, title: "")
    assert_response :unprocessable_entity, response.body

    call(:get, "/desks/#{@mount.id}/conversations", @editor_token, after_id: @other_group.id)
    assert_response :unprocessable_entity, response.body
  end

  test "messages api registration matches html roles and skips generic message create" do
    refute RecordingStudio.capability_enabled?(:messages, for: RecordingStudioMessages::MessageGroup)
    refute RecordingStudio.capability_enabled?(:messages, for: RecordingStudioMessages::MessageMount)

    group = RecordingStudioApi.recordable_registration_for("RecordingStudioMessages::MessageGroup")
    mount = RecordingStudioApi.recordable_registration_for("RecordingStudioMessages::MessageMount")
    assert_equal %i[show], group.operations
    assert_equal %i[show], mount.operations
    assert_equal false, group.auto_capability_actions
    assert_equal [], group.capability_actions
    assert_equal [], mount.capability_actions
    refute RecordingStudioApi.recordable_registration_for("RecordingStudioMessages::Message")

    refute RecordingStudioApi.capability_action(:messages_send_message)
    refute RecordingStudioApi.capability_action(:messages_list_conversations)
    refute RecordingStudioApi.capability_action(:messages_create_group)
    send_message = RecordingStudioApi.registered_endpoint(:messages_send_message)
    create_group = RecordingStudioApi.registered_endpoint(:messages_create_group)
    assert_equal "Message - Send", send_message.openapi.fetch(:title)
    assert_equal "Group - Create", create_group.openapi.fetch(:title)
    assert RecordingStudioApi.registered_endpoint(:messages_list_conversations)
    assert RecordingStudioApi.registered_endpoint(:messages_unread_count)

    assert_equal RecordingStudioMessages::Api::Registration.serialize_group(@group.recordable),
                 RecordingStudioMessages::Api::Target.recordable_fields(@group)
    assert_equal RecordingStudioMessages::Api::Registration.serialize_mount(@mount.recordable),
                 RecordingStudioMessages::Api::Target.recordable_fields(@mount)
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: name.titleize
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.root_recording_for(recordable)
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

    [ issued.value.fetch(:access_token), provision.value.fetch(:api_client) ]
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
