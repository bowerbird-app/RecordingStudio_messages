# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

module MessagesPanelHookOverrides
  def messages_panel_right_header(group_recording, actor:, mount:)
    override = MessagesPanelHookOverrides.current[:right_header]
    return override.call(group_recording, actor: actor, mount: mount) if override
    return if MessagesPanelHookOverrides.current.key?(:right_header)

    super
  end

  def messages_panel_right_header_mobile(group_recording, actor:, mount:)
    override = MessagesPanelHookOverrides.current[:right_header_mobile]
    return override.call(group_recording, actor: actor, mount: mount) if override
    return if MessagesPanelHookOverrides.current.key?(:right_header_mobile)

    super
  end

  def messages_panel_after(group_recording, actor:, mount:)
    override = MessagesPanelHookOverrides.current[:after]
    return override.call(group_recording, actor: actor, mount: mount) if override
    return if MessagesPanelHookOverrides.current.key?(:after)

    super
  end

  def self.current
    Thread.current[:messages_panel_hook_overrides] ||= {}
  end

  def self.with_overrides(right_header: :keep, right_header_mobile: :keep, after: :keep)
    previous = current.dup
    current[:right_header] = right_header unless right_header == :keep
    current[:right_header_mobile] = right_header_mobile unless right_header_mobile == :keep
    current[:after] = after unless after == :keep
    yield
  ensure
    Thread.current[:messages_panel_hook_overrides] = previous
  end
end

DummyMessagesPanelHelper.prepend(MessagesPanelHookOverrides) unless
  DummyMessagesPanelHelper.ancestors.include?(MessagesPanelHookOverrides)

class PanelHeaderHooksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  PANEL_WITHOUT_HEADER_HOOKS = <<~'PANEL'
    <% current_actor = local_assigns.fetch(:current_actor) %>
    <% group_recording = local_assigns.fetch(:group_recording) %>
    <% message_recordings = local_assigns.fetch(:message_recordings) %>
    <% form_url = local_assigns[:form_url].presence || messages_panel_form_url(group_recording) %>
    <% return_to = local_assigns[:return_to].presence || messages_panel_return_to %>
    <% membership_open = !RecordingStudioMessages.membership_locked_for_group?(group_recording) %>

    <%= render FlatPack::Chat::Panel::Component.new(class: "flat-pack--chat-panel") do |panel| %>
      <% panel.header do %>
        <%= render FlatPack::Chat::Header::Component.new(
          title: group_recording.recordable.title
        ) do |header| %>
          <% if membership_open %>
            <% header.right do %>
              <%= recording_studio_accessible_avatars(group_recording, button_style: :ghost) %>
            <% end %>
          <% end %>
        <% end %>
      <% end %>

      <% panel.messages do %>
        <%= render "recording_studio_messages/message_groups/message_list",
                   group_recording: group_recording,
                   message_recordings: message_recordings,
                   current_actor: current_actor %>
      <% end %>

      <% panel.composer do %>
        <%= render "recording_studio_messages/message_groups/composer",
                   group_recording: group_recording,
                   form_url: form_url,
                   return_to: return_to %>
      <% end %>
    <% end %>
  PANEL

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @group = DummyCatalog.support_group_recording
    sign_in @staff
  end

  test "engine header hooks return nothing" do
    helper = Object.new.extend(RecordingStudioMessages::PanelHelper)

    assert_nil helper.messages_panel_right_header(@group, actor: @staff, mount: DummyCatalog.support_mount_recording)
    assert_nil helper.messages_panel_right_header_mobile(
      @group, actor: @staff, mount: DummyCatalog.support_mount_recording
    )
    assert_nil helper.messages_panel_after(@group, actor: @staff, mount: DummyCatalog.support_mount_recording)
  end

  test "default hooks leave the panel html identical to the panel without those slots" do
    with_blank_hooks do
      get_panel
      html = render_panel_partial

      assert_equal stable_panel_html(rendered_baseline), stable_panel_html(html)
      assert_includes response.body, "flat-pack--chat-panel"
      refute_includes response.body, "dummy-thread-status"
      assert_select '[data-flat-pack-chat-panel-part="header"]', count: 0
      assert_select '[data-flat-pack-chat-panel-part="right-header"]', count: 0
      assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"]', count: 0
    end
  end

  test "overridden hooks render both header slots and the after content" do
    seen = []
    with_hooks(
      right_header: lambda { |group_recording, actor:, mount:|
        seen << [group_recording, actor, mount]
        %(<span id="messages-panel-right-header">hook-right</span>).html_safe
      },
      right_header_mobile: lambda { |group_recording, actor:, mount:|
        seen << [group_recording, actor, mount]
        %(<span id="messages-panel-right-header-mobile">hook-mobile</span>).html_safe
      },
      after: lambda { |group_recording, actor:, mount:|
        seen << [group_recording, actor, mount]
        %(<div id="messages-panel-after">hook-after</div>).html_safe
      }
    ) { get_panel }

    mount = DummyCatalog.support_mount_recording
    assert_equal [[@group, @staff, mount], [@group, @staff, mount], [@group, @staff, mount]], seen
    assert_select ".flat-pack--chat-panel" do
      assert_select '[data-flat-pack-chat-panel-part="right-header"] #messages-panel-right-header', text: "hook-right"
      assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"] #messages-panel-right-header-mobile',
                    text: "hook-mobile"
      assert_select "#messages-panel-after", count: 0
    end
    assert_select "#messages-panel-after", text: "hook-after"
    panel = Nokogiri::HTML.fragment(response.body).at_css(".flat-pack--chat-panel")
    assert_equal "messages-panel-after", panel.next_element["id"]
    assert_includes response.body, "hidden sm:flex"
    assert_includes response.body, "flex sm:hidden"
  end

  test "blank slot hooks leave the panel markup unchanged" do
    with_hooks(
      right_header: ->(_group_recording, actor:, mount:) { "" },
      right_header_mobile: ->(_group_recording, actor:, mount:) {},
      after: ->(_group_recording, actor:, mount:) { nil }
    ) do
      get_panel
      assert_equal stable_panel_html(rendered_baseline), stable_panel_html(render_panel_partial)
    end

    assert_select '[data-flat-pack-chat-panel-part="right-header"]', count: 0
    assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"]', count: 0
    assert_select '[data-flat-pack-chat-panel-part="header"]', count: 0
  end

  test "only the desktop header hook stays flex at every width" do
    with_hooks(
      right_header: lambda { |_group_recording, actor:, mount:|
        %(<span id="messages-panel-right-header">hook-right</span>).html_safe
      },
      right_header_mobile: nil,
      after: nil
    ) { get_panel }

    assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"]', count: 0
    assert_select '[data-flat-pack-chat-panel-part="header"]'
    part = css_select('[data-flat-pack-chat-panel-part="right-header"]').first
    assert_equal "flex shrink-0 w-min items-center justify-end", part["class"]
    assert_select '[data-flat-pack-chat-panel-part="right-header"] #messages-panel-right-header',
                  text: "hook-right"
    refute_includes response.body, "hidden sm:flex"
    refute_includes response.body, "messages-panel-after"
  end

  test "only the mobile header hook renders the compact slot" do
    with_hooks(
      right_header: nil,
      right_header_mobile: lambda { |_group_recording, actor:, mount:|
        %(<span id="messages-panel-right-header-mobile">hook-mobile</span>).html_safe
      },
      after: nil
    ) { get_panel }

    assert_select '[data-flat-pack-chat-panel-part="right-header"]', count: 0
    assert_select '[data-flat-pack-chat-panel-part="header"]'
    assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"] #messages-panel-right-header-mobile',
                  text: "hook-mobile"
    assert_includes response.body, "flex sm:hidden"
    refute_includes response.body, "hidden sm:flex"
    refute_includes response.body, "messages-panel-after"
    assert_includes response.body, "Studio help"
  end

  test "dummy header badge renders on the support mount and stays off the inbox mount" do
    get recording_studio_messages.message_group_path(@group),
        headers: { "Turbo-Frame" => "messages-desk-panel" }

    assert_response :success
    assert_select '[data-flat-pack-chat-panel-part="right-header"] #dummy-thread-status', text: "Open"
    assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"] #dummy-thread-status-mobile', text: "Open"

    get recording_studio_messages.message_group_path(DummyCatalog.inbox_group_recording),
        headers: { "Turbo-Frame" => "messages-desk-panel" }

    assert_response :success
    assert_includes response.body, "Site inbox"
    assert_select "#dummy-thread-status", count: 0
    assert_select "#dummy-thread-status-mobile", count: 0
    assert_select '[data-flat-pack-chat-panel-part="right-header"]', count: 0
  end

  test "overridden hooks are present in the my messages turbo stream panel replace" do
    with_hooks(
      right_header: lambda { |_group_recording, actor:, mount:|
        %(<span id="messages-panel-right-header">hook-right</span>).html_safe
      },
      right_header_mobile: lambda { |_group_recording, actor:, mount:|
        %(<span id="messages-panel-right-header-mobile">hook-mobile</span>).html_safe
      },
      after: lambda { |_group_recording, actor:, mount:|
        %(<div id="messages-panel-after">hook-after</div>).html_safe
      }
    ) do
      get recording_studio_messages.my_message_path(@group), as: :turbo_stream
    end

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    panel_html = stream_html("messages-desk-panel")
    assert_includes panel_html, "hook-right"
    assert_includes panel_html, "hook-mobile"
    assert_includes panel_html, "hook-after"
    assert_includes panel_html, 'data-flat-pack-chat-panel-part="right-header"'
    assert_includes panel_html, 'data-flat-pack-chat-panel-part="right-header-mobile"'
  end

  private

  def with_blank_hooks(&block)
    with_hooks(right_header: nil, right_header_mobile: nil, after: nil, &block)
  end

  def with_hooks(**overrides, &block)
    MessagesPanelHookOverrides.with_overrides(**overrides, &block)
  end

  def render_panel_partial
    view.render(
      partial: "recording_studio_messages/message_groups/panel",
      locals: panel_locals
    )
  end

  def rendered_baseline
    view.render(inline: PANEL_WITHOUT_HEADER_HOOKS, locals: panel_locals)
  end

  def get_panel
    get recording_studio_messages.message_group_path(@group),
        headers: { "Turbo-Frame" => "messages-desk-panel" }
    assert_response :success
  end

  def panel_locals
    {
      group_recording: controller.instance_variable_get(:@group_recording),
      message_recordings: controller.instance_variable_get(:@message_recordings),
      current_actor: controller.send(:current_messages_actor)
    }
  end

  def view
    controller.view_context
  end

  def stream_html(target)
    Nokogiri::HTML.fragment(response.body).at_css("turbo-stream[target='#{target}']")&.inner_html.to_s
  end

  def stable_panel_html(html)
    html.to_s.gsub(/__[a-f0-9]{8}/, "__id").rstrip
  end
end
