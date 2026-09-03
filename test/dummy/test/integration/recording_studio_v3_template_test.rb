# frozen_string_literal: true

require "test_helper"

class RecordingStudioHostTemplateTest < ActiveSupport::TestCase
  test "dummy app loads root switchable config and controller support" do
    assert_equal [ "all_workspaces" ], RecordingStudioRootSwitchable.configuration.scopes.keys
    assert_equal :application_layout, RecordingStudioRootSwitchable.configuration.layout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end

  test "dummy app validates recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal [ "Workspace", "RecordingStudioUser::People" ].sort, RecordingStudio.root_recordable_types.sort
    assert_equal [ "Workspace", "Folder" ], RecordingStudio.allowed_parent_types_for("Page")
  end

  test "dummy app schema includes accessible grants and excludes removed core tables" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "dummy seeds use hierarchy idempotently and restore current actor" do
    Current.actor = nil

    load Rails.root.join("db/seeds.rb").to_s

    workspace = Workspace.find_by!(name: "Studio Workspace")
    accessible_workspace = Workspace.find_by!(name: "Client Workspace")
    private_workspace = Workspace.find_by!(name: "Private Workspace")
    folder = Folder.find_by!(name: "Product Docs")
    page = Page.find_by!(title: "Getting Started")
    mailbox = Mailbox.find_by!(name: "Site mailbox")
    root_recording = RecordingStudio::Recording.find_by!(recordable: workspace)
    accessible_root_recording = RecordingStudio::Recording.find_by!(recordable: accessible_workspace)
    private_root_recording = RecordingStudio::Recording.find_by!(recordable: private_workspace)
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder)
    page_recording = RecordingStudio::Recording.find_by!(recordable: page)
    mailbox_recording = RecordingStudio::Recording.find_by!(recordable: mailbox)
    support_mount = root_recording.message_mount("support")
    inbox_mount = mailbox_recording.message_mount("inbox")

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil accessible_root_recording.parent_recording_id
    assert_nil private_root_recording.parent_recording_id
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    assert_equal root_recording, mailbox_recording.parent_recording
    assert_equal root_recording, support_mount.parent_recording
    assert_equal mailbox_recording, inbox_mount.parent_recording
    assert_equal "support", support_mount.recordable.key
    assert_equal "inbox", inbox_mount.recordable.key
    assert_equal DummyCatalog.support_group_recording.parent_recording, support_mount
    assert_equal DummyCatalog.launch_group_recording.parent_recording, support_mount
    assert_equal DummyCatalog.inbox_group_recording.parent_recording, inbox_mount
    assert RecordingStudioAccessible.authorized?(
      actor: User.find_by!(email: "admin@admin.com"),
      recording: DummyCatalog.launch_group_recording,
      role: :view
    )
    assert DummyCatalog.inbox_group_recording.recordable
    assert RecordingStudioMessages.message_recordings(DummyCatalog.support_group_recording).any?
    assert RecordingStudioMessages.message_recordings(DummyCatalog.inbox_group_recording).any?(&:has_attachments?)
    seeded_workspace_names = ["Studio Workspace", "Client Workspace", "Private Workspace"]
    assert_equal 3, Workspace.where(name: seeded_workspace_names).count
    assert_equal 2, User.where(email: %w[admin@admin.com casey@example.com]).count

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudio::Recording.count } do
        load Rails.root.join("db/seeds.rb").to_s
      end
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end
end
