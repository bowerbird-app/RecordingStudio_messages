RecordingStudioMessages install complete.

Next steps:

1. Ensure your Gemfile includes `recording_studio`, `recording_studio_accessible >= 0.4.1`, and `flat_pack`.
2. Review `config/initializers/recording_studio_messages.rb`.
3. Install migrations with `bin/rails generate recording_studio_messages:migrations` and run `bin/rails db:migrate`.
4. Generate container recordables, for example `bin/rails generate recording_studio_messages:container SiteMessages --root`.
5. Register recordable types in `RecordingStudio.config.recordable_types`, including generated containers plus `RecordingStudioMessages::MessageGroup` and `RecordingStudioMessages::Message`.
6. Seed or explicitly create container recordings; the engine does not auto-create containers during requests.
7. Configure recipient type allowlists plus `recipient_search` and `recipient_allowed`; without these hooks recipient search fails closed.
8. Use default container `:edit` authorization for hierarchy-owned containers.
9. For shared-root/private-child messages, configure action authorization and define a host-app policy. Do not grant broad root access solely to allow private group creation.
10. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
