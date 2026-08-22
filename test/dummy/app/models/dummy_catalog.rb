# frozen_string_literal: true

module DummyCatalog
  SUPPORT_KEY = "support"
  INBOX_KEY = "inbox"
  SUPPORT_TITLE = "Studio help"
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

    def group_recording(title)
      group = RecordingStudioMessages::MessageGroup.find_by!(title: title)
      RecordingStudio::Recording.find_by!(recordable: group)
    end

    def support_group_recording
      group_recording(SUPPORT_TITLE)
    end

    def inbox_group_recording
      group_recording(INBOX_TITLE)
    end

    def empty_group_recording
      group_recording(EMPTY_TITLE)
    end
  end
end
