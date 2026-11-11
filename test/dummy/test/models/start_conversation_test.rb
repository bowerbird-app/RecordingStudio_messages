# frozen_string_literal: true

require "test_helper"

class StartConversationTest < ActiveSupport::TestCase
  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Owner"
    )
    @editor = User.create!(
      email: "editor-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Editor"
    )
    @viewer = User.create!(
      email: "viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Viewer"
    )
    Current.actor = @owner

    @workspace = Workspace.create!(name: "Start #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    raise result.error if result.failure?

    mailbox = Mailbox.create!(name: "Start mailbox #{SecureRandom.hex(4)}")
    mailbox_recording = RecordingStudio.record!(
      action: "created",
      recordable: mailbox,
      root_recording: @root,
      parent_recording: @root,
      actor: @owner
    ).recording
    @inherited_mount = mailbox_recording.ensure_message_mount("inbox", actor: @owner)
    @members_mount = @root.ensure_message_mount("support", actor: @owner)

    grant_root!(@editor, :edit)
    grant_root!(@viewer, :view)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "members create_group with recipients grants admin to the creator and edit to each recipient" do
    group = RecordingStudioMessages.create_group(
      @members_mount,
      actor: @owner,
      recipients: [@editor],
      body: "Can you look at this?"
    )

    assert_equal "Owner, Editor", group.recordable.title
    assert_equal :admin, direct_role(group, @owner)
    assert_equal :edit, direct_role(group, @editor)
    refute_includes granted_ids(group), @viewer.id
    assert_includes listed_titles(actor: @owner), "Owner, Editor"
    assert_includes listed_titles(actor: @editor), "Owner, Editor"
    assert_equal "Can you look at this?", RecordingStudioMessages.message_recordings(group).last.recordable.body
  end

  test "untitled create_group names the conversation creator first then recipients in pick order" do
    group = RecordingStudioMessages.create_group(
      @members_mount,
      actor: @owner,
      recipients: [@viewer, @editor],
      body: "Three of us."
    )

    assert_equal "Owner, Viewer, Editor", group.recordable.title
  end

  test "inherited create_group with recipients grants edit to the creator and each recipient" do
    group = RecordingStudioMessages.create_group(
      @inherited_mount,
      title: "Quiet ask",
      actor: @owner,
      recipients: [@editor],
      body: "Need a second pair of eyes."
    )

    assert_equal :edit, direct_role(group, @owner)
    assert_equal :edit, direct_role(group, @editor)
    refute_equal :admin, direct_role(group, @owner)
    assert RecordingStudioAccessible.authorized?(actor: @owner, recording: group, role: :admin)
    assert_includes listed_titles(actor: @owner), "Quiet ask"
    assert_includes listed_titles(actor: @editor), "Quiet ask"
    refute_includes listed_titles(actor: @viewer), "Quiet ask"
  end

  test "dummy contacts resolver filters by name or email without caring about case" do
    matches = DummyCatalog.contacts_for(actor: @owner, mount: @members_mount, query: "editor")

    assert_includes matches.map(&:id), @editor.id
    refute_includes matches.map(&:id), @owner.id
    refute_includes matches.map(&:id), @viewer.id

    by_email = DummyCatalog.contacts_for(
      actor: @owner,
      mount: @members_mount,
      query: @editor.email.split("@").first.upcase
    )
    assert_includes by_email.map(&:id), @editor.id
  end

  test "create_group with recipients rejects a person outside the resolver" do
    error = assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages.create_group(
        @members_mount,
        actor: @owner,
        recipients: [ { type: "User", id: "missing-#{SecureRandom.hex(4)}" } ],
        body: "Hello?"
      )
    end

    assert_equal RecordingStudioMessages::Copy.t("errors.unknown_recipient"), error.message
    assert_equal 0, groups_under(@members_mount)
  end

  test "create_group with recipients rejects an actor without edit on the mount" do
    error = assert_raises(RecordingStudioMessages::NotAuthorized) do
      RecordingStudioMessages.create_group(
        @members_mount,
        actor: @viewer,
        recipients: [@editor],
        body: "Please?"
      )
    end

    assert_equal RecordingStudioMessages::Copy.t("errors.cannot_start"), error.message
    assert_equal 0, groups_under(@members_mount)
  end

  test "create_group with recipients rejects a blank first message" do
    error = assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages.create_group(
        @members_mount,
        actor: @owner,
        recipients: [@editor],
        body: "   "
      )
    end

    assert_equal RecordingStudioMessages::Copy.t("errors.write_message"), error.message
    assert_equal 0, groups_under(@members_mount)
  end

  test "create_group without recipients still writes no inherited grants" do
    group = RecordingStudioMessages.create_group(
      @inherited_mount,
      title: "Quiet thread",
      actor: @owner
    )

    assert_equal [], RecordingStudioMessages.granted_actors(group)
    refute_includes listed_titles(actor: @owner), "Quiet thread"
  end

  private

  def grant_root!(actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: @root,
      actor: actor,
      role: role,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end

  def granted_ids(group)
    RecordingStudioMessages.granted_actors(group).map(&:id)
  end

  def direct_role(group, actor)
    access_recording = RecordingStudioAccessible.access_recordings_for_actor(
      recording: group,
      actor: actor
    ).first
    access_recording&.recordable&.role&.to_sym
  end

  def listed_titles(actor:)
    RecordingStudioMessages.my_group_recordings(actor: actor).map { |recording| recording.recordable.title }
  end

  def groups_under(mount)
    RecordingStudio::Recording.where(
      parent_recording_id: mount.id,
      recordable_type: "RecordingStudioMessages::MessageGroup"
    ).count
  end
end
