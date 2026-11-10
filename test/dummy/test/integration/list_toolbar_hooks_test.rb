# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

module MessagesListToolbarOverrides
  def messages_list_toolbar(mount:, actor:)
    override = MessagesListToolbarOverrides.current[:toolbar]
    return override.call(mount: mount, actor: actor) if override
    return if MessagesListToolbarOverrides.current.key?(:toolbar)

    super
  end

  def self.current
    Thread.current[:messages_list_toolbar_overrides] ||= {}
  end

  def self.with_overrides(toolbar: :keep)
    previous = current.dup
    current[:toolbar] = toolbar unless toolbar == :keep
    yield
  ensure
    Thread.current[:messages_list_toolbar_overrides] = previous
  end
end

DummyMessagesListHelper.prepend(MessagesListToolbarOverrides) unless
  DummyMessagesListHelper.ancestors.include?(MessagesListToolbarOverrides)

class ListToolbarHooksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
    @mount = DummyCatalog.support_mount_recording
    sign_in @staff
  end

  test "engine list toolbar hook returns nothing" do
    helper = Object.new.extend(RecordingStudioMessages::InboxHelper)

    assert_nil helper.messages_list_toolbar(mount: @mount, actor: @staff)
    assert_nil helper.messages_list_toolbar(mount: nil, actor: @staff)
  end

  test "dummy host toolbar renders on the support mount and stays off inbox and my messages" do
    get recording_studio_messages.message_groups_path(mount_id: @mount.id)

    assert_response :success
    assert_select "#dummy-list-toolbar", text: "New"
    assert_select "a[aria-label=?]", "Show unread only"

    get recording_studio_messages.message_groups_path(mount_id: DummyCatalog.inbox_mount_recording.id)
    assert_response :success
    assert_select "#dummy-list-toolbar", count: 0

    get recording_studio_messages.my_messages_path
    assert_response :success
    assert_select "#dummy-list-toolbar", count: 0
    assert_select "a[aria-label=?]", "Show unread only"
  end

  test "overridden list toolbar receives the mount and actor and renders beside the unread toggle" do
    seen = []
    MessagesListToolbarOverrides.with_overrides(
      toolbar: lambda { |mount:, actor:|
        seen << [mount, actor]
        %(<span id="messages-list-toolbar">hook-list</span>).html_safe
      }
    ) do
      get recording_studio_messages.message_groups_path(mount_id: @mount.id)
    end

    assert_equal [[@mount, @staff]], seen
    assert_select "#messages-list-toolbar", text: "hook-list"
    assert_select "a[aria-label=?]", "Show unread only"
    html = response.body
    assert_operator html.index("Show unread only"), :<, html.index("messages-list-toolbar")
  end

  test "my messages calls the hook with a blank mount" do
    seen = []
    MessagesListToolbarOverrides.with_overrides(
      toolbar: lambda { |mount:, actor:|
        seen << [mount, actor]
        %(<span id="messages-list-toolbar">hook-list</span>).html_safe
      }
    ) do
      get recording_studio_messages.my_messages_path
    end

    assert_equal [[nil, @staff]], seen
    assert_select "#messages-list-toolbar", text: "hook-list"
  end
end
