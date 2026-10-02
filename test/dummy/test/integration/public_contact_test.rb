# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PublicContactTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @otp_was = RecordingStudioUser.config.otp_enabled
    RecordingStudioUser.config.otp_enabled = true
    RecordingStudioUser::Engine.apply_otp_setup!(User)
    register_otp_channels!

    @staff = User.create!(
      email: "admin@admin.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Ada Staff",
      confirmed_at: Time.current
    )
    @workspace = Workspace.create!(name: "Contact #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    Current.actor = @staff
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @staff)
    mailbox = Mailbox.create!(name: "Contact mailbox #{SecureRandom.hex(4)}")
    mailbox_recording = RecordingStudio.record!(
      action: "created",
      recordable: mailbox,
      root_recording: @root,
      parent_recording: @root,
      actor: @staff
    ).recording
    @mount = mailbox_recording.ensure_message_mount("inbox", actor: @staff)
    @support = @root.ensure_message_mount("support", actor: @staff)
  end

  teardown do
    Current.actor = nil
    RecordingStudioUser.config.otp_enabled = @otp_was
  end

  test "unknown email confirms the profile and sends one conversation after the code" do
    groups_before = RecordingStudioMessages::MessageGroup.count
    messages_before = RecordingStudioMessages::Message.count
    notifications_before = message_received_count

    post contact_path, params: {
      name: "Ada Lovelace",
      email: "Ada@Example.com",
      body: "Please send the quieter crop."
    }

    assert_redirected_to recording_studio_messages.public_contact_verify_path
    assert_equal groups_before, RecordingStudioMessages::MessageGroup.count
    assert_equal messages_before, RecordingStudioMessages::Message.count
    assert_equal notifications_before, message_received_count

    user = User.find_by!(email: "ada@example.com")
    assert_equal 1, User.where(email: "ada@example.com").count
    assert_equal "otp", user.registered_with
    assert_nil user.confirmed_at
    assert_nil user.name

    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    challenge = RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id)
    assert_equal "registration", challenge.purpose
    code = challenge.decrypt_delivery_code!

    follow_redirect!
    assert_includes response.body, "ada@example.com"
    assert_select "input[name=code][maxlength='6']"

    post recording_studio_messages.public_contact_verify_path, params: { code: code }

    assert_redirected_to recording_studio_messages.public_contact_sent_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Message sent"
    assert_equal groups_before + 1, RecordingStudioMessages::MessageGroup.count
    assert_equal messages_before + 1, RecordingStudioMessages::Message.count
    assert_equal notifications_before + 1, message_received_count
    assert_equal 1, RecordingStudioMessages::Message.where(body: "Please send the quieter crop.").count

    user.reload
    assert user.confirmed?
    assert_nil user.name
    profile = RecordingStudioUser.profile_for(user)
    assert_equal "Ada", profile.first_name
    assert_equal "Lovelace", profile.last_name
    assert_equal "Ada Lovelace", Object.new.extend(RecordingStudioMessages::PanelHelper).message_sender_name(user)

    intent.reload
    assert_nil intent.body
    group = intent.group_recording
    message = RecordingStudioMessages::Message.find_by!(body: "Please send the quieter crop.")
    message_recording = RecordingStudio::Recording.find_by!(recordable: message)
    sender = message_recording.events.where(action: "created").order(:created_at).first.actor
    assert_equal user.id, sender.id
    assert_includes RecordingStudioMessages.granted_actors(group).map(&:id), @staff.id
    assert_includes RecordingStudioMessages.granted_actors(group).map(&:id), user.id

    notification = message_received_scope.order(:created_at).last
    assert_equal @staff.id, notification.recipient_id
  end

  test "confirmed email uses login OTP and leaves the profile unchanged" do
    existing = User.create!(
      email: "casey.kept@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Casey Patron",
      confirmed_at: Time.current
    )
    RecordingStudioUser.record_profile!(
      existing,
      actor: existing,
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    count = User.count
    groups_before = RecordingStudioMessages::MessageGroup.count
    messages_before = RecordingStudioMessages::Message.count
    notifications_before = message_received_count

    post contact_path, params: {
      name: "Someone Else",
      email: "Casey.Kept@example.com",
      body: "Still Casey."
    }
    assert_redirected_to recording_studio_messages.public_contact_verify_path
    assert_equal groups_before, RecordingStudioMessages::MessageGroup.count
    assert_equal messages_before, RecordingStudioMessages::Message.count
    assert_equal notifications_before, message_received_count

    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    challenge = RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id)
    assert_equal "login", challenge.purpose
    assert_equal existing.id, intent.user_id
    assert_equal count, User.count

    post recording_studio_messages.public_contact_verify_path, params: { code: challenge.decrypt_delivery_code! }

    assert_redirected_to recording_studio_messages.public_contact_sent_path
    follow_redirect!
    assert_includes response.body, "Message sent"
    assert_nil session["warden.user.user.key"]
    assert_equal existing.id, User.find_by!(email: "casey.kept@example.com").id
    assert_equal count, User.count
    assert_equal groups_before + 1, RecordingStudioMessages::MessageGroup.count
    assert_equal messages_before + 1, RecordingStudioMessages::Message.count
    assert_equal notifications_before + 1, message_received_count
    existing.reload
    assert_equal "Casey Patron", existing.name
    profile = RecordingStudioUser.profile_for(existing)
    assert_equal "Casey", profile.first_name
    assert_equal "Patron", profile.last_name
    message = RecordingStudioMessages::Message.find_by!(body: "Still Casey.")
    message_recording = RecordingStudio::Recording.find_by!(recordable: message)
    sender = message_recording.events.where(action: "created").order(:created_at).first.actor
    assert_equal existing.id, sender.id
    assert_includes RecordingStudioMessages.granted_actors(intent.reload.group_recording).map(&:id), existing.id
  end

  test "wrong code sends nothing" do
    post contact_path, params: { name: "Ada Lovelace", email: "wrong@example.com", body: "Do not send." }
    follow_redirect!
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    real_code = RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id).decrypt_delivery_code!
    wrong = real_code == "000000" ? "111111" : "000000"

    post recording_studio_messages.public_contact_verify_path, params: { code: wrong }

    assert_equal 0, RecordingStudioMessages::MessageGroup.count
    assert_equal 0, RecordingStudioMessages::Message.count
    assert_equal 0, message_received_count
    refute_includes response.body, "Message sent"
  end

  test "signed-in post ignores a different email and skips OTP" do
    visitor = User.create!(
      email: "visitor@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Visiting Person",
      confirmed_at: Time.current
    )
    sign_in visitor

    assert_no_difference -> { RecordingStudioUser::OtpChallenge.count } do
      post contact_path, params: {
        name: "Not Me",
        email: "other@example.com",
        body: "Sent while signed in."
      }
    end

    assert_redirected_to recording_studio_messages.public_contact_sent_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Message sent"
    assert_includes response.body, "View conversation"
    assert_nil User.find_by(email: "other@example.com")
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
    message = RecordingStudioMessages::Message.find_by!(body: "Sent while signed in.")
    message_recording = RecordingStudio::Recording.find_by!(recordable: message)
    sender = message_recording.events.where(action: "created").order(:created_at).first.actor
    assert_equal visitor.id, sender.id
  end

  test "support mount without public contact does not open a conversation" do
    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      error = assert_raises(RecordingStudioMessages::Error) do
        RecordingStudioMessages.begin_public_contact(
          mount_recording: @support,
          name: "Ada",
          email: "ada@example.com",
          body: "Hello",
          current_actor: nil,
          request: nil,
          session: {}
        )
      end
      assert_equal "Public contact is not enabled on this mount.", error.message

      get recording_studio_messages.public_contact_path(mount_id: @support.id)
      assert_response :not_found

      post recording_studio_messages.public_contact_path(mount_id: @support.id), params: {
        name: "Ada",
        email: "ada@example.com",
        body: "Hello"
      }
      assert_response :not_found
    end
  end

  test "a different actor cannot complete a pending intent" do
    post contact_path, params: { name: "Ada Lovelace", email: "owner@example.com", body: "Mine." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    stranger = User.create!(
      email: "stranger@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Stranger",
      confirmed_at: Time.current
    )

    error = assert_raises(RecordingStudioMessages::NotAuthorized) do
      RecordingStudioMessages.complete_public_contact(intent: intent, actor: stranger)
    end

    assert_equal "You cannot send this message.", error.message
    assert_equal 0, RecordingStudioMessages::MessageGroup.count
    assert_equal 0, RecordingStudioMessages::Message.count
    assert_nil intent.reload.message_group_id
  end

  test "complete twice returns the same group and does not send again" do
    post contact_path, params: { name: "Ada Lovelace", email: "twice@example.com", body: "Once only." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    code = RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id).decrypt_delivery_code!
    post recording_studio_messages.public_contact_verify_path, params: { code: code }

    user = User.find_by!(email: "twice@example.com")
    intent.reload
    first = intent.group_recording
    second = RecordingStudioMessages.complete_public_contact(intent: intent, actor: user)

    assert_equal first.id, second.id
    assert_equal 1, RecordingStudioMessages::MessageGroup.count
    assert_equal 1, RecordingStudioMessages::Message.count
  end

  test "signed-out form renders name email message and send" do
    get contact_path

    assert_response :success
    assert_includes response.body, "Name"
    assert_includes response.body, "Email"
    assert_includes response.body, "Message"
    assert_includes response.body, "Send message"
    assert_includes response.body, "Contact"
  end

  test "verify page shows the code field and the normalized email" do
    post contact_path, params: { name: "Ada Lovelace", email: "Ada@Example.com", body: "Hello there." }
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Check your email"
    assert_includes response.body, "We sent a 6-digit code to ada@example.com."
    assert_select "input[name=code][maxlength='6'][inputmode=numeric][autocomplete=one-time-code]"
    assert_select "button", text: "Confirm & send"
    assert_select "form[action=?]", recording_studio_messages.public_contact_resend_path
  end

  test "signed-in form has no editable email and shows the actor" do
    sign_in @staff
    get contact_path

    assert_response :success
    assert_select "input[name=email]", count: 0
    assert_select "input[type=email]", count: 0
    assert_includes response.body, "Ada Staff"
    assert_includes response.body, "admin@admin.com"
    assert_select "textarea[name=body]"
  end

  test "desk routes still require sign in" do
    get recording_studio_messages.message_groups_path
    assert_redirected_to new_user_session_path

    group = RecordingStudioMessages.create_group(@mount, title: "Existing desk", actor: @staff)
    post recording_studio_messages.message_group_messages_path(group), params: { message: { body: "nope" } }
    assert_redirected_to new_user_session_path

    get contact_path
    assert_response :success
  end

  test "expired code does not send" do
    post contact_path, params: { name: "Ada Lovelace", email: "expired-code@example.com", body: "Too late." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    challenge = RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id)
    code = challenge.decrypt_delivery_code!
    challenge.update!(expires_at: 1.minute.ago)

    post recording_studio_messages.public_contact_verify_path, params: { code: code }

    assert_equal 0, RecordingStudioMessages::MessageGroup.count
    assert_equal 0, RecordingStudioMessages::Message.count
    assert_equal 0, message_received_count
  end

  test "expired intent does not send" do
    post contact_path, params: { name: "Ada Lovelace", email: "expired-intent@example.com", body: "Too late." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    code = RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id).decrypt_delivery_code!
    intent.update!(expires_at: 1.hour.ago)

    post recording_studio_messages.public_contact_verify_path, params: { code: code }

    assert_equal 0, RecordingStudioMessages::MessageGroup.count
    assert_equal 0, RecordingStudioMessages::Message.count
    assert_equal 0, message_received_count
    assert_nil intent.reload.message_group_id
  end

  test "unconfirmed password user does not create a second user or a code" do
    existing = User.create!(
      email: "password-user@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      confirmed_at: Time.current
    )
    existing.update_column(:confirmed_at, nil)
    count = User.count

    post contact_path, params: {
      name: "Password User",
      email: "password-user@example.com",
      body: "I already signed up."
    }

    assert_equal count, User.count
    assert_equal 0, RecordingStudioUser::OtpChallenge.where(user_id: existing.id).count
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
    assert_includes response.body, "That email already has an account. Try signing in."
  end

  test "resend uses a separate rate limit and a second resend asks for a minute" do
    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    post contact_path, params: { name: "Ada Lovelace", email: "resend@example.com", body: "Need another code." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    first_challenge_id = intent.otp_challenge_id
    first_purpose = RecordingStudioUser::OtpChallenge.find(first_challenge_id).purpose

    post recording_studio_messages.public_contact_resend_path
    assert_redirected_to recording_studio_messages.public_contact_verify_path
    intent.reload
    assert_not_equal first_challenge_id, intent.otp_challenge_id
    assert_equal first_purpose, RecordingStudioUser::OtpChallenge.find(intent.otp_challenge_id).purpose
    assert_equal 0, RecordingStudioMessages::MessageGroup.count

    post recording_studio_messages.public_contact_resend_path
    assert_response :unprocessable_entity
    assert_includes response.body, "Give it a minute, then try again."
    assert_equal 0, RecordingStudioMessages::MessageGroup.count
  ensure
    Rails.cache = previous_cache
  end

  test "duplicate normalized email does not create two users" do
    post contact_path, params: { name: "Ada Lovelace", email: "Ada@Example.com", body: "First try." }
    assert_equal 1, User.where(email: "ada@example.com").count

    post contact_path, params: { name: "Ada Lovelace", email: "ada@example.com", body: "Second try." }

    assert_equal 1, User.where(email: "ada@example.com").count
    assert_equal 0, RecordingStudioMessages::MessageGroup.count
  end

  private

  def register_otp_channels!
    adapter = Class.new do
      def deliver(notification:, delivery:)
        delivery.mark_delivered! if delivery.respond_to?(:mark_delivered!)
        notification
      end
    end.new
    RecordingStudioNotifications.register_channel(:email, adapter)
    RecordingStudioNotifications.register_channel(:push, adapter)
  end

  def contact_path
    recording_studio_messages.public_contact_path(mount_id: @mount.id)
  end

  def message_received_scope
    RecordingStudioNotifications::Notification.where(notification_type: "message_received")
  end

  def message_received_count
    message_received_scope.count
  end
end
