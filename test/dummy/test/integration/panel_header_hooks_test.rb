# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Hosts override PanelHelper the way Support overrides messages_inbox_href.
# This stand-in lives in the test helper path so a request can turn the hooks
# on without changing the engine defaults.
module MessagesPanelHookOverrides
  def messages_panel_right_header(group_recording)
    override = MessagesPanelHookOverrides.current[:right_header]
    return override.call(group_recording) if override

    super
  end

  def messages_panel_right_header_mobile(group_recording)
    override = MessagesPanelHookOverrides.current[:right_header_mobile]
    return override.call(group_recording) if override

    super
  end

  def messages_panel_after(group_recording)
    override = MessagesPanelHookOverrides.current[:after]
    return override.call(group_recording) if override

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

RecordingStudioMessages::PanelHelper.prepend(MessagesPanelHookOverrides) unless
  RecordingStudioMessages::PanelHelper.ancestors.include?(MessagesPanelHookOverrides)

class PanelHeaderHooksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Panel markup from before the header hooks, rendered against the Flatpack
  # that is pinned now (v0.1.329). This is not a frozen snapshot from an older
  # kit. Defaults must match this render exactly.
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

  test "default header hooks return nothing" do
    helper = Object.new.extend(RecordingStudioMessages::PanelHelper)

    assert_nil helper.messages_panel_right_header(@group)
    assert_nil helper.messages_panel_right_header_mobile(@group)
    assert_nil helper.messages_panel_after(@group)
  end

  test "default hooks leave the panel html identical to the panel without those slots" do
    get_panel
    html = render_panel_partial

    assert_equal stable_panel_html(rendered_baseline), stable_panel_html(html)
    assert_includes stable_panel_html(response.body), stable_panel_html(html)
    assert_select '[data-flat-pack-chat-panel-part="header"]', count: 0
    assert_select '[data-flat-pack-chat-panel-part="right-header"]', count: 0
    assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"]', count: 0
  end

  test "overridden hooks render both header slots and the after content" do
    seen = []
    with_hooks(
      right_header: lambda { |group_recording|
        seen << group_recording
        %(<span id="messages-panel-right-header">hook-right</span>).html_safe
      },
      right_header_mobile: lambda { |group_recording|
        seen << group_recording
        %(<span id="messages-panel-right-header-mobile">hook-mobile</span>).html_safe
      },
      after: lambda { |group_recording|
        seen << group_recording
        %(<div id="messages-panel-after">hook-after</div>).html_safe
      }
    ) { get_panel }

    assert_equal [@group, @group, @group], seen
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
      right_header: ->(_group_recording) { "" },
      right_header_mobile: ->(_group_recording) {},
      after: ->(_group_recording) { nil }
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
      right_header: lambda { |_group_recording|
        %(<span id="messages-panel-right-header">hook-right</span>).html_safe
      }
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
      right_header_mobile: lambda { |_group_recording|
        %(<span id="messages-panel-right-header-mobile">hook-mobile</span>).html_safe
      }
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

  private

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

  # Composer field ids include a random suffix. The markup around them is stable.
  def stable_panel_html(html)
    html.to_s.gsub(/__[a-f0-9]{8}/, "__id")
  end
end
