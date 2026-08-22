# frozen_string_literal: true

module DummyCatalog
  SUPPORT_KEY = "support"
  INBOX_KEY = "inbox"
  SUPPORT_TITLE = "Studio help"
  LAUNCH_TITLE = "Launch notes"
  INBOX_TITLE = "Site inbox"
  EMPTY_TITLE = "Open conversation"

  class << self
    def studio_workspace
      Workspace.find_by!(name: "Studio Workspace")
    end

    def mailbox
      Mailbox.find_by!(name: "Site mailbox")
    end

    def support_mount_recording
      RecordingStudio.root_recording_for(studio_workspace).message_mount(SUPPORT_KEY)
    end

    def inbox_mount_recording
      mailbox_recording = RecordingStudio::Recording.find_by!(recordable: mailbox)
      mailbox_recording.message_mount(INBOX_KEY)
    end

    def group_recordings_under(mount)
      RecordingStudio::Recording.unscoped.where(
        parent_recording_id: mount.id,
        recordable_type: "RecordingStudioMessages::MessageGroup",
        trashed_at: nil
      ).includes(:recordable)
    end

    def find_group_recording_under(mount, title)
      group_recordings_under(mount).detect { |recording| recording.recordable&.title == title }
    end

    def group_recording_under(mount, title)
      find_group_recording_under(mount, title) ||
        raise(ActiveRecord::RecordNotFound, "No #{title.inspect} conversation under this desk")
    end

    def support_group_recording
      group_recording_under(support_mount_recording, SUPPORT_TITLE)
    end

    def launch_group_recording
      group_recording_under(support_mount_recording, LAUNCH_TITLE)
    end

    def inbox_group_recording
      group_recording_under(inbox_mount_recording, INBOX_TITLE)
    end

    def empty_group_recording
      group_recording_under(support_mount_recording, EMPTY_TITLE)
    end
  end
end
