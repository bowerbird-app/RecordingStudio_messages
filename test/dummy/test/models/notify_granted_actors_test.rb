# frozen_string_literal: true

require "test_helper"

class NotifyGrantedActorsTest < ActiveSupport::TestCase
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
    @workspace = Workspace.create!(name: "Notify #{SecureRandom.hex(4)}")
    @ticket_root = RecordingStudio.create_root_recording!(@workspace, actor: @staff)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @ticket_root, actor: @staff)
    @mount = @ticket_root.ensure_message_mount("support", actor: @staff)
    @group = RecordingStudioMessages.create_group(@mount, title: "Root filing", actor: @staff)
    result = RecordingStudioAccessible.grant_access(
      recording: @group,
      actor: @customer,
      role: :edit,
      manager_actor: @staff
    )
    raise result.error if result.failure?

    @admin_root_recordable = AdminRoot.create!(name: "Notify Admin #{SecureRandom.hex(4)}")
    @admin_root = RecordingStudio.create_root_recording!(@admin_root_recordable, actor: @staff)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @admin_root, actor: @staff)
  end

  teardown do
    RecordingStudioMessages.configuration.admin_notification_root = nil
  end

  test "default files every recipient under the ticket root" do
    RecordingStudioMessages.configuration.admin_notification_root = nil

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Default filing stays on the ticket.",
      actor: @customer,
      url: "/staff/message_center"
    )

    staff_note = last_message_received_for(@staff)
    assert_equal @ticket_root.id, staff_note.root_recording_id
    assert_equal @staff, staff_note.recipient
    assert_equal @group.id, staff_note.recording_id
    assert_equal "Default filing stays on the ticket.", staff_note.body
  end

  test "opted-in staff recipient is filed under the admin root" do
    RecordingStudioMessages.configuration.admin_notification_root = @admin_root

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Staff should see this in Admin.",
      actor: @customer,
      url: "/admin/support/messages?group_id=#{@group.id}"
    )

    staff_note = last_message_received_for(@staff)
    assert_equal @admin_root.id, staff_note.root_recording_id
    assert_nil staff_note.recording_id
    assert staff_note.body.blank?
    refute_includes staff_note.title.to_s, "Staff should see this in Admin."
    assert_equal @group.id, staff_note.metadata["message_group_id"]
    assert_equal @ticket_root, @group.root_recording
  end

  test "a member who can view the workspace stays on the ticket root when admin filing is on" do
    RecordingStudioMessages.configuration.admin_notification_root = @admin_root
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Workspace Member"
    )
    grant_root!(member)
    grant_group!(member)

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Members keep the workspace inbox.",
      actor: @staff,
      url: "/inbox"
    )

    member_note = last_message_received_for(member)
    assert_equal member, member_note.recipient
    assert_equal @ticket_root.id, member_note.root_recording_id
    refute_equal @admin_root.id, member_note.root_recording_id
    assert_equal @group.id, member_note.recording_id
    assert_equal "Members keep the workspace inbox.", member_note.body
    assert_equal "/inbox", member_note.url
  end

  test "admin root notice omits the message text" do
    RecordingStudioMessages.configuration.admin_notification_root = @admin_root
    secret = "Quiet line #{SecureRandom.hex(4)} stays off the admin copy."

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: secret,
      actor: @customer,
      url: "/admin/support/messages?group_id=#{@group.id}"
    )

    staff_note = last_message_received_for(@staff)
    assert_equal @admin_root.id, staff_note.root_recording_id
    assert_nil staff_note.recording_id
    assert staff_note.body.blank?
    refute_includes staff_note.body.to_s, secret
    refute_includes staff_note.title.to_s, secret
    assert_equal "New message in Root filing", staff_note.title
  end

  test "blank body notify copy uses the reference title" do
    RecordingStudioMessages.configuration.admin_notification_root = nil
    page = RecordingStudio.record!(
      action: "created",
      recordable: Page.create!(title: "Brand notes"),
      root_recording: @ticket_root,
      parent_recording: @ticket_root,
      actor: @staff
    ).recording

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "",
      actor: @staff,
      references: [{ recording_id: page.id, title: "Brand notes", url: "/pages/#{page.id}" }],
      url: "/inbox"
    )

    customer_note = last_personal_for(@customer)
    assert_equal "Brand notes", customer_note.body
    assert_equal "", RecordingStudioMessages.message_recordings(@group).last.recordable.body
  end

  test "callable admin_notification_root files staff under the returned recording" do
    RecordingStudioMessages.configuration.admin_notification_root = -> { @admin_root }

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Resolver points at Admin.",
      actor: @customer
    )

    staff_note = last_message_received_for(@staff)
    assert_equal @admin_root.id, staff_note.root_recording_id
    assert staff_note.body.blank?
    refute_includes staff_note.title.to_s, "Resolver points at Admin."
  end

  test "a guest gets one personal notice and a member keeps the workspace notice" do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Workspace Member"
    )
    grant_root!(member)
    grant_group!(member)
    extra_guest = User.create!(
      email: "guest-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Extra Guest"
    )
    grant_group!(extra_guest)
    access_calls = 0
    root_checks = 0
    original_access = RecordingStudioAccessible.method(:actors_with_access)
    original_authorized = RecordingStudioAccessible.method(:authorized?)

    RecordingStudioAccessible.stub(:actors_with_access, lambda { |**kwargs|
      access_calls += 1 if kwargs[:recording] == @ticket_root
      original_access.call(**kwargs)
    }) do
      RecordingStudioAccessible.stub(:authorized?, lambda { |**kwargs|
        root_checks += 1 if kwargs[:recording] == @ticket_root
        original_authorized.call(**kwargs)
      }) do
        RecordingStudioMessages.send_message(
          group_recording: @group,
          body: "The proof is ready.",
          actor: @staff,
          url: "/staff/message_center"
        )
      end
    end

    assert_equal 1, access_calls
    assert_equal 0, root_checks

    guest_note = last_personal_for(@customer)
    assert_equal 1, personal_count(@customer)
    assert_equal 0, message_received_count(@customer)
    assert_nil guest_note.root_recording_id
    assert_equal @group.id.to_s, guest_note.thread_key
    assert_equal "New message in Root filing", guest_note.title
    assert_equal "The proof is ready.", guest_note.body
    assert_equal guest_path, guest_note.url
    refute_includes guest_note.title.to_s, @workspace.name
    refute_includes guest_note.body.to_s, @workspace.name

    extra_note = last_personal_for(extra_guest)
    assert_equal guest_path, extra_note.url
    assert_equal 1, personal_count(extra_guest)

    member_note = last_message_received_for(member)
    assert_equal @ticket_root.id, member_note.root_recording_id
    assert_equal @group.id, member_note.recording_id
    assert_equal "/staff/message_center", member_note.url
    assert_equal "The proof is ready.", member_note.body
    assert_equal 0, personal_count(member)

    inbox = inbox_for(@customer, @admin_root)
    assert_includes inbox.map(&:id), guest_note.id
    assert_equal [guest_note.id], inbox.map(&:id)
  end

  test "older notifications keeps every recipient on the workspace notice" do
    RecordingStudioMessages.stub(:personal_notices_supported?, false) do
      RecordingStudioMessages.send_message(
        group_recording: @group,
        body: "Legacy filing.",
        actor: @staff,
        url: "/staff/message_center"
      )
    end

    note = last_message_received_for(@customer)
    assert_equal @ticket_root.id, note.root_recording_id
    assert_equal @group.id, note.recording_id
    assert_equal "/staff/message_center", note.url
    assert_equal 0, personal_count(@customer)
  end

  test "personal email default follows whether that channel is registered" do
    type = RecordingStudioNotifications.notification_types[:message_received_personal]
    assert_equal %i[in_app email], type.available_channels

    without_email = lambda { |name| name.to_sym == :in_app }
    with_email = lambda { |name| %i[in_app email].include?(name.to_sym) }

    RecordingStudioNotifications.channels.stub(:registered?, without_email) do
      RecordingStudioMessages.register_message_received_personal_type!
      assert_equal [:in_app],
                   RecordingStudioNotifications.notification_types[:message_received_personal].default_channels
    end

    RecordingStudioNotifications.channels.stub(:registered?, with_email) do
      RecordingStudioMessages.register_message_received_personal_type!
      assert_equal %i[in_app email],
                   RecordingStudioNotifications.notification_types[:message_received_personal].default_channels
    end
  ensure
    RecordingStudioMessages.register_message_received_personal_type!
  end

  private

  def grant_root!(actor)
    result = RecordingStudioAccessible.grant_access(
      recording: @ticket_root,
      actor: actor,
      role: :view,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  def grant_group!(actor)
    result = RecordingStudioAccessible.grant_access(
      recording: @group,
      actor: actor,
      role: :edit,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  def guest_path
    RecordingStudioMessages::Engine.routes.url_helpers.guest_conversation_path(@group)
  end

  def inbox_for(recipient, root_recording)
    RecordingStudioNotifications::Services::InboxScope.relation(
      recipient: recipient,
      actor: recipient,
      root_recording: root_recording,
      inbox_scope: "current_root"
    ).to_a
  end

  def personal_count(recipient)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received_personal",
      recipient: recipient
    ).count
  end

  def message_received_count(recipient)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received",
      recipient: recipient
    ).count
  end

  def last_personal_for(recipient)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received_personal",
      recipient: recipient
    ).order(:created_at).last
  end

  def last_message_received_for(recipient)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received",
      recipient: recipient
    ).order(:created_at).last
  end
end
