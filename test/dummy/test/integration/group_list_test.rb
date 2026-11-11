# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class GroupListTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
  end

  test "staff desk lists conversations the actor can view through Accessible" do
    sign_in @staff
    get staff_desk_path

    assert_response :success
    assert_select "html[data-theme='rounded']", count: 1
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "[data-controller='flat-pack--chat-layout']"
    assert_select "[data-controller='flat-pack--list-selectable']"
    assert_includes response.body, "Staff desk"
    assert_select "[data-flat-pack--chat-layout-target='sidebar'] h2", text: ""
    refute_select "[data-flat-pack--chat-layout-target='sidebar'] h2",
                  text: DummyCatalog.studio_workspace.name
    refute_select "[data-flat-pack--chat-layout-target='panel'] h2",
                  text: DummyCatalog.studio_workspace.name
    assert_includes response.body, "Studio help"
    assert_includes response.body, "Launch notes"
    assert_includes response.body, "I will send a quieter line this evening."
    assert_includes response.body, "flat-pack--chat-panel"
    assert_select "a[href=?][data-turbo-frame=?]",
                  recording_studio_messages.message_group_path(DummyCatalog.support_group_recording),
                  "messages-desk-panel"
    assert_select "a[href=?][data-turbo-frame=?]",
                  recording_studio_messages.message_group_path(DummyCatalog.launch_group_recording),
                  "messages-desk-panel"
    assert_select "turbo-frame#messages-desk-panel"
    assert_includes response.body, "flat-pack-page-nav"
    assert_includes response.body, "h-[calc(100dvh-15.5rem)]"
    assert_includes response.body, "w-full min-w-0"
    refute_includes response.body, "min-h-[70vh]"
    assert_includes response.body, "Back to conversations"
    assert_includes response.body, "sm:grid"
    refute_includes response.body, "md:grid-cols-[280px"
    refute_includes response.body, "[data-flat-pack--chat-layout-target=\"panel\"] > div:first-child:has([aria-label=\"Back to conversations\"])"
    refute_includes response.body, "back_href"
    refute_includes response.body, "Open conversation"
    refute_includes response.body, recording_studio_messages.message_group_path(DummyCatalog.empty_group_recording)
    refute_includes response.body, "PageTitle"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Pundit"
    refute_includes response.body, "CanCan"
  end

  test "staff can open a listed conversation into Chat::Panel" do
    sign_in @staff
    get staff_desk_path

    assert_response :success
    get recording_studio_messages.message_group_path(DummyCatalog.support_group_recording)

    assert_response :success
    assert_includes response.body, "flat-pack--chat-panel"
    assert_includes response.body, "The homepage hero feels a bit loud"
    assert_includes response.body, "Studio help"
    assert_includes response.body, "flat-pack-page-nav"
    assert_select "[data-controller='flat-pack--chat-layout']"
    assert_select "textarea[name='message[body]'][rows='1']"
    assert_includes response.body, "rounded-[var(--chat-composer-radius)]"
    assert_includes response.body, "min-h-[var(--chat-composer-control-height)]"
    assert_includes response.body, "rounded-[var(--chat-message-radius)]"
    assert_includes response.body, "px-[var(--chat-message-padding-x)]"
    assert_includes response.body, "py-[var(--chat-message-padding-y)]"
    refute_includes response.body, "rounded-lg border-[var(--chat-input-border-color)]"
  end

  test "inbox row click loads the panel through the desk turbo frame" do
    sign_in @staff
    group = DummyCatalog.support_group_recording

    get recording_studio_messages.message_group_path(group),
        headers: { "Turbo-Frame" => "messages-desk-panel" }

    assert_response :success
    assert_select "turbo-frame#messages-desk-panel"
    assert_includes response.body, "flat-pack--chat-panel"
    assert_includes response.body, "The homepage hero feels a bit loud"
    assert_includes response.body, "Studio help"
    refute_includes response.body, "flat-pack--chat-layout"
    refute_includes response.body, "flat-pack-page-nav"
    refute_includes response.body, "data-controller='flat-pack--chat-layout'"
  end

  test "engine index scopes to a mount and Accessible view grants" do
    sign_in @staff
    mount = DummyCatalog.support_mount_recording
    get recording_studio_messages.message_groups_path(mount_id: mount.id)

    assert_response :success
    assert_select "[data-controller='flat-pack--chat-layout']"
    assert_includes response.body, "Studio help"
    assert_includes response.body, "Launch notes"
    assert_includes response.body, "flat-pack--chat-panel"
    refute_includes response.body, "Open conversation"
    refute_includes response.body, "Site inbox"
    refute_includes response.body, "Did the press stills land?"
  end

  test "inbox still shows a one-row list for the mailbox mount" do
    sign_in @customer
    get inbox_path

    assert_response :success
    assert_select "[data-controller='flat-pack--chat-layout']"
    assert_select "[data-controller='flat-pack--list-selectable']"
    assert_includes response.body, "Site inbox"
    assert_includes response.body, "They are in. I attached the first frame."
    assert_includes response.body, "flat-pack--chat-panel"
    assert_select "a[href=?][data-turbo-frame=?]",
                  recording_studio_messages.message_group_path(DummyCatalog.inbox_group_recording),
                  "messages-desk-panel"
    assert_select "turbo-frame#messages-desk-panel"
    assert_includes response.body, "flat-pack-page-nav"
    assert_includes response.body, "h-[calc(100dvh-15.5rem)]"
    assert_includes response.body, "w-full min-w-0"
    assert_includes response.body, "Back to conversations"
    assert_includes response.body, "sm:grid"
    refute_includes response.body, "md:grid-cols-[280px"
    refute_includes response.body, "[data-flat-pack--chat-layout-target=\"panel\"] > div:first-child:has([aria-label=\"Back to conversations\"])"
    refute_includes response.body, "Studio help"
  end

  test "stranger without a grant does not see conversations on the staff desk" do
    stranger = User.create!(
      email: "list-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Stranger",
      confirmed_at: Time.current
    )

    sign_in stranger
    get staff_desk_path

    assert_redirected_to root_path
  end

  test "granted actor sees the engine desk for a named mount" do
    sign_in @staff
    mount = DummyCatalog.support_mount_recording

    get recording_studio_messages.message_groups_path(mount_id: mount.id)

    assert_response :success
    assert_select "[data-controller='flat-pack--chat-layout']"
    assert_includes response.body, DummyCatalog.studio_workspace.name
    assert_includes response.body, "Studio help"
  end

  test "ungranted actor gets 404 on engine index and does not see the parent name" do
    stranger = User.create!(
      email: "index-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Stranger",
      confirmed_at: Time.current
    )
    mount = DummyCatalog.support_mount_recording
    parent_name = DummyCatalog.studio_workspace.name

    sign_in stranger
    get recording_studio_messages.message_groups_path(mount_id: mount.id)

    assert_response :not_found
    refute_includes response.body, parent_name
  end

  test "conversation grantee without parent view gets 404 on engine index" do
    grantee = User.create!(
      email: "group-only-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Group Only",
      confirmed_at: Time.current
    )
    result = RecordingStudioAccessible.grant_access(
      recording: DummyCatalog.support_group_recording,
      actor: grantee,
      role: :view,
      manager_actor: @staff
    )
    raise result.error if result.failure?

    parent_name = DummyCatalog.studio_workspace.name
    sign_in grantee
    get recording_studio_messages.message_groups_path(mount_id: DummyCatalog.support_mount_recording.id)

    assert_response :not_found
    refute_includes response.body, parent_name
  end

  test "engine index 404s when the mount has no parent" do
    sign_in @staff
    mount = DummyCatalog.support_mount_recording
    previous_parent_id = mount.parent_recording_id
    mount.update_column(:parent_recording_id, nil)

    get recording_studio_messages.message_groups_path(mount_id: mount.id)

    assert_response :not_found
    assert_includes response.body, "Messages mount not found"
  ensure
    if defined?(mount) && mount && defined?(previous_parent_id) && previous_parent_id
      mount.update_column(:parent_recording_id, previous_parent_id)
    end
  end

  test "engine show without a grant redirects" do
    stranger = User.create!(
      email: "show-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Stranger",
      confirmed_at: Time.current
    )

    sign_in stranger
    get recording_studio_messages.message_group_path(DummyCatalog.support_group_recording)

    assert_redirected_to "/"
  end
end
