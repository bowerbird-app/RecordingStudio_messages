# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class NewConversationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
    @members_mount = DummyCatalog.support_mount_recording
    @inherited_mount = DummyCatalog.inbox_mount_recording
    @original_workspace = RecordingStudio.capability_options(:messages, for: Workspace)
  end

  teardown do
    if @original_workspace
      RecordingStudio.set_capability_options(:messages, on: Workspace, **@original_workspace)
    end
  end

  test "new message stays off the list when the mount has no contacts resolver" do
    sign_in @staff
    RecordingStudio.set_capability_options(:messages, on: Workspace, keys: [:support])

    get recording_studio_messages.message_groups_path(mount_id: @members_mount.id)

    assert_response :success
    refute_includes response.body, RecordingStudioMessages::Copy.t("inbox.new")
    refute_includes response.body, "messages-new-conversation-#{@members_mount.id}"
  end

  test "new message shows when the actor can edit and the mount has contacts" do
    sign_in @staff
    get recording_studio_messages.message_groups_path(mount_id: @members_mount.id)

    assert_response :success
    assert_includes response.body, RecordingStudioMessages::Copy.t("inbox.new")
    assert_includes response.body, RecordingStudioMessages::Copy.t("inbox.send")
    assert_includes response.body, "messages-new-conversation-#{@members_mount.id}"
    assert_includes response.body, "flat-pack--select"
    assert_includes response.body, "data-flat-pack--select-multiple-value=\"true\""
    assert_includes response.body, "data-flat-pack--select-search-mode-value=\"remote\""
    assert_includes response.body, recording_studio_messages.contacts_message_groups_path(
      mount_id: @members_mount.id
    )
    refute_includes response.body, "recording-studio-messages--new-conversation"
    refute_includes response.body, 'name="title"'
    assert_select "[data-modal-id=?]", "messages-new-conversation-#{@members_mount.id}"
    assert_select "button[aria-label=?]", RecordingStudioMessages::Copy.t("inbox.new")
  end

  test "contact search returns only resolver matches for the query" do
    sign_in @staff
    get recording_studio_messages.contacts_message_groups_path(
      mount_id: @members_mount.id,
      q: "Casey"
    ), as: :json

    assert_response :success
    items = JSON.parse(response.body).fetch("items")
    labels = items.map { |item| item.fetch("label") }
    values = items.map { |item| item.fetch("value") }
    assert_equal ["Casey Patron"], labels
    assert_equal ["User:#{@customer.id}"], values
    refute_includes response.body, "Ada Staff"
    refute_includes response.body, @staff.email
    refute_includes response.body, "Jules Early"
    refute_includes response.body, "Kit Extra"
    refute_includes response.body, "Riley One"
    refute_includes response.body, "Sam Overflow"
  end

  test "contact search matches name or email without caring about case" do
    sign_in @staff
    get recording_studio_messages.contacts_message_groups_path(
      mount_id: @members_mount.id,
      q: "casey@example"
    ), as: :json

    assert_response :success
    labels = JSON.parse(response.body).fetch("items").map { |item| item.fetch("label") }
    assert_equal ["Casey Patron"], labels
    refute_includes response.body, "Jules Early"
  end

  test "contact search stays empty until there is a query" do
    sign_in @staff
    get recording_studio_messages.contacts_message_groups_path(mount_id: @members_mount.id), as: :json

    assert_response :success
    assert_equal [], JSON.parse(response.body).fetch("items")
  end

  test "creating a conversation lands on it and the recipient sees it in my messages" do
    sign_in @staff
    assert_difference -> { groups_under(@members_mount) }, +1 do
      post recording_studio_messages.message_groups_path, params: {
        mount_id: @members_mount.id,
        body: "Can you send the quieter still?",
        recipients: [ "User:#{@customer.id}" ]
      }
    end

    group = DummyCatalog.find_group_recording_under(@members_mount, "Casey Patron")
    assert_redirected_to recording_studio_messages.message_group_path(group)
    follow_redirect!
    assert_includes response.body, "Can you send the quieter still?"
    assert_includes response.body, "Casey Patron"

    sign_in @customer
    get recording_studio_messages.my_messages_path
    assert_response :success
    assert_includes response.body, "Casey Patron"
  end

  test "create rejects a recipient outside the resolver" do
    sign_in @staff
    assert_no_difference -> { groups_under(@members_mount) } do
      post recording_studio_messages.message_groups_path, params: {
        mount_id: @members_mount.id,
        body: "Hello?",
        recipients: [ { type: "User", id: "missing-#{SecureRandom.hex(4)}" } ]
      }
    end

    assert_redirected_to recording_studio_messages.message_groups_path(mount_id: @members_mount.id)
    assert_equal RecordingStudioMessages::Copy.t("errors.unknown_recipient"), flash[:alert]
  end

  test "create rejects a blank first message" do
    sign_in @staff
    assert_no_difference -> { groups_under(@members_mount) } do
      post recording_studio_messages.message_groups_path, params: {
        mount_id: @members_mount.id,
        body: "   ",
        recipients: [ { type: "User", id: @customer.id } ]
      }
    end

    assert_redirected_to recording_studio_messages.message_groups_path(mount_id: @members_mount.id)
    assert_equal RecordingStudioMessages::Copy.t("errors.write_message"), flash[:alert]
  end

  test "create without edit is rejected" do
    viewer = User.create!(
      email: "viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Viewer"
    )
    root = RecordingStudio.root_recording_for(DummyCatalog.studio_workspace)
    result = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: viewer,
      role: :view,
      manager_actor: @staff
    )
    raise result.error if result.failure?

    sign_in viewer
    Current.actor = viewer
    assert_no_difference -> { groups_under(@members_mount) } do
      post recording_studio_messages.message_groups_path, params: {
        mount_id: @members_mount.id,
        body: "Hello?",
        recipients: [ { type: "User", id: @staff.id } ]
      }
    end

    assert_response :redirect
    refute_match(%r{/message_groups/[0-9a-f-]+$}, response.redirect_url)
    assert_includes [
      RecordingStudioMessages::Copy.t("flashes.cannot_open"),
      RecordingStudioMessages::Copy.t("errors.cannot_start")
    ], flash[:alert]
  end

  test "inherited desk also offers new message" do
    sign_in @staff
    get inbox_path

    assert_response :success
    assert_includes response.body, RecordingStudioMessages::Copy.t("inbox.new")
    assert_includes response.body, "messages-new-conversation-#{@inherited_mount.id}"
  end

  private

  def groups_under(mount)
    RecordingStudio::Recording.where(
      parent_recording_id: mount.id,
      recordable_type: "RecordingStudioMessages::MessageGroup"
    ).count
  end
end
