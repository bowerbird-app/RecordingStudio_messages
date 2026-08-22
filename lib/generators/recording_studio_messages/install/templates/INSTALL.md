RecordingStudioMessages install complete.

Next steps:

1. Include `RecordingStudio::Capabilities::Messages.to` on each host type that should hold a mount.
2. Register `MessageMount`, `MessageGroup`, `Message`, and `RecordingStudioAttachable::Attachment` in `config/initializers/recording_studio.rb`.
3. Review `config/initializers/recording_studio_messages.rb`.
4. Install migrations with `bin/rails generate recording_studio_messages:migrations` (plus Accessible, Attachable, and Notifications).
5. Apply the migrations with `bin/rails db:migrate`.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Mount Accessible and Attachable next to this engine. Adjust auth, layout, and current actor integration to match your host app. Auth stays on Accessible.
8. Keep strict declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
