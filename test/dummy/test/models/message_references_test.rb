# frozen_string_literal: true

require "test_helper"

class MessageReferencesTest < ActiveSupport::TestCase
  setup do
    @staff = User.create!(
      email: "staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Ada Staff"
    )
    @customer = User.create!(
      email: "customer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Casey Patron"
    )
    @workspace = Workspace.create!(name: "Refs #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @staff)
    @mount = @root.ensure_message_mount("support", actor: @staff)
    @group = RecordingStudioMessages.create_group(@mount, title: "Refs conversation", actor: @staff)
    grant!(@group, @customer, :edit)
    @page = record_page!("Brand notes", parent: @root)
  end

  test "send_message writes a reference and appends title plus url" do
    Current.actor = @staff
    url = "/pages/#{@page.id}"

    message = RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "See this.",
      actor: @staff,
      references: [{ recording_id: @page.id, title: "Brand notes", url: url }],
      notify: false
    )

    row = RecordingStudioMessages::MessageReference.find_by!(message_recording_id: message.id)
    assert_equal @page.id, row.target_recording_id
    assert_includes message.recordable.body, "Brand notes"
    assert_includes message.recordable.body, url
  end

  test "send_message refuses a target the sender cannot view" do
    Current.actor = @customer

    error = assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages.send_message(
        group_recording: @group,
        body: "See this.",
        actor: @customer,
        references: [{ recording_id: @page.id, title: "Brand notes", url: "/pages/#{@page.id}" }],
        notify: false
      )
    end

    assert_equal RecordingStudioMessages::Copy.t("errors.cannot_attach_item"), error.message
    assert_equal 0, RecordingStudioMessages::MessageReference.count
  end

  test "send_message refuses a target outside the mount parent tree" do
    other = Workspace.create!(name: "Other #{SecureRandom.hex(4)}")
    other_root = RecordingStudio.root_recording_for(other)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: other_root, actor: @staff)
    outsider = record_page!("Elsewhere", parent: other_root, root: other_root)
    Current.actor = @staff

    assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages.send_message(
        group_recording: @group,
        body: "See this.",
        actor: @staff,
        references: [{ recording_id: outsider.id, title: "Elsewhere", url: "/pages/#{outsider.id}" }],
        notify: false
      )
    end
  end

  test "render hides unseen and trashed references" do
    Current.actor = @staff
    shown = RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Shown",
      actor: @staff,
      references: [{ recording_id: @page.id, title: "Brand notes", url: "/pages/#{@page.id}" }],
      notify: false
    )
    secret_page = record_page!("Secret", parent: @root)
    hidden = RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Hidden",
      actor: @staff,
      references: [{ recording_id: secret_page.id, title: "Secret", url: "/pages/#{secret_page.id}" }],
      notify: false
    )
    secret_page.update_column(:trashed_at, Time.current)

    visible_to_staff = RecordingStudioMessages.visible_message_references(
      [shown, hidden],
      actor: @staff
    )
    visible_to_customer = RecordingStudioMessages.visible_message_references(
      [shown, hidden],
      actor: @customer
    )

    assert_equal [@page.id], visible_to_staff[shown.id.to_s].map(&:id)
    assert_nil visible_to_staff[hidden.id.to_s]
    assert_nil visible_to_customer[shown.id.to_s]
    assert_nil visible_to_customer[hidden.id.to_s]
  end

  test "visible_message_references query count stays flat as the thread grows" do
    Current.actor = @staff
    messages = Array.new(4) do |index|
      RecordingStudioMessages.send_message(
        group_recording: @group,
        body: "Line #{index}",
        actor: @staff,
        references: [{ recording_id: @page.id, title: "Brand notes", url: "/pages/#{@page.id}" }],
        notify: false
      )
    end

    snapshot_query_count(messages.take(2))
    small = snapshot_query_count(messages.take(2))
    large = snapshot_query_count(messages)

    assert_equal small, large
  end

  private

  def grant!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  def record_page!(title, parent:, root: @root)
    RecordingStudio.record!(
      action: "created",
      recordable: Page.create!(title: title),
      root_recording: root,
      parent_recording: parent,
      actor: @staff
    ).recording
  end

  def snapshot_query_count(messages)
    count = 0
    callback = lambda do |*_args, payload|
      name = payload[:name].to_s
      next unless name.end_with?(" Load")
      next if name.include?("SCHEMA")
      next if name == "CACHE"

      count += 1
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      RecordingStudioMessages.visible_message_references(messages, actor: @staff)
    end
    count
  end
end
