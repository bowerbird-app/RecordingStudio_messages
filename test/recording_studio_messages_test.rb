# frozen_string_literal: true

require "test_helper"

class RecordingStudioMessagesTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.3.0", ::RecordingStudioMessages::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioMessages::Engine
  end

  def test_gemspec_pins_recording_studio_family
    gemspec = File.read(File.expand_path("../recording_studio_messages.gemspec", __dir__))

    assert_equal "~> 4.2", gemspec_constraint(gemspec, "recording_studio")
    assert_equal "~> 0.9.1", gemspec_constraint(gemspec, "recording_studio_accessible")
    assert_equal "~> 0.5.1", gemspec_constraint(gemspec, "recording_studio_attachable")
    assert_equal "~> 0.3.1", gemspec_constraint(gemspec, "recording_studio_notifications")
    assert_equal "~> 0.1.148", gemspec_constraint(gemspec, "flat_pack")
    assert_equal "~> 8.1.0", gemspec_constraint(gemspec, "rails")
    refute_includes gemspec, 'spec.add_dependency "recording_studio_publishable"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_user"'
    refute_includes gemspec, ".cursor"
  end

  def test_root_gemfile_resolves_the_same_family_tags
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.3.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.8.2"'
    refute_includes gemfile, "1adc7722ec58fcfeb43ff1e2e96849936a6e9411"
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.148"'
    assert_equal "~> 0.9.1", gemfile_constraint(gemfile, "recording_studio_accessible")
    assert_equal "~> 0.3.1", gemfile_constraint(gemfile, "recording_studio_notifications")
    assert_equal "~> 0.1.148", gemfile_constraint(gemfile, "flat_pack")
  end

  def test_dummy_gemfile_pins_verified_family_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.3.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.8.2"'
    refute_includes gemfile, "1adc7722ec58fcfeb43ff1e2e96849936a6e9411"
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.148"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v0.1.134"'
    refute_includes gemfile, 'tag: "0.3.1"'
    refute_includes gemfile, 'tag: "v0.1.84"'
  end

  def test_does_not_ship_copied_core_hooks_or_template_leftovers
    refute File.exist?(File.expand_path("../lib/recording_studio_messages/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_messages/services/base_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_messages/services/example_service.rb", __dir__))
    refute File.exist?(File.expand_path("../app/controllers/recording_studio_messages/home_controller.rb", __dir__))
    controller_path = File.expand_path(
      "../app/controllers/recording_studio_messages/message_groups_controller.rb",
      __dir__
    )
    assert File.exist?(controller_path)
    assert File.exist?(File.expand_path("../app/models/recording_studio_messages/message_mount.rb", __dir__))
    refute File.exist?(File.expand_path("../app/models/recording_studio_messages/participant.rb", __dir__))
    refute File.exist?(File.expand_path("../app/models/recording_studio_messages/pundit.rb", __dir__))
  end

  def test_message_groups_index_lists_inbox_rows_without_a_custom_acl
    routes = File.read(File.expand_path("../config/routes.rb", __dir__))
    controller = File.read(
      File.expand_path("../app/controllers/recording_studio_messages/message_groups_controller.rb", __dir__)
    )
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_messages/inbox_helper.rb", __dir__)
    )
    panel_helper = File.read(
      File.expand_path("../app/helpers/recording_studio_messages/panel_helper.rb", __dir__)
    )
    desk = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_desk.html.erb", __dir__)
    )
    panel = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_panel.html.erb", __dir__)
    )
    show = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/show.html.erb", __dir__)
    )
    panel_frame = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_panel_frame.html.erb", __dir__)
    )
    list_groups = File.read(
      File.expand_path("../lib/recording_studio_messages/services/list_groups.rb", __dir__)
    )
    api = File.read(File.expand_path("../lib/recording_studio_messages.rb", __dir__))

    assert_includes routes, "%i[index show]"
    assert_includes controller, "def index"
    assert_includes controller, "viewable_group_recordings"
    assert_includes api, "def viewable_group_recordings"
    assert_includes list_groups, "RecordingStudioAccessible.authorized?"
    assert_includes list_groups, "role: :view"
    assert_includes helper, "def messages_inbox_rows"
    assert_includes helper, "messages_inbox_row_complete?"
    assert_includes helper, "turbo_frame: messages_desk_panel_id"
    assert_includes helper, "def messages_inbox_row_link"
    assert_includes panel_helper, "def messages_desk_panel_id"
    assert_includes panel_helper, '"messages-desk-panel"'
    assert_includes controller, "turbo_frame_request?"
    assert_includes show, "turbo_frame_request?"
    assert_includes show, "panel_frame"
    assert_includes desk, "FlatPack::Chat::Layout::Component.new("
    assert_includes desk, "variant: :split"
    assert_includes desk, "layout.sidebar"
    assert_includes desk, "layout.panel"
    assert_includes desk, "messages_inbox_rows"
    assert_includes desk, "panel_frame"
    assert_includes panel_frame, "messages_desk_panel_id"
    refute_includes panel, "back_href"
    assert_includes desk, "FlatPack::List::Component.new(spacing: :dense, selectable: true)"
    assert_includes desk, "FlatPack::Chat::InboxRow::Component"
    assert_includes desk, '<div class="w-full min-w-0 <%= desk_height_class %>">'
    assert_includes desk, "h-[calc(100dvh-8.5rem)]"
    assert_includes desk, "local_assigns[:desk_height_class]"
    refute_includes desk, "min-h-[70vh]"
    refute_match(/class="[^"]*md:grid-cols-\[280px/, desk)
    refute_includes desk, "display: none"
    refute_includes desk, "<style>"
    refute_includes desk, "FlatPack::PageTitle::Component"
    refute_includes desk, ">Conversations<"
    refute_includes helper, '"Conversation"'
    refute_includes controller, "Pundit"
    refute_includes controller, "CanCan"
    refute_includes controller, "user.admin?"
    refute_includes list_groups, "Pundit"
    refute_includes list_groups, "CanCan"
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "return \"application\" if devise_controller?"
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))

    default_layout_head = File.read(
      File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    )
    assert_includes default_layout_head, 'document.documentElement.setAttribute("data-theme", "rounded")'
    refute_includes default_layout_head, "recording_studio_root_switch_dropdown"
    refute_includes default_layout_head, "Sign out"
    assert File.exist?(File.expand_path("dummy/app/controllers/concerns/html_rounded_theme.rb", __dir__))
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "FlatPack::Alert::Component"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_mounts_users_gem_auth_without_a_copied_login_view
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    initializer = File.read(File.expand_path("dummy/config/initializers/recording_studio_user.rb", __dir__))

    assert_includes routes, "skip: %i[sessions registrations passwords]"
    assert_includes routes, "recording_studio_user_auth_for :users"
    assert_includes routes, "mount RecordingStudioUser::Engine"
    assert_includes initializer, 'config.user_class_name = "User"'
    assert_includes initializer, "config.otp_enabled = false"
    refute File.exist?(File.expand_path("dummy/app/views/devise/sessions/new.html.erb", __dir__))
  end

  def test_dummy_pins_turbo_and_loads_flatpack_js
    application_js = File.read(File.expand_path("dummy/app/javascript/application.js", __dir__))
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))

    assert_includes application_js, 'import "@hotwired/turbo-rails"'
    assert_includes importmap, 'pin "@hotwired/turbo-rails", to: "turbo.min.js"'
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "vendor/bundle/**/bundler/gems/flatpack-*/app/components/**/*.rb"
    assert_includes tailwind_source, "vendor/bundle/**/bundler/gems/RecordingStudio*/app/views/**/*.erb"
    assert_includes tailwind_source, "../../../../../vendor/bundle/**/bundler/gems/RecordingStudio*/app/views/**/*.erb"
    assert_includes tailwind_source, '@source inline("pt-16")'
    assert_includes tailwind_source, '@source inline("min-h-dvh")'
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, '"Workspace"'
    assert_includes initializer_source, '"Folder"'
    assert_includes initializer_source, '"Page"'
    assert_includes initializer_source, '"RecordingStudioAttachable::Attachment"'
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    assert_includes initializer_source, "RecordingStudioMessages::MessageMount"
    assert_includes initializer_source, "RecordingStudioMessages::MessageGroup"
    assert_includes initializer_source, "RecordingStudioMessages::Message"
    assert_includes initializer_source, '"Mailbox"'
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "This Rails app exists to prove Recording Studio Messages"
    assert_includes readme_source, "/staff/desk"
    assert_includes readme_source, "/inbox"
    assert_includes readme_source, "https://flatpack.bowerbird.io/"
  end

  def test_readme_points_at_live_flatpack_kit
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "https://flatpack.bowerbird.io/"
    assert_includes readme, "ensure_message_mount"
    assert_includes readme, "notify_each"
    assert_includes readme, "two mounts"
    assert_includes readme, "Do not add a Notifications → Messages dependency"
    assert_includes readme, "docs/cursor-skills.md"
    refute_includes readme, "flatpack-c6p8f.ondigitalocean.app"
    refute_includes readme, "v3.0.0"
    refute_includes readme, "0.1.84"
  end

  def test_send_replaces_the_thread_over_turbo_without_action_cable
    controller = File.read(
      File.expand_path("../app/controllers/recording_studio_messages/messages_controller.rb", __dir__)
    )
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_messages/panel_helper.rb", __dir__)
    )
    stream = File.read(
      File.expand_path("../app/views/recording_studio_messages/messages/create.turbo_stream.erb", __dir__)
    )

    assert_includes controller, "format.turbo_stream"
    assert_includes helper, "messages_panel_list_id"
    assert_includes stream, "turbo_stream.replace messages_panel_list_id"
    assert_includes stream, "turbo_stream.replace messages_panel_composer_id"
    refute_includes controller, "ActionCable"
    refute File.exist?(File.expand_path("../app/channels", __dir__))
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_messages/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end

  private

  def gemspec_constraint(gemspec, name)
    match = gemspec.match(/spec\.add_dependency "#{Regexp.escape(name)}", "([^"]+)"/)
    match && match[1]
  end

  def gemfile_constraint(gemfile, name)
    match = gemfile.match(/gem "#{Regexp.escape(name)}", "([^"]+)"/)
    match && match[1]
  end
end
