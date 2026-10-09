# frozen_string_literal: true

require "test_helper"

class MetricsTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
    @workspace = Workspace.find_by!(name: "Studio Workspace")
    @root = RecordingStudio.root_recording_for(@workspace)
    @mount = @root.ensure_message_mount("support", actor: @staff)
  end

  test "sent_over_time counts live message recordings not revisions or trash" do
    group = RecordingStudioMessages.create_group(@mount, title: "Metric thread", actor: @staff)
    first = RecordingStudioMessages.send_message(
      group_recording: group,
      body: "First live line",
      actor: @staff,
      notify: false
    )
    second = RecordingStudioMessages.send_message(
      group_recording: group,
      body: "Second live line",
      actor: @staff,
      notify: false
    )
    RecordingStudio.record!(
      action: "updated",
      recording: first,
      recordable: RecordingStudioMessages::Message.new(body: "Revised first line"),
      actor: @staff
    )
    second.update!(trashed_at: Time.current)

    kept = live_recordings(RecordingStudioMessages::MESSAGE_TYPE)
    refute_includes kept.map(&:id), second.id
    assert_includes kept.map(&:id), first.id
    assert_operator RecordingStudioMessages::Message.count, :>,
                    RecordingStudio::Recording.where(recordable_type: RecordingStudioMessages::MESSAGE_TYPE).count

    result = execute_metric("messages.sent_over_time")
    assert_equal kept.count, timeseries_total(result)
  end

  test "created_over_time counts live conversations not trash" do
    live = RecordingStudioMessages.create_group(@mount, title: "Kept conversation", actor: @staff)
    trashed = RecordingStudioMessages.create_group(@mount, title: "Trashed conversation", actor: @staff)
    RecordingStudio.record!(
      action: "updated",
      recording: live,
      recordable: RecordingStudioMessages::MessageGroup.new(title: "Renamed conversation"),
      actor: @staff
    )
    trashed.update!(trashed_at: Time.current)

    kept = live_recordings(RecordingStudioMessages::MESSAGE_GROUP_TYPE)
    refute_includes kept.map(&:id), trashed.id
    assert_includes kept.map(&:id), live.id

    result = execute_metric("message_groups.created_over_time")
    assert_equal kept.count, timeseries_total(result)
  end

  test "contact intent metrics split submitted time and conversion" do
    group = RecordingStudioMessages.create_group(@mount, title: "From contact", actor: @staff)
    create_intent(email: "converted@example.com", message_group_id: group.id, body: nil)
    create_intent(email: "pending@example.com", expires_at: 2.hours.from_now)
    create_intent(email: "expired@example.com", expires_at: 2.hours.ago)

    submitted = execute_metric("contact_intents.submitted_over_time")
    assert_equal RecordingStudioMessages::PublicContactIntent.count, timeseries_total(submitted)

    converted = execute_metric("contact_intents.converted")
    by_key = converted.data.to_h { |row| [row[:key] || row["key"], row[:value] || row["value"]] }
    assert_equal 1, by_key["converted"]
    assert_equal 1, by_key["expired"]
    assert_equal 1, by_key["pending"]
  end

  test "staff can view operations metrics and a non-admin cannot" do
    staff_context = api_context_for(@staff)
    customer_context = api_context_for(@customer)
    definition = RecordingStudioMetrics.find("messages.sent_over_time")

    assert RecordingStudioMessages::Api::Access.can_view?(staff_context)
    refute RecordingStudioMessages::Api::Access.can_view?(customer_context)

    allowed = RecordingStudioMetrics::Api.context_from_api(staff_context, definition: definition)
    denied = RecordingStudioMetrics::Api.context_from_api(customer_context, definition: definition)

    assert_equal :site, allowed.scope
    assert allowed.site_authorized?
    assert_nil denied
  end

  private

  def live_recordings(recordable_type)
    RecordingStudio::Recording.where(recordable_type: recordable_type, trashed_at: nil)
  end

  def execute_metric(identifier)
    RecordingStudioMetrics.execute(
      identifier,
      context: RecordingStudioMetrics::Context.new(actor: @staff, scope: :site, site_authorized: true),
      cache: false
    )
  end

  def timeseries_total(result)
    result.data.sum { |row| row[:value] || row["value"] || 0 }
  end

  def api_context_for(actor)
    grant = Struct.new(:actor).new(actor)
    Struct.new(:access_grant, :access_recording, :root_recording, :api_key, :params).new(
      grant,
      nil,
      nil,
      :operations,
      {}
    )
  end

  def create_intent(email:, expires_at: 1.day.from_now, message_group_id: nil, body: "Hello from the form")
    RecordingStudioMessages::PublicContactIntent.create!(
      mount_recording_id: @mount.id,
      user_id: @customer.id,
      otp_challenge_id: SecureRandom.uuid,
      message_group_id: message_group_id,
      email: email,
      submitted_name: "Casey",
      body: body,
      expires_at: expires_at
    )
  end
end
