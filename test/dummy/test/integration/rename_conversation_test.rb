# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RenameConversationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
    @group = DummyCatalog.support_group_recording
  end

  test "edit access can rename the conversation and updates the list row title" do
    sign_in @staff
    get recording_studio_messages.message_groups_path(mount_id: DummyCatalog.support_mount_recording.id)

    assert_response :success
    assert_select ".fp-inline-edit[data-controller='flat-pack--inline-edit']"
    assert_select "input[type=hidden][name='message_group[title]']"
    assert_select "turbo-frame#messages-inbox-title-#{@group.id} p", text: "Studio help"
    assert_select '[data-flat-pack-chat-panel-part="right-header"] > .flex.items-center.gap-2.whitespace-nowrap.p-4 #dummy-thread-status',
                  text: "Open"
    assert_select '[data-flat-pack-chat-panel-part="right-header-mobile"] > .flex.items-center.gap-2.whitespace-nowrap.p-4 #dummy-thread-status-mobile',
                  text: "Open"

    original_recordable_id = @group.recordable_id
    new_title = "Quieter hero"

    assert_difference -> { @group.events.count }, +1 do
      patch recording_studio_messages.rename_message_group_path(@group),
            params: { message_group: { title: "  #{new_title}  " } },
            as: :turbo_stream
    end

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    @group.reload
    assert_equal new_title, @group.recordable.title
    assert_not_equal original_recordable_id, @group.recordable_id
    assert_equal "updated", @group.events.first.action
    targets = css_select("turbo-stream").map { |node| node["target"] }
    assert_equal ["messages-inbox-title-#{@group.id}"], targets
    row_html = stream_html("messages-inbox-title-#{@group.id}")
    assert_includes row_html, new_title
    refute_includes row_html, "Launch notes"
    assert_match(/<p[^>]*>#{Regexp.escape(new_title)}<\/p>/, row_html)
    refute_includes response.body, "flat-pack--chat-layout"
  end

  test "view access keeps a plain title and cannot rename" do
    viewer = User.create!(
      email: "rename-viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Viewer",
      confirmed_at: Time.current
    )
    grant_role!(@group, viewer, :view)

    sign_in viewer
    get recording_studio_messages.message_group_path(@group)

    assert_response :success
    assert_includes response.body, "Studio help"
    refute_includes response.body, "flat-pack--inline-edit"
    refute_includes response.body, "message_group[title]"

    original_recordable_id = @group.recordable_id
    patch recording_studio_messages.rename_message_group_path(@group),
          params: { message_group: { title: "Should not stick" } },
          as: :turbo_stream

    assert_response :forbidden
    @group.reload
    assert_equal "Studio help", @group.recordable.title
    assert_equal original_recordable_id, @group.recordable_id
  end

  test "a stranger cannot rename a conversation they cannot open" do
    stranger = User.create!(
      email: "rename-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Stranger",
      confirmed_at: Time.current
    )

    sign_in stranger
    patch recording_studio_messages.rename_message_group_path(@group),
          params: { message_group: { title: "Leaked" } }

    assert_response :not_found
    @group.reload
    assert_equal "Studio help", @group.recordable.title
  end

  test "blank and too-long names keep the old title" do
    sign_in @staff
    original_recordable_id = @group.recordable_id

    assert_no_difference -> { @group.events.count } do
      patch recording_studio_messages.rename_message_group_path(@group),
            params: { message_group: { title: "   " } },
            as: :turbo_stream
    end

    assert_response :unprocessable_entity
    @group.reload
    assert_equal "Studio help", @group.recordable.title
    assert_equal original_recordable_id, @group.recordable_id

    too_long = "A" * (RecordingStudioMessages::MessageGroup::TITLE_MAX + 1)
    assert_no_difference -> { @group.events.count } do
      patch recording_studio_messages.rename_message_group_path(@group),
            params: { message_group: { title: too_long } },
            as: :turbo_stream
    end

    assert_response :unprocessable_entity
    @group.reload
    assert_equal "Studio help", @group.recordable.title
    assert_equal original_recordable_id, @group.recordable_id
  end

  test "tags do not grant rename" do
    tagged = RecordingStudioMessages.create_group(
      DummyCatalog.support_mount_recording,
      title: "Tagged only",
      actor: @staff
    )
    RecordingStudioMessages.tag(
      tagged,
      key: "press_center",
      recording: RecordingStudio.root_recording_for(DummyCatalog.studio_workspace)
    )
    viewer = User.create!(
      email: "rename-tagged-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Tagged",
      confirmed_at: Time.current
    )

    sign_in viewer
    patch recording_studio_messages.rename_message_group_path(tagged),
          params: { message_group: { title: "From a tag" } }

    assert_response :not_found
    tagged.reload
    assert_equal "Tagged only", tagged.recordable.title
  end

  test "a mismatched mount_id does not rename" do
    sign_in @staff
    patch recording_studio_messages.rename_message_group_path(
      @group,
      mount_id: DummyCatalog.inbox_mount_recording.id
    ), params: { message_group: { title: "Wrong desk" } }

    assert_response :not_found
    @group.reload
    assert_equal "Studio help", @group.recordable.title
  end

  private

  def grant_role!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  def stream_html(target)
    Nokogiri::HTML.fragment(response.body).at_css("turbo-stream[target='#{target}']")&.inner_html.to_s
  end
end
