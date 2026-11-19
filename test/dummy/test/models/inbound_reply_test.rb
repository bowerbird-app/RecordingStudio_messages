# frozen_string_literal: true

require "test_helper"

class InboundReplyTest < ActiveSupport::TestCase
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
    @workspace = Workspace.create!(name: "Reply #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(@workspace, actor: @staff)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @staff)
    @mount = @root.ensure_message_mount("support", actor: @staff)
    @group = RecordingStudioMessages.create_group(@mount, title: "Reply conversation", actor: @staff)
    grant!(@customer, :edit)
    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "The print is ready.",
      actor: @staff,
      url: "/staff/message_center"
    )
  end

  test "a guest with only a conversation grant replies and notifies the other person after commit" do
    calls = 0
    result = nil
    original = RecordingStudioNotifications.method(:notify_each)
    RecordingStudioNotifications.stub(:notify_each, lambda { |*args, **kwargs, &block|
      calls += 1
      original.call(*args, **kwargs, &block)
    }) do
      RecordingStudioNotifications::Reply.transaction do
        result = reply_to(@customer, body: "I will pick it up.")
        assert_equal 0, calls
      end
    end

    assert result.ok?
    assert_equal 1, calls
    messages = RecordingStudioMessages.message_recordings(@group).to_a
    posted = messages.last
    assert_equal 2, messages.size
    created = posted.events.find { |event| event.action == "created" }
    assert_equal @customer, created.actor
    assert_equal "I will pick it up.", posted.recordable.body

    staff_notes = workspace_notices_for(@staff)
    assert_equal 1, staff_notes.count
    note = staff_notes.first
    assert_equal @group.id.to_s, note.thread_key
    assert_equal @root.id, note.root_recording_id
    assert_equal @group.id, note.recording_id
    assert_equal @customer, note.actor
    assert_includes note.body, "I will pick it up."
    assert_equal conversation_url, note.url
    opening = personal_notices_for(@customer).first
    assert_equal 1, personal_notices_for(@customer).count
    assert_equal 0, workspace_notices_for(@customer).count
    assert_equal @group.id.to_s, opening.thread_key
    assert_nil opening.root_recording_id
    assert_equal guest_url, opening.url
    refute RecordingStudioAccessible.authorized?(actor: @customer, recording: @root, role: :view)
  end

  test "a recipient without edit is rejected and nothing is posted" do
    viewer = User.create!(
      email: "viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "View Only"
    )
    grant!(viewer, :view)
    RecordingStudioMessages.send_message(group_recording: @group, body: "Still here.", actor: @staff)
    before = message_count

    result = reply_to(viewer, body: "I should not be able to send.")

    assert result.rejected?
    assert_equal :not_authorized, result.reason
    assert_equal before, message_count
  end

  test "a missing or trashed conversation is rejected" do
    missing = notice_for(@customer)
    missing.update!(metadata: missing.metadata.merge("message_group_id" => SecureRandom.uuid))

    result = reply_to(@customer, body: "Still there?", notification: missing)

    assert result.rejected?
    assert_equal :group_missing, result.reason
    assert_equal 1, message_count

    missing.update!(metadata: missing.metadata.merge("message_group_id" => @group.id.to_s))
    @group.update!(trashed_at: Time.current)
    trashed = reply_to(@customer, body: "And now?")

    assert trashed.rejected?
    assert_equal :group_missing, trashed.reason
    assert_equal 1, message_count
  end

  test "a blank reply is rejected" do
    result = reply_to(@customer, body: "   ")

    assert result.rejected?
    assert_equal :empty, result.reason
    assert_equal 1, message_count
  end

  test "a raise inside the handler leaves no message and sends no notification" do
    RecordingStudioNotifications.register_reply_handler(:message_received_personal) do |notification:, recipient:, body:,
                                                                                         attachments:|
      RecordingStudioMessages::Services::InboundReply.call(notification:, recipient:, body:, attachments:)
      raise "reply blew up"
    end
    calls = 0
    result = nil
    before = message_count

    RecordingStudioNotifications.stub(:notify_each, ->(*) { calls += 1 }) do
      result = reply_to(@customer, body: "This should roll back.")
    end

    assert result.failed?
    assert_equal :handler_error, result.reason
    assert_equal before, message_count
    assert_equal 0, calls
    assert_equal 0, notices_for(@staff).count
  ensure
    RecordingStudioMessages.register_message_received_reply_handler!
  end

  test "a reply attaches the handed-off blobs" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("print notes"),
      filename: "notes.txt",
      content_type: "text/plain"
    )

    result = reply_to(@customer, body: "Notes attached.", attachments: [blob])

    assert result.ok?
    posted = RecordingStudioMessages.message_recordings(@group).last
    assert posted.has_attachments?
    names = posted.attachments.map { |attachment| attachment.recordable.original_filename }
    assert_equal ["notes.txt"], names
  end

  test "a rolled-back send does not notify" do
    calls = 0
    RecordingStudioNotifications.stub(:notify_each, ->(*) { calls += 1 }) do
      RecordingStudioMessages::Message.transaction do
        RecordingStudioMessages.send_message(group_recording: @group, body: "Held", actor: @staff)
        assert_equal 0, calls
        raise ActiveRecord::Rollback
      end
    end

    assert_equal 0, calls
    refute RecordingStudioMessages.message_recordings(@group).any? { |message| message.recordable.body == "Held" }
  end

  test "message_received offers email and keeps in-app as the default" do
    type = RecordingStudioNotifications.notification_types[:message_received]

    assert_equal [:in_app], type.default_channels
    assert_equal %i[in_app email], type.available_channels
    assert RecordingStudioNotifications.replyable?(:message_received)
    assert RecordingStudioNotifications.replyable?(:message_received_personal)
  end

  test "a host that registers the type keeps its channels and the reply handler" do
    RecordingStudioNotifications.register_notification_type(
      :message_received,
      label: "Host message",
      description: "Host copy",
      default_channels: [:in_app],
      available_channels: [:in_app],
      scope: :root
    )
    RecordingStudioMessages.register_message_received_type!
    RecordingStudioMessages.register_message_received_reply_handler!

    type = RecordingStudioNotifications.notification_types[:message_received]
    assert_equal "Host message", type.label
    assert_equal [:in_app], type.available_channels
    assert RecordingStudioNotifications.replyable?(:message_received)
    personal = RecordingStudioNotifications.notification_types[:message_received_personal]
    assert_equal :global, personal.scope
    assert RecordingStudioNotifications.replyable?(:message_received_personal)
  ensure
    restore_message_received_type!
  end

  test "older notifications registers nothing and omits thread_key" do
    RecordingStudioNotifications.reply_handlers.clear!
    with_reply_handler_hidden do
      RecordingStudioMessages.register_message_received_reply_handler!
      refute RecordingStudioNotifications.replyable?(:message_received)
    end

    RecordingStudioMessages.stub(:personal_notices_supported?, false) do
      RecordingStudioMessages.stub(:thread_key_supported?, false) do
        RecordingStudioMessages.send_message(group_recording: @group, body: "Legacy path", actor: @staff)
      end
    end

    assert_nil workspace_notices_for(@customer).order(:created_at).last.thread_key
    assert_equal @root.id, workspace_notices_for(@customer).order(:created_at).last.root_recording_id
  ensure
    RecordingStudioMessages.register_message_received_reply_handler!
  end

  private

  def grant!(actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: @group,
      actor: actor,
      role: role,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  def reply_to(actor, body:, attachments: [], notification: nil)
    RecordingStudioNotifications.handle_reply(
      notification: notification || notice_for(actor),
      recipient: actor,
      body: body,
      attachments: attachments,
      channel: "email",
      idempotency_key: SecureRandom.uuid
    )
  end

  def notice_for(actor)
    notices_for(actor).order(:created_at).last
  end

  def notices_for(actor)
    personal_notices_for(actor).or(workspace_notices_for(actor))
  end

  def personal_notices_for(actor)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received_personal",
      recipient: actor
    )
  end

  def workspace_notices_for(actor)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received",
      recipient: actor
    )
  end

  def guest_url
    RecordingStudioMessages::Engine.routes.url_helpers.guest_conversation_path(@group)
  end

  def message_count
    RecordingStudioMessages.message_recordings(@group).count
  end

  def conversation_url
    RecordingStudioMessages::Engine.routes.url_helpers.message_group_path(@group)
  end

  def restore_message_received_type!
    RecordingStudioNotifications.register_notification_type(
      :message_received,
      **RecordingStudioMessages.message_received_type_options
    )
  end

  def with_reply_handler_hidden
    singleton = RecordingStudioNotifications.singleton_class
    singleton.alias_method(:respond_to_with_reply_handler?, :respond_to?)
    singleton.define_method(:respond_to?) do |method_name, include_all = false|
      return false if method_name.to_sym == :register_reply_handler

      respond_to_with_reply_handler?(method_name, include_all)
    end
    yield
  ensure
    singleton.alias_method(:respond_to?, :respond_to_with_reply_handler?)
  end
end
