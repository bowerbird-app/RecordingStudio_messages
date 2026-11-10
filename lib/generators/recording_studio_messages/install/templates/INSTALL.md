RecordingStudioMessages install complete.

Next steps:

1. Include `RecordingStudio::Capabilities::Messages.to` on each host type that should hold a mount.
2. Register `MessageMount`, `MessageGroup`, `Message`, and `RecordingStudioAttachable::Attachment` in `config/initializers/recording_studio.rb`.
3. Review `config/initializers/recording_studio_messages.rb`.
4. Install migrations with `bin/rails generate recording_studio_messages:migrations` (plus Accessible, Attachable, and Notifications).
5. Apply the migrations with `bin/rails db:migrate`.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Pin `flat_pack/copy` in the host importmap (`to: "flat_pack/copy.js"`) so InlineEdit can load. The dummy pin sits next to `flat_pack/heroicons`. `pin_all_from` on Flatpack controllers already loads `flat-pack--chat-timestamp-reveal`. If the host copied `build_stimulus.js`, register `ChatTimestampRevealController` as `flat-pack--chat-timestamp-reveal`.
8. Mount Accessible and Attachable next to this engine. Adjust auth, layout, and current actor integration to match your host app. Auth stays on Accessible.
9. Keep strict declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
10. Link to `my_messages_path` for the cross-mount inbox of conversations the current actor was added to. Mount desks honor `unread=1` the same way. Override `messages_list_toolbar(mount:, actor:)` when the host needs a control beside the unread toggle.
