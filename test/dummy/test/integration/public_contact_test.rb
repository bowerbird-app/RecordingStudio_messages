# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "cgi"

class PublicContactTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveSupport::Testing::TimeHelpers

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

    assert_redirected_to otp_challenge_path
    assert_equal groups_before, RecordingStudioMessages::MessageGroup.count
    assert_equal messages_before, RecordingStudioMessages::Message.count
    assert_equal notifications_before, message_received_count

    user = User.find_by!(email: "ada@example.com")
    assert_equal 1, User.where(email: "ada@example.com").count
    assert_equal "otp", user.registered_with
    assert_nil user.confirmed_at
    assert_nil user.name

    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    assert_equal "registration", otp_purpose_for(intent)

    follow_redirect!
    assert_includes response.body, "a***@example.com"
    refute_includes response.body, "ada@example.com"
    assert_select "input[name=code][maxlength='6']"

    deliver_code!(intent)

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
    assert_nil profile.time_zone
    assert_equal "Ada Lovelace", Object.new.extend(RecordingStudioMessages::PanelHelper).message_sender_name(user)

    intent.reload
    assert_nil intent.body
    group = intent.group_recording
    message = RecordingStudioMessages::Message.find_by!(body: "Please send the quieter crop.")
    message_recording = RecordingStudio::Recording.find_by!(recordable: message)
    sender = message_recording.events.where(action: "created").order(:created_at).first.actor
    assert_equal user.id, sender.id
    refute_includes RecordingStudioMessages.granted_actors(group).map(&:id), @staff.id
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
    assert_redirected_to otp_challenge_path
    assert_equal groups_before, RecordingStudioMessages::MessageGroup.count
    assert_equal messages_before, RecordingStudioMessages::Message.count
    assert_equal notifications_before, message_received_count

    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    assert_equal "login", otp_purpose_for(intent)
    assert_equal existing.id, intent.user_id
    assert_equal count, User.count

    deliver_code!(intent)

    assert_redirected_to recording_studio_messages.public_contact_sent_path
    follow_redirect!
    assert_includes response.body, "Message sent"
    assert_equal existing.id, session["warden.user.user.key"]&.first&.first
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
    real_code = otp_code_for(intent)
    wrong = real_code == "000000" ? "111111" : "000000"

    post otp_challenge_path, params: { code: wrong }

    assert_response :unprocessable_entity
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

    assert_no_difference -> { otp_notification_count } do
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
    assert_select ".text-center h1.fp-heading.font-semibold", text: "Message sent"
    assert_includes response.body, "text-[length:var(--text-3xl)]"
    assert_select "svg[data-flat-pack--icon-name-value=?]", "rocket-launch"
    assert_includes response.body, "Powered by #{@workspace.name}"
    refute_includes response.body, "Your message has been sent."
    assert_select "a[data-turbo-frame=_top][data-fp-style=primary]", text: "View conversation"
    assert_select "link[href*='flat_pack/application']"
    assert_select "title", text: "Message sent"
    assert_nil User.find_by(email: "other@example.com")
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
    message = RecordingStudioMessages::Message.find_by!(body: "Sent while signed in.")
    message_recording = RecordingStudio::Recording.find_by!(recordable: message)
    sender = message_recording.events.where(action: "created").order(:created_at).first.actor
    assert_equal visitor.id, sender.id
  end

  test "sent screen icon slot follows configuration" do
    sign_in @staff
    post contact_path, params: { body: "Show the rocket." }
    follow_redirect!

    assert_select ".text-center h1.fp-heading.font-semibold", text: "Message sent"
    assert_includes response.body, "text-[length:var(--text-3xl)]"
    assert_select "[data-public-contact-step=sent] svg[data-flat-pack--icon-name-value=?]", "rocket-launch"
    assert_select "[data-public-contact-step=sent] img", count: 0

    RecordingStudioMessages.configuration.public_contact_sent_icon = "paper-airplane"
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] svg[data-flat-pack--icon-name-value=?]", "paper-airplane"
    assert_select "[data-public-contact-step=sent] img", count: 0

    RecordingStudioMessages.configuration.public_contact_sent_icon = nil
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] svg[data-controller='flat-pack--icon']", count: 0
    assert_select "[data-public-contact-step=sent] img", count: 0
    assert_select ".text-center h1.fp-heading.font-semibold", text: "Message sent"
    assert_includes response.body, "text-[length:var(--text-3xl)]"
  ensure
    RecordingStudioMessages.configuration.public_contact_sent_icon = "rocket-launch"
  end

  test "sent screen icon slot renders an image for a path or URL" do
    sign_in @staff
    post contact_path, params: { body: "Show the mark." }
    follow_redirect!

    RecordingStudioMessages.configuration.public_contact_sent_icon = "/icon.png"
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] img.block.h-8.w-8[src=?]", "/icon.png"
    assert_select "[data-public-contact-step=sent] svg[data-controller='flat-pack--icon']", count: 0

    RecordingStudioMessages.configuration.public_contact_sent_icon = "https://cdn.example.com/sent.webp"
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] img[src=?]", "https://cdn.example.com/sent.webp"
    assert_select "[data-public-contact-step=sent] svg[data-controller='flat-pack--icon']", count: 0

    RecordingStudioMessages.configuration.public_contact_sent_icon = "images/brand-mark.png"
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] img[src=?]", "images/brand-mark.png"

    RecordingStudioMessages.configuration.public_contact_sent_icon = "mark.svg"
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] img[src=?]", "mark.svg"
    assert_select "[data-public-contact-step=sent] svg[data-controller='flat-pack--icon']", count: 0

    RecordingStudioMessages.configuration.public_contact_sent_icon = "http://cdn.example.com/mark.gif"
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] img[src=?]", "http://cdn.example.com/mark.gif"

    RecordingStudioMessages.configuration.public_contact_sent_icon = "brand/mark"
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] img[src=?]", "brand/mark"
    assert_select "[data-public-contact-step=sent] svg[data-controller='flat-pack--icon']", count: 0

    RecordingStudioMessages.configuration.public_contact_sent_icon = nil
    get recording_studio_messages.public_contact_sent_path
    assert_select "[data-public-contact-step=sent] img", count: 0
    assert_select "[data-public-contact-step=sent] svg[data-controller='flat-pack--icon']", count: 0
  ensure
    RecordingStudioMessages.configuration.public_contact_sent_icon = "rocket-launch"
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
          request: contact_request,
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
    code = otp_code_for(intent)
    deliver_code!(intent, code: code)

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
    assert_select "h1.fp-heading.font-semibold", text: "Contact"
    assert_includes response.body, "text-[length:var(--text-xl)]"
  end

  test "code page is the Users screen with a masked email" do
    post contact_path, params: { name: "Ada Lovelace", email: "Ada@Example.com", body: "Hello there." }
    assert_redirected_to otp_challenge_path
    follow_redirect!

    assert_response :success
    assert_select "title", text: "Enter your code"
    assert_includes response.body, "a***@example.com"
    refute_includes response.body, "ada@example.com"
    refute_includes response.body, "Verify it's you"
    refute_includes response.body, "Check your email"
    refute_includes response.body, "Confirm & send"
    assert_select "input[name=code][maxlength='6'][inputmode=numeric][autocomplete=one-time-code]"
    assert_select "button", text: "Continue"
    assert_select "button", text: "Resend code"
    assert_select "button", text: "Next", count: 0
  end

  test "signed-in form shows the actor name as a badge and hides the email" do
    sign_in @staff
    get contact_path

    assert_response :success
    assert_select "input[name=email]", count: 0
    assert_select "input[type=email]", count: 0
    assert_select "span.inline-flex", text: "Ada Staff"
    refute_includes response.body, "admin@admin.com"
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
    code = otp_code_for(intent)

    travel 11.minutes do
      post otp_challenge_path, params: { code: code }
      assert_response :unprocessable_entity
    end

    assert_equal 0, RecordingStudioMessages::MessageGroup.count
    assert_equal 0, RecordingStudioMessages::Message.count
    assert_equal 0, message_received_count
  end

  test "expired intent does not send" do
    post contact_path, params: { name: "Ada Lovelace", email: "expired-intent@example.com", body: "Too late." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    code = otp_code_for(intent)
    intent.update!(expires_at: 1.hour.ago)

    post otp_challenge_path, params: { code: code }
    assert_response :redirect
    post recording_studio_messages.public_contact_return_path,
         params: { contact_token: return_token_from(response.location) }

    assert_response :unprocessable_entity
    assert_includes response.body, "That contact form expired. Send it again."
    assert_equal 0, RecordingStudioMessages::MessageGroup.count
    assert_equal 0, RecordingStudioMessages::Message.count
    assert_equal 0, message_received_count
    assert_nil intent.reload.message_group_id
    assert User.find_by!(email: "expired-intent@example.com").confirmed?
  end

  test "unconfirmed password user is refused without a code or a new account" do
    existing = User.create!(
      email: "password-user@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      registered_with: "password",
      confirmed_at: Time.current
    )
    existing.update_column(:confirmed_at, nil)
    RecordingStudioUser.record_profile!(
      existing,
      actor: existing,
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "Eastern Time (US & Canada)"
    )
    count = User.count

    post contact_path, params: {
      name: "Someone Else",
      email: "password-user@example.com",
      body: "I already signed up."
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Confirm that email, then try again."
    assert_equal count, User.count
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
    assert_equal 0, RecordingStudioMessages::Message.count
    existing.reload
    assert_nil existing.confirmed_at
    assert_equal "password", existing.registered_with
    assert existing.valid_password?("Password123!")
    profile = RecordingStudioUser.profile_for(existing)
    assert_equal "Casey", profile.first_name
    assert_equal "Patron", profile.last_name
  end

  test "unconfirmed otp user is reused and then confirmed" do
    existing = RecordingStudioUser.create_unconfirmed_user!(email: "otp-existing@example.com")
    count = User.count

    post contact_path, params: {
      name: "Ada Lovelace",
      email: "otp-existing@example.com",
      body: "Same account."
    }

    assert_redirected_to otp_challenge_path
    assert_equal count, User.count
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    assert_equal existing.id, intent.user_id
    assert_equal "registration", otp_purpose_for(intent)
    assert_equal 0, RecordingStudioMessages::Message.count

    deliver_code!(intent)

    existing.reload
    assert_equal existing.id, User.find_by!(email: "otp-existing@example.com").id
    assert_equal count, User.count
    assert existing.confirmed?
    assert_equal "otp", existing.registered_with
    profile = RecordingStudioUser.profile_for(existing)
    assert_equal "Ada", profile.first_name
    assert_equal "Lovelace", profile.last_name
    assert_equal 1, RecordingStudioMessages::Message.where(body: "Same account.").count
  end

  test "a single submitted name is stored without a surname or time zone" do
    post contact_path, params: {
      name: "Madonna",
      email: "madonna@example.com",
      body: "One name."
    }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last

    deliver_code!(intent)

    user = User.find_by!(email: "madonna@example.com")
    profile = RecordingStudioUser.profile_for(user)
    assert_equal "Madonna", profile.first_name
    assert_nil profile.last_name
    assert_nil profile.time_zone
    assert_nil user.name
    assert_equal "Madonna", Object.new.extend(RecordingStudioMessages::PanelHelper).message_sender_name(user)
    assert_equal 1, RecordingStudioMessages::Message.where(body: "One name.").count
  end

  test "Users resend replaces the session code and a second resend waits" do
    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    post contact_path, params: { name: "Ada Lovelace", email: "resend@example.com", body: "Need another code." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    first_challenge_id = intent.otp_challenge_id

    post otp_resend_path
    assert_redirected_to otp_challenge_path
    assert_equal first_challenge_id, intent.reload.otp_challenge_id
    assert_not_equal first_challenge_id, session[:otp_challenge_id]
    assert_equal 0, RecordingStudioMessages::MessageGroup.count

    fresh_code = RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
    post otp_resend_path
    assert_redirected_to otp_challenge_path
    follow_redirect!
    assert_includes response.body, "Please wait before requesting another code."
    assert_equal 0, RecordingStudioMessages::MessageGroup.count

    deliver_code!(intent, code: fresh_code)
    assert_redirected_to recording_studio_messages.public_contact_sent_path
    assert_equal 1, RecordingStudioMessages::Message.where(body: "Need another code.").count
  ensure
    Rails.cache = previous_cache
  end

  test "modal frame renders the signed-out form without the page shell" do
    get contact_path(presentation: "modal"), headers: modal_headers

    assert_response :success
    assert_select "turbo-frame#public_contact"
    assert_select "input[name=name]"
    assert_select "input[name=email]"
    assert_select "textarea[name=body]"
    assert_select "h1", count: 0
    assert_select "input[name=presentation][value=modal]"
    assert_select "form[data-turbo-frame=?]", "public_contact"
    refute_includes response.body, "min-h-dvh"
    refute_includes response.body, "<html"
  end

  test "modal keeps the code step, errors, resend, and sent screen in the frame" do
    post contact_path, params: modal_message, headers: modal_headers

    assert_redirected_to contact_path(presentation: "modal")
    get response.location, headers: modal_headers

    assert_response :success
    assert_select "turbo-frame#public_contact h1", count: 0
    assert_select "[data-public-contact-step=verify]"
    assert_select "h2", text: "Verify it's you"
    assert_select "input[name=accept_terms]", count: 0
    assert_select "turbo-frame##{RecordingStudioUser::OtpCodeForm::FRAME_ID}"
    assert_select "button", text: "Continue"
    assert_select "button", text: "Resend code"
    assert_includes response.body, "a***@example.com"
    refute_includes response.body, "ada@example.com"
    refute_includes response.body, "min-h-dvh"

    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    wrong = otp_code_for(intent) == "000000" ? "111111" : "000000"
    post otp_challenge_path, params: { code: wrong }, headers: inline_otp_headers

    assert_response :unprocessable_entity
    assert_includes response.body, "That code did not work."
    assert_select "turbo-frame##{RecordingStudioUser::OtpCodeForm::FRAME_ID} input[name=code]"
    assert_equal 0, RecordingStudioMessages::Message.count

    post otp_resend_path, headers: inline_otp_headers
    assert_response :success
    assert_includes response.body, "If an eligible account exists, we sent a code."
    fresh_code = RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]

    deliver_modal_code!(intent, code: fresh_code)
    assert_redirected_to recording_studio_messages.public_contact_sent_path(presentation: "modal")
    get response.location, headers: modal_headers

    assert_select "turbo-frame#public_contact h1", text: "Message sent"
    assert_select "svg[data-flat-pack--icon-name-value=?]", "rocket-launch"
    assert_select "[data-public-contact-step=sent]"
    assert_includes response.body, "Powered by #{@workspace.name}"
    refute_includes response.body, "Your message has been sent."
    assert_select "a[data-turbo-frame=_top]", text: "View conversation"
    assert_equal 1, RecordingStudioMessages::Message.count

    sign_out :user
    get contact_path(presentation: "modal"), headers: modal_headers
    assert_select "input[name=name]"
    assert_select "h1", text: "Message sent", count: 0
    assert_select "input[name=code]", count: 0
  end

  test "opening the modal again resumes the code step without a new code" do
    post contact_path, params: modal_message(email: "resume@example.com"), headers: modal_headers
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    challenge_id = intent.otp_challenge_id
    codes_before = otp_notification_count

    get contact_path(presentation: "modal"), headers: modal_headers

    assert_select "turbo-frame#public_contact h1", count: 0
    assert_select "[data-public-contact-step=verify]"
    assert_select "button", text: "Continue"
    assert_equal challenge_id, intent.reload.otp_challenge_id
    assert_equal codes_before, otp_notification_count

    get contact_path
    assert_response :success
    assert_select "input[name=name]"
    assert_includes response.body, "min-h-dvh"
  end

  test "signed-in modal skips the code step" do
    sign_in @staff

    get contact_path(presentation: "modal"), headers: modal_headers
    assert_select "span.inline-flex", text: "Ada Staff"
    assert_select "input[name=email]", count: 0
    assert_select "h1", count: 0

    post contact_path, params: { body: "From the dialog.", presentation: "modal" }, headers: modal_headers
    assert_redirected_to recording_studio_messages.public_contact_sent_path(presentation: "modal")
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
    RecordingStudioSiteSettings.update!(@root, name: "Quiet Crop", actor: @staff)
    get response.location, headers: modal_headers
    assert_select "h1", text: "Message sent"
    assert_select "[data-public-contact-step=sent]"
    assert_includes response.body, "Powered by Quiet Crop"
    refute_includes response.body, "Your message has been sent."
    refute_includes response.body, ">Contact<"
    assert_select "a[data-turbo-frame=_top][data-fp-style=primary]", text: "View conversation"
  end

  test "expired modal offers a fresh form and the old code routes are gone" do
    post contact_path, params: modal_message(email: "expired-modal@example.com"), headers: modal_headers
    get response.location, headers: modal_headers
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    intent.update!(expires_at: 1.hour.ago)

    get contact_path(presentation: "modal"), headers: modal_headers
    assert_response :unprocessable_entity
    assert_includes response.body, "That contact form expired. Send it again."
    assert_select "a[href=?]", contact_path(presentation: "modal"), text: "Send it again"
    assert_equal 0, RecordingStudioMessages::Message.count

    get "/recording_studio_messages/public_contact/verify"
    assert_response :not_found

    get "/recording_studio_messages/public_contact/verify", params: { presentation: "modal" }
    assert_response :not_found

    post otp_challenge_path, params: { code: otp_code_for(intent) }, headers: inline_otp_headers
    assert_response :success
    post recording_studio_messages.public_contact_return_path,
         params: { contact_token: return_token_from(response.body), presentation: "modal" },
         headers: modal_headers
    assert_response :unprocessable_entity
    assert_select "a", text: "Send it again"
    assert_select "input[name=code]", count: 0
    assert_equal 0, RecordingStudioMessages::Message.count

    sign_out :user
    post contact_path, params: { name: "Ada Lovelace", email: "expired-page@example.com", body: "Too late." }
    page_intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    page_intent.update!(expires_at: 1.hour.ago)
    post otp_challenge_path, params: { code: otp_code_for(page_intent) }
    assert_response :redirect
    post recording_studio_messages.public_contact_return_path,
         params: { contact_token: return_token_from(response.location) }
    assert_response :unprocessable_entity
    assert_includes response.body, "That contact form expired. Send it again."
    assert_includes response.body, "min-h-dvh"
    assert_select "input[name=code]", count: 0
    assert_equal 0, RecordingStudioMessages::Message.count
  end

  test "a signed-in modal does not resume a signed-out code" do
    post contact_path, params: modal_message(email: "before-signin@example.com"), headers: modal_headers
    sign_in @staff

    get contact_path(presentation: "modal"), headers: modal_headers

    assert_select "span.inline-flex", text: "Ada Staff"
    assert_select "input[name=code]", count: 0

    sign_out @staff
    get contact_path(presentation: "modal"), headers: modal_headers
    assert_select "[data-public-contact-step=verify]"
    assert_select "button", text: "Continue"
  end

  test "modal frame keeps a custom introduction and submit label" do
    get contact_path(presentation: "modal", introduction: "We reply by email.", submit_label: "Send note"),
        headers: modal_headers

    assert_includes response.body, "We reply by email."
    assert_select "button", text: "Send note"
    assert_select "input[name=introduction][value=?]", "We reply by email."
    assert_select "input[name=submit_label][value=?]", "Send note"

    post contact_path,
         params: modal_message(email: "note@example.com").merge(
           introduction: "We reply by email.",
           submit_label: "Send note"
         ),
         headers: modal_headers
    assert_redirected_to contact_path(
      presentation: "modal",
      introduction: "We reply by email.",
      submit_label: "Send note"
    )
    verify_path = response.location
    get verify_path, headers: modal_headers
    assert_select "input[name=introduction][value=?]", "We reply by email."
    assert_select "input[name=submit_label][value=?]", "Send note"
    assert_select "button", text: "Resend code"

    RecordingStudioMessages::PublicContactIntent.order(:created_at).last.update!(expires_at: 1.hour.ago)
    get verify_path, headers: modal_headers
    assert_select "a[href=?]",
                  contact_path(presentation: "modal", introduction: "We reply by email.", submit_label: "Send note"),
                  text: "Send it again"
  end

  test "modal validation keeps the typed email in the frame" do
    post contact_path,
         params: { presentation: "modal", name: "", email: "ada@example.com", body: "Hi there." },
         headers: modal_headers

    assert_response :unprocessable_entity
    assert_includes response.body, "Enter your name."
    assert_select "turbo-frame#public_contact input[name=email][value=?]", "ada@example.com"
    assert_equal 0, RecordingStudioMessages::Message.count
  end

  test "presentation modal without the frame header still renders the page" do
    post contact_path, params: modal_message(email: "page-visit@example.com"), headers: modal_headers

    get contact_path(presentation: "modal")

    assert_response :success
    assert_select "h1", text: "Contact"
    assert_select "input[name=name]"
    assert_select "input[name=code]", count: 0
    assert_includes response.body, "min-h-dvh"
    assert_select "form[data-turbo=false]"

    get contact_path(presentation: "drawer")
    assert_select "h1", text: "Contact"
    assert_select "input[name=presentation]", count: 0
    assert_select "form[data-turbo=false]"
  end

  test "duplicate normalized email does not create two users" do
    post contact_path, params: { name: "Ada Lovelace", email: "Ada@Example.com", body: "First try." }
    assert_equal 1, User.where(email: "ada@example.com").count

    post contact_path, params: { name: "Ada Lovelace", email: "ada@example.com", body: "Second try." }

    assert_equal 1, User.where(email: "ada@example.com").count
    assert_equal 0, RecordingStudioMessages::MessageGroup.count
  end

  test "verified visitor is signed in even when the sign-in flag is off" do
    verify_contact(email: "default-off@example.com")

    user = User.find_by!(email: "default-off@example.com")
    assert_equal user.id, session["warden.user.user.key"]&.first&.first
    assert_select "[data-public-contact-success-redirect]", count: 0
    assert_select "a[href=?]", message_group_path_for_last_group, text: "View conversation"
  end

  test "sign in after verification signs in a newly registered visitor" do
    with_contact_config(public_contact_sign_in_after_verification: true) do
      verify_contact(email: "new-signin@example.com")

      user = User.find_by!(email: "new-signin@example.com")
      assert_equal user.id, session["warden.user.user.key"]&.first&.first
      assert_select "a[href=?]", message_group_path_for_last_group, text: "View conversation"
      assert_select "[data-public-contact-success-redirect]", count: 0
      assert_select "[data-public-contact-step=sent] a", count: 1
    end
  end

  test "sign in after verification signs in an existing confirmed user via login OTP" do
    existing = User.create!(
      email: "existing-signin@example.com", password: "Password123!",
      password_confirmation: "Password123!", name: "Existing Person", confirmed_at: Time.current
    )

    with_contact_config(public_contact_sign_in_after_verification: true) do
      verify_contact(email: "existing-signin@example.com", purpose: "login")

      assert_equal existing.id, session["warden.user.user.key"]&.first&.first
    end
  end

  test "wrong code does not sign in even when enabled" do
    with_contact_config(public_contact_sign_in_after_verification: true) do
      post contact_path, params: { name: "Ada Lovelace", email: "nope@example.com", body: "No." }
      intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
      wrong = otp_code_for(intent) == "000000" ? "111111" : "000000"

      post otp_challenge_path, params: { code: wrong }

      assert_response :unprocessable_entity
      assert_nil session["warden.user.user.key"]
    end
  end

  test "success redirect string shows one button with the default label for a new visitor" do
    with_contact_config(public_contact_success_redirect_url: "/inbox") do
      verify_contact(email: "button-new@example.com")

      user = User.find_by!(email: "button-new@example.com")
      assert_equal user.id, session["warden.user.user.key"]&.first&.first
      assert_select "[data-public-contact-step=sent] a", count: 1
      assert_select "a[data-public-contact-success-redirect][href=?]", "/inbox", text: "View conversation"
    end
  end

  test "success redirect callable receives context and custom label renders for an existing user" do
    User.create!(
      email: "button-existing@example.com", password: "Password123!",
      password_confirmation: "Password123!", name: "Button Person", confirmed_at: Time.current
    )
    seen = nil
    resolver = lambda do |mount_recording:, group_recording:, user:, request:|
      seen = [ mount_recording, group_recording, user, request ]
      "/people/#{user.id}"
    end

    with_contact_config(
      public_contact_success_redirect_url: resolver,
      public_contact_success_redirect_label: "Open my messages",
      public_contact_sign_in_after_verification: true
    ) do
      verify_contact(email: "button-existing@example.com", purpose: "login")

      user = User.find_by!(email: "button-existing@example.com")
      assert_select "[data-public-contact-step=sent] a", count: 1
      assert_select "a[data-public-contact-success-redirect][href=?]", "/people/#{user.id}", text: "Open my messages"
      assert_equal @mount.id, seen[0].id
      assert_equal last_group_recording.id, seen[1].id
      assert_equal user.id, seen[2].id
      assert seen[3].respond_to?(:host)
    end
  end

  test "success redirect button renders in the modal sent step and for signed-in senders" do
    with_contact_config(public_contact_success_redirect_url: "/inbox") do
      post contact_path, params: modal_message(email: "modal-button@example.com"), headers: modal_headers
      get response.location, headers: modal_headers
      intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
      deliver_modal_code!(intent)
      get recording_studio_messages.public_contact_sent_path(presentation: "modal"), headers: modal_headers
      assert_select "turbo-frame#public_contact [data-public-contact-step=sent] a", count: 1
      assert_select "turbo-frame#public_contact a[data-public-contact-success-redirect][href=?]", "/inbox"

      sign_in User.create!(
        email: "signed-in-button@example.com", password: "Password123!",
        password_confirmation: "Password123!", name: "Signed In", confirmed_at: Time.current
      )
      post contact_path, params: { body: "Hello while signed in." }
      follow_redirect!
      assert_select "[data-public-contact-step=sent] a", count: 1
      assert_select "a[data-public-contact-success-redirect][href=?]", "/inbox"
      assert_select "[data-public-contact-step=sent] a[href=?]", message_group_path_for_last_group, count: 0
    end
  end

  test "blank success redirect from a callable hides the button" do
    with_contact_config(
      public_contact_success_redirect_url: ->(**) { nil },
      public_contact_sign_in_after_verification: true
    ) do
      verify_contact(email: "blank-button@example.com")

      assert_select "[data-public-contact-success-redirect]", count: 0
      assert_select "[data-public-contact-step=sent] a", count: 0
    end
  end

  test "signed-out contact stores tag ids and complete tags one conversation" do
    press = press_recording("Press center")
    kit = press_recording("Press kit")
    received = []
    resolver = lambda { |mount_recording:, actor:, tags:|
      received << tags.dup
      tags.clear
      [@staff]
    }

    with_contact_config(public_contact_recipient_resolver: resolver) do
      request = contact_request
      outcome = RecordingStudioMessages.begin_public_contact(
        mount_recording: @mount,
        name: "Ada Lovelace",
        email: "tagged-contact@example.com",
        body: "Hello from the center",
        current_actor: nil,
        request: request,
        session: request.session,
        tags: { "press_center" => press, press_kit: kit }
      )

      intent = outcome.intent
      assert_nil outcome.group_recording
      assert_equal(
        { "press_center" => press.id.to_s, "press_kit" => kit.id.to_s },
        intent.tags
      )
      assert_equal [], received

      verified = RecordingStudioUser.verify_otp!(
        challenge_id: intent.otp_challenge_id,
        code: otp_code_for(intent),
        purpose: otp_purpose_for(intent),
        session: request.session
      )
      assert verified.success?

      user = User.find_by!(email: "tagged-contact@example.com")
      group = RecordingStudioMessages.complete_public_contact(intent: intent, actor: user)
      rows = RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: group.id)
      assert_equal press.id, rows.find_by!(key: "press_center").tagged_recording_id
      assert_equal kit.id, rows.find_by!(key: "press_kit").tagged_recording_id
      assert_equal({ "press_center" => press, "press_kit" => kit }, received.last)

      again = RecordingStudioMessages.complete_public_contact(intent: intent.reload, actor: user)
      assert_equal group.id, again.id
      assert_equal 2, RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: group.id).count
      assert_equal 1, received.size
    end
  end

  test "a keyrest resolver receives tags and an omitted hash is empty" do
    press = press_recording("Press center")
    received = []
    resolver = lambda { |mount_recording:, actor:, **rest|
      received << rest.fetch(:tags)
      [@staff]
    }

    with_contact_config(public_contact_recipient_resolver: resolver) do
      RecordingStudioMessages.begin_public_contact(
        mount_recording: @mount,
        name: nil,
        email: nil,
        body: "Signed in",
        current_actor: @staff,
        request: contact_request,
        session: {},
        tags: { "press_center" => press }
      )
      RecordingStudioMessages.begin_public_contact(
        mount_recording: @mount,
        name: nil,
        email: nil,
        body: "No tags",
        current_actor: @staff,
        request: contact_request,
        session: {}
      )
    end

    assert_equal [{ "press_center" => press }, {}], received
  end

  test "signed-in contact tags the new conversation through the two-keyword resolver" do
    press = press_recording("Press center")
    outcome = RecordingStudioMessages.begin_public_contact(
      mount_recording: @mount,
      name: nil,
      email: nil,
      body: "From the desk",
      current_actor: @staff,
      request: contact_request,
      session: {},
      tags: { "press_center" => press }
    )

    group = outcome.group_recording
    assert_nil outcome.intent
    row = RecordingStudioMessages::MessageGroupTag.find_by!(
      message_group_recording_id: group.id,
      key: "press_center"
    )
    assert_equal press.id, row.tagged_recording_id
  end

  test "complete raises when a stale trashed tagged recording is gone and does not confirm identity" do
    press = press_recording("Press center")
    session = {}
    outcome = RecordingStudioMessages.begin_public_contact(
      mount_recording: @mount,
      name: "Ada Lovelace",
      email: "stale-trash-target@example.com",
      body: "Hello",
      current_actor: nil,
      request: contact_request,
      session: session,
      tags: { "press_center" => press }
    )
    intent = outcome.intent
    user = User.find_by!(email: "stale-trash-target@example.com")
    RecordingStudio::Recording.unscoped.where(id: press.id).update_all(trashed_at: Time.current)
    assert_nil press.trashed_at

    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      error = assert_raises(RecordingStudioMessages::Error) do
        RecordingStudioMessages.complete_public_contact(intent: intent, actor: user)
      end
      assert_equal "We couldn't send that message. Start a new one.", error.message
    end

    user.reload
    assert_nil user.confirmed_at
    intent.reload
    assert_nil intent.message_group_id
    assert_equal "Hello", intent.body
    assert intent.open?
  end

  test "complete rejects a trashed or destroyed mount before identity confirmation" do
    session = {}
    outcome = RecordingStudioMessages.begin_public_contact(
      mount_recording: @mount,
      name: "Ada Lovelace",
      email: "stale-trash-mount@example.com",
      body: "Hello",
      current_actor: nil,
      request: contact_request,
      session: session
    )
    intent = outcome.intent
    user = User.find_by!(email: "stale-trash-mount@example.com")
    RecordingStudio::Recording.unscoped.where(id: @mount.id).update_all(trashed_at: Time.current)
    assert_nil @mount.trashed_at

    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      error = assert_raises(RecordingStudioMessages::Error) do
        RecordingStudioMessages.complete_public_contact(intent: intent, actor: user)
      end
      assert_equal "We couldn't send that message. Start a new one.", error.message
    end

    user.reload
    assert_nil user.confirmed_at
    intent.reload
    assert intent.open?

    RecordingStudio::Recording.unscoped.where(id: @mount.id).update_all(trashed_at: nil)
    destroy_session = {}
    destroy_outcome = RecordingStudioMessages.begin_public_contact(
      mount_recording: @mount,
      name: "Ada Lovelace",
      email: "stale-destroy-mount@example.com",
      body: "Hello",
      current_actor: nil,
      request: contact_request,
      session: destroy_session
    )
    destroy_intent = destroy_outcome.intent
    destroy_user = User.find_by!(email: "stale-destroy-mount@example.com")
    destroy_intent.update_column(:mount_recording_id, SecureRandom.uuid)

    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      error = assert_raises(RecordingStudioMessages::Error) do
        RecordingStudioMessages.complete_public_contact(intent: destroy_intent, actor: destroy_user)
      end
      assert_equal "We couldn't send that message. Start a new one.", error.message
    end

    destroy_user.reload
    assert_nil destroy_user.confirmed_at
    destroy_intent.reload
    assert destroy_intent.open?
  end

  test "a trashed mount denies the return after Users has already confirmed the code" do
    post contact_path, params: { name: "Ada Lovelace", email: "verify-trash-mount@example.com", body: "Hello." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    user = User.find_by!(email: "verify-trash-mount@example.com")
    code = otp_code_for(intent)
    RecordingStudio::Recording.unscoped.where(id: @mount.id).update_all(trashed_at: Time.current)

    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      post otp_challenge_path, params: { code: code }
      assert_response :redirect
      post recording_studio_messages.public_contact_return_path,
           params: { contact_token: return_token_from(response.location) }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /couldn't send that message/i
    end

    user.reload
    assert user.confirmed?
    intent.reload
    assert intent.open?
    assert_nil intent.message_group_id
  end

  test "a valid tag token tags the conversation for a signed-in sender" do
    mailbox = @mount.parent_recording
    token = contact_tag_token("press_center" => mailbox)

    sign_in @staff
    assert_difference -> { RecordingStudioMessages::MessageGroupTag.count }, 1 do
      post contact_path, params: { body: "From the signed-in desk.", tag_token: token }
    end

    assert_redirected_to recording_studio_messages.public_contact_sent_path
    group = last_group_recording
    row = RecordingStudioMessages::MessageGroupTag.find_by!(
      message_group_recording_id: group.id,
      key: "press_center"
    )
    assert_equal mailbox.id, row.tagged_recording_id
  end

  test "a valid tag token tags the conversation after the email code" do
    mailbox = @mount.parent_recording
    nested = RecordingStudioMessages.create_group(@mount, title: "Nested target", actor: @staff)
    token = contact_tag_token("press_center" => mailbox, "press_kit" => nested)

    post contact_path, params: {
      name: "Ada Lovelace",
      email: "tagged-token@example.com",
      body: "Please file this under the mailbox.",
      tag_token: token
    }
    assert_redirected_to otp_challenge_path
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    assert_equal(
      { "press_center" => mailbox.id.to_s, "press_kit" => nested.id.to_s },
      intent.tags
    )

    deliver_code!(intent)
    assert_redirected_to recording_studio_messages.public_contact_sent_path

    group = intent.reload.group_recording
    rows = RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: group.id)
    assert_equal mailbox.id, rows.find_by!(key: "press_center").tagged_recording_id
    assert_equal nested.id, rows.find_by!(key: "press_kit").tagged_recording_id
  end

  test "a tampered tag token does not create a conversation" do
    token = contact_tag_token("press_center" => @mount.parent_recording)
    tampered = "#{token}x"

    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      post contact_path, params: {
        name: "Ada Lovelace",
        email: "tampered-token@example.com",
        body: "Hello.",
        tag_token: tampered
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /couldn't send that message/i
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
  end

  test "an expired tag token does not create a conversation" do
    token = contact_tag_token("press_center" => @mount.parent_recording)

    travel RecordingStudioMessages::PublicContact::TagToken::LIFETIME + 1.second do
      assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
        post contact_path, params: {
          name: "Ada Lovelace",
          email: "expired-token@example.com",
          body: "Hello.",
          tag_token: token
        }
      end
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /couldn't send that message/i
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
  end

  test "a tag token for a recording outside the mount parent tree is rejected" do
    outsider = press_recording("Other workspace")
    token = outsider_tag_token(@mount, "press_center" => outsider)

    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      post contact_path, params: {
        name: "Ada Lovelace",
        email: "outside-tree@example.com",
        body: "Hello.",
        tag_token: token
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /couldn't send that message/i
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
  end

  test "a tag token for a trashed recording is rejected" do
    nested = RecordingStudioMessages.create_group(@mount, title: "Soon gone", actor: @staff)
    token = contact_tag_token("press_center" => nested)
    nested.update!(trashed_at: Time.current)

    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      post contact_path, params: {
        name: "Ada Lovelace",
        email: "trashed-target@example.com",
        body: "Hello.",
        tag_token: token
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /couldn't send that message/i
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
  end

  test "modal contact without tags still has no tag token" do
    get contact_path(presentation: "modal"), headers: modal_headers

    assert_response :success
    assert_select "input[name=tag_token]", count: 0

    post contact_path, params: modal_message(email: "no-tags-token@example.com"), headers: modal_headers
    assert_redirected_to contact_path(presentation: "modal")
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    assert_equal({}, intent.tags)
  end

  test "modal src and restart keep a valid tag token" do
    mailbox = @mount.parent_recording
    token = contact_tag_token("press_center" => mailbox)

    get contact_path(presentation: "modal", tag_token: token), headers: modal_headers
    assert_response :success
    assert_select "input[name=tag_token][value=?]", token

    post contact_path,
         params: modal_message(email: "restart-token@example.com").merge(tag_token: token),
         headers: modal_headers
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    intent.update!(expires_at: 1.hour.ago)
    get contact_path(presentation: "modal", tag_token: token),
        headers: modal_headers

    assert_select "a[href=?]",
                  contact_path(presentation: "modal", tag_token: token),
                  text: "Send it again"
  end

  test "complete raises when a tagged recording is gone and leaves the intent open" do
    press = press_recording("Press center")
    outcome = RecordingStudioMessages.begin_public_contact(
      mount_recording: @mount,
      name: "Ada Lovelace",
      email: "missing-target@example.com",
      body: "Hello",
      current_actor: nil,
      request: contact_request,
      session: {},
      tags: { "press_center" => press }
    )
    intent = outcome.intent
    press.destroy
    user = User.find_by!(email: "missing-target@example.com")

    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      error = assert_raises(RecordingStudioMessages::Error) do
        RecordingStudioMessages.complete_public_contact(intent: intent, actor: user)
      end
      assert_equal "We couldn't send that message. Start a new one.", error.message
    end

    intent.reload
    assert_nil intent.message_group_id
    assert_equal "Hello", intent.body
    assert intent.open?
  end

  test "otp registration off denies a new address without creating a user" do
    RecordingStudioUser.config.otp_registration_enabled = false

    assert_no_difference -> { User.count } do
      post contact_path, params: { name: "Ada Lovelace", email: "new-off@example.com", body: "Hello." }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Public contact needs Recording Studio Users email codes."
    assert_equal 0, RecordingStudioMessages::PublicContactIntent.count
    assert_equal 0, RecordingStudioMessages::Message.count
  ensure
    RecordingStudioUser.config.otp_registration_enabled = true
  end

  test "modal verify fulfils with the rotated csrf token and a second post stays one conversation" do
    with_forgery_protection do
      get contact_path
      param, old_token = csrf_meta
      email = "rotate@example.com"

      post contact_path,
           params: modal_message(email: email).merge(param => old_token),
           headers: modal_headers
      assert_redirected_to contact_path(presentation: "modal")
      get response.location, headers: modal_headers
      assert_response :success

      intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
      post otp_challenge_path,
           params: { code: otp_code_for(intent), param => old_token },
           headers: inline_otp_headers
      assert_response :success
      fresh = signed_in_csrf(response.body)
      token = return_token_from(response.body)
      refute_equal old_token, fresh.fetch("csrf_token")

      post recording_studio_messages.public_contact_return_path,
           params: { contact_token: token, presentation: "modal", param => old_token },
           headers: modal_headers
      assert_response :unprocessable_entity
      assert_equal 0, RecordingStudioMessages::Message.count
      assert intent.reload.open?

      post recording_studio_messages.public_contact_return_path,
           params: { contact_token: token, presentation: "modal", fresh.fetch("csrf_param") => fresh.fetch("csrf_token") },
           headers: modal_headers
      assert_redirected_to recording_studio_messages.public_contact_sent_path(presentation: "modal")
      group_id = intent.reload.message_group_id

      post recording_studio_messages.public_contact_return_path,
           params: { contact_token: token, presentation: "modal", fresh.fetch("csrf_param") => fresh.fetch("csrf_token") },
           headers: modal_headers
      assert_redirected_to recording_studio_messages.public_contact_sent_path(presentation: "modal")
      assert_equal group_id, intent.reload.message_group_id
      assert_equal 1, RecordingStudioMessages::Message.where(body: "Please send the quieter crop.").count
      assert User.find_by!(email: email).confirmed?
    end
  end

  test "an unticked terms box does not finish a new address or send the message" do
    publish_signup_terms!
    email = "terms-off@example.com"
    post contact_path, params: modal_message(email: email), headers: modal_headers
    assert_redirected_to contact_path(presentation: "modal")
    get response.location, headers: modal_headers

    assert_select "input[type=checkbox][name=accept_terms][value=1]"
    assert_select "h2", text: "Verify it's you"
    user = User.find_by!(email: email)
    refute user.confirmed?
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last

    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      post otp_challenge_path,
           params: { code: otp_code_for(intent) },
           headers: inline_otp_headers
    end

    assert_response :unprocessable_entity
    refute user.reload.confirmed?
    assert_nil session["warden.user.user.key"]
    assert_equal 0, RecordingStudioMessages::Message.count
    assert intent.reload.open?
    assert_equal 1, User.where(email: email).count
  end

  test "a ticked terms box records acceptance, sends once, and a second post stays one conversation" do
    publish_signup_terms!
    email = "terms-on@example.com"
    post contact_path, params: modal_message(email: email), headers: modal_headers
    get response.location, headers: modal_headers
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    user = User.find_by!(email: email)
    code = otp_code_for(intent)

    post otp_challenge_path, params: { code: code }, headers: inline_otp_headers
    assert_response :unprocessable_entity
    refute user.reload.confirmed?

    post otp_challenge_path,
         params: { code: code, accept_terms: "1" },
         headers: inline_otp_headers
    assert_response :success
    assert user.reload.confirmed?
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal user.id, receipt.actor_id
    assert_equal({ "source" => "checkbox" }, receipt.provenance)
    token = return_token_from(response.body)

    post recording_studio_messages.public_contact_return_path,
         params: { contact_token: token, presentation: "modal" },
         headers: modal_headers
    assert_redirected_to recording_studio_messages.public_contact_sent_path(presentation: "modal")
    group_id = intent.reload.message_group_id

    post recording_studio_messages.public_contact_return_path,
         params: { contact_token: token, presentation: "modal" },
         headers: modal_headers
    assert_redirected_to recording_studio_messages.public_contact_sent_path(presentation: "modal")
    assert_equal group_id, intent.reload.message_group_id
    assert_equal 1, RecordingStudioMessages::Message.where(body: "Please send the quieter crop.").count
  end

  test "an existing account has no terms box and can send without ticking" do
    publish_signup_terms!
    existing = User.create!(
      email: "casey.terms@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Casey Patron",
      confirmed_at: Time.current
    )
    post contact_path, params: modal_message(email: existing.email), headers: modal_headers
    get response.location, headers: modal_headers

    assert_select "input[name=accept_terms]", count: 0
    assert_select "h2", text: "Verify it's you"
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    assert_equal "login", otp_purpose_for(intent)
    accept_live_terms!(existing)

    deliver_modal_code!(intent)
    assert_redirected_to recording_studio_messages.public_contact_sent_path(presentation: "modal")
    assert_equal 1, RecordingStudioMessages::Message.count
    receipts = RecordingStudioTermsAndConditions::Acceptance.where(actor_id: existing.id)
    assert_equal [ "continue_notice" ], receipts.map { |receipt| receipt.provenance["source"] }
  end

  test "a url-safe return token fulfills once and a second post returns the same conversation" do
    post contact_path, params: { name: "Ada Lovelace", email: "replay@example.com", body: "Once." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    post otp_challenge_path, params: { code: otp_code_for(intent) }
    token = return_token_from(response.location)
    assert_match(/\A[A-Za-z0-9_-]+\z/, token)
    path = request_path(response.location)
    assert_equal path, RecordingStudioUser::ReturnTo.accept(path)
    assert_includes path, "contact_token=#{token}"
    follow_redirect!
    assert_equal 0, RecordingStudioMessages::Message.count

    post recording_studio_messages.public_contact_return_path, params: { contact_token: token }
    assert_redirected_to recording_studio_messages.public_contact_sent_path
    group_id = intent.reload.message_group_id

    post recording_studio_messages.public_contact_return_path, params: { contact_token: token }
    assert_redirected_to recording_studio_messages.public_contact_sent_path
    assert_equal group_id, intent.reload.message_group_id
    assert_equal 1, RecordingStudioMessages::Message.count
  end

  test "an expired or tampered return token is denied" do
    post contact_path, params: { name: "Ada Lovelace", email: "stale-token@example.com", body: "Hello." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    post otp_challenge_path, params: { code: otp_code_for(intent) }
    token = return_token_from(response.location)

    travel 16.minutes do
      post recording_studio_messages.public_contact_return_path, params: { contact_token: token }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: "That link expired. Start again."
    end

    post recording_studio_messages.public_contact_return_path, params: { contact_token: "#{token}x" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "That link expired. Start again."
    assert_equal 0, RecordingStudioMessages::Message.count
  end

  test "a signed-out or different person cannot finish the return" do
    post contact_path, params: { name: "Ada Lovelace", email: "wrong-person@example.com", body: "Hello." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    post otp_challenge_path, params: { code: otp_code_for(intent) }
    token = return_token_from(response.location)

    sign_out :user
    post recording_studio_messages.public_contact_return_path, params: { contact_token: token }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "You cannot send this message."

    sign_in @staff
    post recording_studio_messages.public_contact_return_path, params: { contact_token: token }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "You cannot send this message."
    assert_equal 0, RecordingStudioMessages::Message.count
    assert intent.reload.open?
  end

  private

  def press_recording(name)
    workspace = Workspace.create!(name: "#{name} #{SecureRandom.hex(4)}")
    RecordingStudio.root_recording_for(workspace)
  end

  def verify_contact(email:, purpose: "registration")
    post contact_path, params: { name: "Ada Lovelace", email: email, body: "Hello from #{email}." }
    intent = RecordingStudioMessages::PublicContactIntent.order(:created_at).last
    assert_equal purpose, otp_purpose_for(intent)
    deliver_code!(intent)
    assert_redirected_to recording_studio_messages.public_contact_sent_path
    follow_redirect!
    assert_response :success
    intent
  end

  def deliver_code!(intent, code: nil)
    post otp_challenge_path, params: { code: code || otp_code_for(intent) }
    assert_response :redirect
    token = return_token_from(response.location)
    follow_redirect!
    assert_response :success
    assert_select "form#public-contact-finish"
    assert_equal 0, RecordingStudioMessages::Message.count
    post recording_studio_messages.public_contact_return_path, params: { contact_token: token }
  end

  def deliver_modal_code!(intent, code: nil)
    post otp_challenge_path,
         params: { code: code || otp_code_for(intent) },
         headers: inline_otp_headers
    assert_response :success
    token = return_token_from(response.body)
    post recording_studio_messages.public_contact_return_path,
         params: { contact_token: token, presentation: "modal" },
         headers: modal_headers
  end

  def otp_challenge_path
    Rails.application.routes.url_helpers.recording_studio_user_otp_challenge_path(script_name: "")
  end

  def otp_resend_path
    Rails.application.routes.url_helpers.recording_studio_user_otp_resend_path(script_name: "")
  end

  def inline_otp_headers
    { "Turbo-Frame" => RecordingStudioUser::OtpCodeForm::FRAME_ID }
  end

  def return_token_from(source)
    token = CGI.unescapeHTML(source.to_s)[/contact_token=([^"&\s<]+)/, 1]
    token && CGI.unescape(token)
  end

  def request_path(location)
    uri = URI.parse(location.to_s)
    uri.query.present? ? "#{uri.path}?#{uri.query}" : uri.path
  end

  def csrf_meta
    param = css_select('meta[name="csrf-param"]').first["content"]
    token = css_select('meta[name="csrf-token"]').first["content"]
    [ param, token ]
  end

  def signed_in_csrf(body)
    encoded = body.to_s[/var detail = (\{.*?\});/m, 1]
    assert encoded, "signed-in event missing"
    JSON.parse(encoded)
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def accept_live_terms!(user)
    root = RecordingStudioTermsAndConditions::Gate.first_root_with_live_terms
    RecordingStudioTermsAndConditions.pending_published_list(user, root).each do |terms|
      RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "continue_notice" })
    end
  end

  def publish_signup_terms!
    recording = @root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = "Signup Terms"
      terms.body = "Be kind on the way in."
    end
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "contact-terms-#{SecureRandom.hex(4)}", status: "published" }
    ).value!
  end

  def contact_request
    ActionDispatch::TestRequest.create.tap do |test_request|
      test_request.session = ActionController::TestSession.new
    end
  end

  def last_group_recording
    RecordingStudio::Recording
      .where(recordable_type: "RecordingStudioMessages::MessageGroup")
      .order(:created_at)
      .last
  end

  def message_group_path_for_last_group
    recording_studio_messages.message_group_path(last_group_recording)
  end

  def with_contact_config(**values)
    config = RecordingStudioMessages.configuration
    previous = values.keys.to_h { |key| [ key, config.public_send(key) ] }
    values.each { |key, value| config.public_send("#{key}=", value) }
    yield
  ensure
    previous&.each { |key, value| config.public_send("#{key}=", value) }
  end

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

  def contact_path(**extra)
    recording_studio_messages.public_contact_path({ mount_id: @mount.id }.merge(extra))
  end

  def contact_tag_token(tags)
    RecordingStudioMessages::PublicContact::TagToken.generate(mount: @mount, tags: tags)
  end

  def outsider_tag_token(mount, tags)
    ids = tags.to_h { |key, recording| [ key.to_s, recording.id.to_s ] }
    Rails.application.message_verifier(RecordingStudioMessages::PublicContact::TagToken::PURPOSE).generate(
      { "mount_id" => mount.id.to_s, "tags" => ids },
      purpose: RecordingStudioMessages::PublicContact::TagToken::PURPOSE,
      expires_in: RecordingStudioMessages::PublicContact::TagToken::LIFETIME
    )
  end

  def modal_headers
    { "Turbo-Frame" => RecordingStudioMessages::PublicContactHelper::FRAME_ID }
  end

  def modal_message(email: "Ada@Example.com")
    { presentation: "modal", name: "Ada Lovelace", email: email, body: "Please send the quieter crop." }
  end

  def message_received_scope
    RecordingStudioNotifications::Notification.where(notification_type: "message_received")
  end

  def message_received_count
    message_received_scope.count
  end

  def otp_purpose_for(intent)
    RecordingStudioUser.otp_proof(intent.otp_challenge_id).purpose
  end

  def otp_code_for(intent)
    RecordingStudioUser.otp_message(intent.otp_challenge_id).fetch(:body)[/\d{6}/]
  end

  def otp_notification_count
    RecordingStudioNotifications::Notification.where(notification_type: %w[registration_otp login_otp]).count
  end
end
