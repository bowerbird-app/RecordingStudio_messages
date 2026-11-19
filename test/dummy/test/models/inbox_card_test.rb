# frozen_string_literal: true

require "test_helper"

class InboxCardTest < ActiveSupport::TestCase
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
    @stranger = User.create!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Stranger"
    )
    Current.actor = @owner
    @mount = support_mount
  end

  teardown do
    Current.actor = @previous_actor
    remove_dashboard_stub
  end

  test "mine and mount cards render titles, previews, and inbox links" do
    group = open_conversation(@mount, "Desk notes", "The quieter crop is in.")

    mine = render_card(actor: @viewer, title: "My messages", mine: true)
    mount_card = render_card(actor: @viewer, title: "Team inbox", mount: @mount)

    assert_includes mine, "My messages"
    assert_includes mine, "Desk notes"
    assert_includes mine, "The quieter crop is in."
    assert_includes mine, "See all"
    assert_includes mine, "data-inbox-card=\"mine\""
    assert_includes mine, "/recording_studio_messages/my_messages"

    assert_includes mount_card, "Team inbox"
    assert_includes mount_card, "Desk notes"
    assert_includes mount_card, "The quieter crop is in."
    assert_includes mount_card, "data-inbox-card=\"mount\""
    assert_includes mount_card, "/recording_studio_messages/message_groups?mount_id=#{@mount.id}"
    assert_includes mount_card, "/recording_studio_messages/message_groups/#{group.id}"
  end

  test "an empty source renders nothing" do
    open_conversation(@mount, "Kept", "Still here.")

    html = render_card(actor: @viewer, title: "Team inbox", mount: empty_inbox_mount)

    assert_equal "", html.strip
    refute_includes html, "Team inbox"
    refute_includes html, "Kept"
  end

  test "an actor without access sees no card and no conversation text" do
    open_conversation(@mount, "Private desk", "Do not leak this line.")

    mine = render_card(actor: @stranger, title: "My messages", mine: true)
    mount_card = render_card(actor: @stranger, title: "Team inbox", mount: @mount)

    assert_equal "", mine.strip
    assert_equal "", mount_card.strip
    [mine, mount_card].each do |html|
      refute_includes html, "My messages"
      refute_includes html, "Team inbox"
      refute_includes html, "Private desk"
      refute_includes html, "Do not leak this line."
    end
  end

  test "the unread badge counts the source, not only the preview" do
    first, = Array.new(3) { |index| open_conversation(@mount, "Note #{index}", "Line #{index}") }
    RecordingStudioMessages.mark_read(group_recording: first, actor: @viewer)

    html = render_card(actor: @viewer, title: "My messages", mine: true, limit: 1)

    assert_equal 2, RecordingStudioMessages.unread_count(actor: @viewer)
    assert_includes html, ">2<"
    assert_equal 1, html.scan(/Note \d/).uniq.size
  end

  test "rendering more conversations does not add queries" do
    2.times { |index| open_conversation(@mount, "Flat #{index}", "Body #{index}") }
    render_card(actor: @viewer, title: "My messages", mine: true)
    small = query_count { render_card(actor: @viewer, title: "My messages", mine: true) }

    3.times { |index| open_conversation(@mount, "More #{index}", "Extra #{index}") }
    large = query_count { render_card(actor: @viewer, title: "My messages", mine: true) }

    assert_equal small, large
    assert_operator small, :>, 0
  end

  test "dashboard prepare hides an empty source and publishes a visible one" do
    install_dashboard_stub
    empty = RecordingStudioMessages::InboxCard.prepare(@viewer, { title: "My messages", mine: true })
    assert_equal :empty, empty.state

    open_conversation(@mount, "Ready", "Hello from the desk.")
    context = Struct.new(:actor, :team_mount).new(@viewer, @mount)
    filled = RecordingStudioMessages::InboxCard.prepare(
      context,
      { title: "Team inbox", mount: ->(ctx) { ctx.team_mount } }
    )

    assert_equal :content, filled.state
    assert_equal "Team inbox", filled.data.title
    assert_equal ["Ready"], filled.data.groups.map { |group| group.recordable.title }
  end

  test "dashboard registration is skipped until the gem is loaded, then once" do
    refute defined?(RecordingStudioDashboard)
    assert_nil RecordingStudioMessages::InboxCard.register_dashboard_widget!

    install_dashboard_stub
    widget = RecordingStudioMessages::InboxCard.register_dashboard_widget!
    assert_equal :messages_inbox, widget.id
    assert_equal RecordingStudioMessages::InboxCard, widget.component
    assert_equal :hide, widget.attrs[:empty]
    assert_equal [6, 12], widget.attrs[:supported_spans]
    assert_nil RecordingStudioMessages::InboxCard.register_dashboard_widget!
  end

  private

  def support_mount
    workspace = Workspace.create!(name: "Inbox card #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(workspace, actor: @owner)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    raise result.error if result.failure?

    @root.ensure_message_mount("support", actor: @owner)
  end

  def empty_inbox_mount
    mailbox = Mailbox.create!(name: "Empty mailbox #{SecureRandom.hex(4)}")
    mailbox_recording = RecordingStudio.record!(
      action: "created",
      recordable: mailbox,
      root_recording: @root,
      parent_recording: @root,
      actor: @owner
    ).recording
    mailbox_recording.ensure_message_mount("inbox", actor: @owner)
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

  def open_conversation(mount, title, body)
    Current.actor = @owner
    group = RecordingStudioMessages.create_group(mount, title: title, actor: @owner)
    grant_view!(group, @viewer)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: body,
      actor: @owner,
      notify: false
    )
    group
  end

  def render_card(...)
    controller = HomeController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.view_context.render(RecordingStudioMessages::InboxCard.new(...))
  end

  def query_count
    count = 0
    callback = lambda do |*_args, payload|
      name = payload[:name].to_s
      next unless name.end_with?(" Load")
      next if name.include?("SCHEMA")
      next if name == "CACHE"

      count += 1
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    count
  end

  def install_dashboard_stub
    return if defined?(RecordingStudioDashboard)

    stub = Module.new
    stub.const_set(:Preparation, Class.new do
      attr_reader :state, :data

      def self.empty
        new(:empty, nil)
      end

      def self.content(data)
        new(:content, data)
      end

      def initialize(state, data)
        @state = state
        @data = data
      end
    end)
    registry_class = Class.new do
      def initialize
        @widgets = {}
      end

      def add(id, component, attrs)
        @widgets[id] = Struct.new(:id, :component, :attrs).new(id, component, attrs)
      end

      def widget(id)
        @widgets.fetch(id.to_sym)
      end
    end
    stub.const_set(:Registry, registry_class)
    stub.define_singleton_method(:registry) { @registry ||= const_get(:Registry).new }
    stub.define_singleton_method(:register_widget) do |id, component:, **attrs|
      registry.add(id, component, attrs)
    end
    Object.const_set(:RecordingStudioDashboard, stub)
    @dashboard_stub_installed = true
  end

  def remove_dashboard_stub
    return unless @dashboard_stub_installed
    return unless defined?(RecordingStudioDashboard)

    Object.send(:remove_const, :RecordingStudioDashboard)
    @dashboard_stub_installed = false
  end
end
