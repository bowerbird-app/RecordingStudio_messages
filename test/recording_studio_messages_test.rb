# frozen_string_literal: true

require "test_helper"

class RecordingStudioMessagesTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.24.0", ::RecordingStudioMessages::VERSION
  end

  def test_facade_creates_and_lists_groups_by_tag_without_an_actor
    api = File.read(File.expand_path("../lib/recording_studio_messages.rb", __dir__))
    flow = File.read(
      File.expand_path("../app/controllers/recording_studio_messages/public_contact_flow.rb", __dir__)
    )
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_messages/public_contact_helper.rb", __dir__)
    )

    assert_includes api, "recipients: nil, body: nil"
    assert_includes api, "def create_group(mount_recording, actor:, title: nil"
    assert_includes api, "def rename_group(group_recording:, title:, actor:)"
    assert_includes api, "def tagged_group_recordings(mount_recording:, tags:)"
    assert_includes api, "def register_composer_action"
    assert_includes api, "def register_message_embed"
    assert_includes api, "def preview_text(body, references: [])"
    assert_includes api, "def send_message(...)"
    assert_includes flow, "tags: contact_tags"
    assert_includes helper, "tags: nil"
    assert_includes helper, "tag_token:"
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioMessages::Engine
  end

  def test_gemspec_pins_recording_studio_family
    gemspec = File.read(File.expand_path("../recording_studio_messages.gemspec", __dir__))

    assert_equal ">= 6.1.0", gemspec_constraint(gemspec, "recording_studio")
    assert_equal "~> 0.24", gemspec_constraint(gemspec, "recording_studio_accessible")
    assert_equal "~> 0.13", gemspec_constraint(gemspec, "recording_studio_attachable")
    assert_includes gemspec, 'spec.add_dependency "recording_studio_metrics", ">= 0.3.0", "< 1.0"'
    metrics_requirement = Gem::Requirement.new(">= 0.3.0", "< 1.0")
    assert metrics_requirement.satisfied_by?(Gem::Version.new("0.3.0"))
    assert metrics_requirement.satisfied_by?(Gem::Version.new("0.5.0"))
    refute metrics_requirement.satisfied_by?(Gem::Version.new("0.2.9"))
    refute metrics_requirement.satisfied_by?(Gem::Version.new("1.0.0"))
    assert_includes gemspec, 'spec.add_dependency "recording_studio_notifications", ">= 0.3.1", "< 1"'
    requirement = Gem::Requirement.new(">= 0.3.1", "< 1")
    assert requirement.satisfied_by?(Gem::Version.new("0.3.1"))
    assert requirement.satisfied_by?(Gem::Version.new("0.4.0"))
    assert requirement.satisfied_by?(Gem::Version.new("0.5.0"))
    refute requirement.satisfied_by?(Gem::Version.new("0.3.0"))
    refute requirement.satisfied_by?(Gem::Version.new("1.0.0"))
    assert_equal ">= 0.1.349", gemspec_constraint(gemspec, "flat_pack")
    assert_equal "~> 8.1.0", gemspec_constraint(gemspec, "rails")
    refute_includes gemspec, 'spec.add_dependency "recording_studio_publishable"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_user"'
    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, 'spec.add_dependency "recording_studio_internationalization"'
    refute_includes gemspec, ".cursor"
  end

  def test_root_gemfile_resolves_the_same_family_tags
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.21.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.13.1"'
    assert_includes gemfile, 'gem "recording_studio_notifications", ">= 0.3.1", "< 1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.28.0"'
    assert_includes gemfile, 'gem "recording_studio_user", "~> 0.28.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.1"'
    assert_equal "~> 0.5", gemfile_constraint(gemfile, "recording_studio_cache")
    refute_includes gemfile, "1adc7722ec58fcfeb43ff1e2e96849936a6e9411"
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.349"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.6.2"'
    assert_equal "~> 2.1", gemfile_constraint(gemfile, "recording_studio_admin")
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.11.3"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.6.1"'
    assert_includes gemfile, 'gem "recording_studio_metrics", ">= 0.3.0", "< 1.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.0"'
    assert_equal ">= 6.1.0", gemfile_constraint(gemfile, "recording_studio")
    assert_equal ">= 0.1.349", gemfile_constraint(gemfile, "flat_pack")
    assert_equal "~> 0.24", gemfile_constraint(gemfile, "recording_studio_accessible")
    refute_includes gemfile, 'tag: "v0.3.4"'
    refute_includes gemfile, 'tag: "v4.7.0"'
    refute_includes gemfile, 'tag: "v0.1.245"'
  end

  def test_dummy_gemfile_pins_verified_family_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.21.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.13.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.10.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.28.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.11.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_site_settings", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_terms_and_conditions", tag: "v0.13.4"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.6.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.11.3"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.6.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.0"'
    refute_includes gemfile, "1adc7722ec58fcfeb43ff1e2e96849936a6e9411"
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.349"'
    assert_includes gemfile, 'gem "view_component", "4.19.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Internationalization", tag: "v0.1.7"'
    assert_includes gemfile, "widen_recording_studio_requirement"
    refute_includes gemfile, 'tag: "v0.3.4"'
    refute_includes gemfile, 'tag: "v0.1.148"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v0.1.134"'
    refute_includes gemfile, 'tag: "0.3.1"'
    refute_includes gemfile, 'tag: "v0.1.84"'
    refute_includes gemfile, 'tag: "v4.7.0"'
    refute_includes gemfile, 'tag: "v0.1.245"'
  end

  def test_lockfiles_resolve_notifications_0_13_1
    root_lock = File.read(File.expand_path("../Gemfile.lock", __dir__))
    dummy_lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes root_lock, "tag: v0.13.1"
    assert_includes root_lock, "recording_studio_notifications (0.13.1)"
    assert_includes root_lock, "recording_studio_notifications (>= 0.3.1, < 1)"
    refute_includes root_lock, "recording_studio_notifications (0.7.0)"
    assert_includes dummy_lock, "tag: v0.13.1"
    assert_includes dummy_lock, "recording_studio_notifications (0.13.1)"
    refute_includes dummy_lock, "recording_studio_notifications (0.7.0)"
    assert_includes root_lock, "tag: v6.3.0"
    assert_includes root_lock, "recording_studio (6.3.0)"
    assert_includes root_lock, "tag: v0.1.349"
    assert_includes root_lock, "flat_pack (0.1.349)"
    assert_includes dummy_lock, "tag: v0.1.349"
    assert_includes dummy_lock, "flat_pack (0.1.349)"
    assert_includes root_lock, "view_component (4.19.0)"
    assert_includes dummy_lock, "view_component (4.19.0)"
  end

  def test_widen_rewrites_a_four_x_constraint_that_happens_to_contain_the_digit_six
    pessimistic = dependency_requirement("~> 4.6")
    assert pessimistic.satisfied_by?(Gem::Version.new("6.1.0"))
    assert_equal ">= 6.1.0", pessimistic.to_s

    already_open = dependency_requirement(">= 4.2")
    assert_equal ">= 4.2", already_open.to_s
    assert already_open.satisfied_by?(Gem::Version.new("6.1.0"))
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
    application_controller = File.read(
      File.expand_path("../app/controllers/recording_studio_messages/application_controller.rb", __dir__)
    )
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
    list_toolbar = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_list_toolbar.html.erb", __dir__)
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
    assert_includes routes, "patch :rename, on: :member"
    assert_includes routes, "resources :my_messages, only: %i[index show]"
    assert_includes application_controller, "include RecordingStudio::ControllerLayout"
    assert_includes controller, "def index"
    assert_includes controller, "viewable_group_recordings"
    assert_includes controller, "unread_filter?"
    assert_includes controller, "older_href_for"
    assert_includes controller, "authorize_mount_parent!"
    assert_includes controller, "authorize_group!(:view)"
    assert_includes controller, "include MessageGroupsRename"
    rename_actions = File.read(
      File.expand_path("../app/controllers/recording_studio_messages/message_groups_rename.rb", __dir__)
    )
    assert_includes rename_actions, "def rename"
    assert_includes rename_actions, "authorize_rename_mount!"
    assert_includes rename_actions, "rename_editable?"
    assert_includes rename_actions, "role: :edit"
    refute_includes rename_actions, "update_column"
    refute_includes controller, "update_column"
    assert_includes controller, "mark_read"
    assert_includes api, "def rename_group"
    assert_includes api, "def viewable_group_recordings"
    assert_includes api, "unread: false"
    assert_includes api, "def my_group_recordings"
    assert_includes api, "def mark_read"
    assert_includes api, "def unread?"
    assert_includes api, "def unread_count"
    assert_includes api, "def seen_by"
    assert_includes api, "def tag"
    assert_includes api, "def untag"
    assert_includes list_groups, "RecordingStudioAccessible.recordings_for"
    assert_includes list_groups, "MessageGroupTags.restrict"
    assert_includes list_groups, "minimum_role: :view"
    assert_includes list_groups, "RecordingStudioMessages::MESSAGE_GROUP_TYPE"
    assert_includes list_groups, "unread: false"
    assert_includes list_groups, "unread_ids_among"
    refute_includes list_groups, "authorized?"
    refute_includes list_groups, "WITH RECURSIVE"
    assert_includes helper, "def messages_inbox_rows"
    assert_includes helper, "inbox_unread?"
    assert_includes helper, "messages_unread_filter_button"
    assert_includes helper, "messages_unread_filter_href"
    assert_includes helper, "def messages_list_toolbar(mount:, actor:)"
    assert_includes helper, "def messages_list_header_title(mount:, actor:)"
    assert_includes helper, "messages_unread_filter_index_path"
    assert_includes helper, 'icon: "bell-alert"'
    refute_includes helper, "funnel"
    refute_includes helper, "unread_count:"
    assert_includes helper, "messages_inbox_row_complete?"
    assert_includes helper, "turbo_frame: messages_desk_panel_id"
    assert_includes helper, "turbo_stream: true"
    assert_includes helper, "def messages_unread_badge_id"
    assert_includes helper, "def messages_inbox_unread_dot_id"
    assert_includes helper, "def messages_inbox_title_id"
    assert_includes helper, "title_frame_id: messages_inbox_title_id(group_recording)"
    assert_includes helper, "def messages_inbox_row_link"
    assert_includes helper, "inbox: inbox"
    assert_includes helper, "messages_inbox_mount_name"
    my_messages_controller = File.read(
      File.expand_path("../app/controllers/recording_studio_messages/my_messages_controller.rb", __dir__)
    )
    assert_includes my_messages_controller, "my_group_recordings"
    assert_includes my_messages_controller, "mark_read"
    assert_includes my_messages_controller, "unread_filter?"
    refute_includes my_messages_controller, "viewable_group_recordings"
    refute_includes my_messages_controller, "authorize_mount_parent!"
    assert_includes my_messages_controller, "unless turbo_frame_request?"
    assert_includes my_messages_controller, "format.turbo_stream"
    assert_includes my_messages_controller, "inbox_member?"
    my_messages_stream = File.read(
      File.expand_path("../app/views/recording_studio_messages/my_messages/show.turbo_stream.erb", __dir__)
    )
    assert_includes my_messages_stream, "turbo_stream.update messages_desk_panel_id"
    assert_includes my_messages_stream, "turbo_stream.update messages_inbox_unread_dot_id"
    assert_includes my_messages_stream, "turbo_stream.update messages_unread_badge_id"
    rename_stream = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/rename.turbo_stream.erb", __dir__)
    )
    assert_includes rename_stream, "turbo_stream.update messages_inbox_title_id"
    assert_includes rename_stream, "FlatPack::Chat::InboxRow::Component"
    refute_includes rename_stream, "messages_inbox_rows"
    refute_includes my_messages_stream, "messages_inbox_rows"
    query = File.read(
      File.expand_path("../lib/recording_studio_messages/services/my_group_recordings.rb", __dir__)
    )
    assert_includes query, "AccessRoles"
    assert_includes query, "unread:"
    assert_includes query, "apply_unread"
    refute_includes query, "ELSE -1"
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
    assert_includes desk, "turbo_frame_tag inbox_row[:title_frame_id]"
    assert_includes list_toolbar, "unread_badge"
    assert_includes desk, "panel_frame"
    assert_includes panel_frame, "messages_desk_panel_id"
    assert_includes panel, "membership_locked_for_group?"
    assert_includes panel, "messages_panel_header_title(group_recording, actor: current_actor, inbox: inbox)"
    assert_includes panel, "messages_panel_right_header(group_recording, actor: current_actor, mount:"
    assert_includes panel, "messages_panel_right_header_mobile(group_recording, actor: current_actor, mount:"
    assert_includes panel, "messages_panel_after(group_recording, actor: current_actor, mount:"
    assert_includes panel, "panel.right_header do"
    assert_includes panel, "panel.right_header_mobile do"
    assert_includes panel, "flex items-center gap-2 whitespace-nowrap p-4"
    assert_includes panel, "if right_header.present?"
    assert_includes panel, "if right_header_mobile.present?"
    assert_includes panel_helper, "def messages_panel_right_header(group_recording, actor:, mount:)"
    assert_includes panel_helper, "def messages_panel_right_header_mobile(group_recording, actor:, mount:)"
    assert_includes panel_helper, "def messages_panel_after(group_recording, actor:, mount:)"
    assert_includes panel_helper, "def messages_can_rename_group?"
    assert_includes panel_helper, "def messages_panel_header_title"
    assert_includes panel_helper, "FlatPack::InlineEdit::Component"
    assert_includes panel_helper, "role: :edit"
    assert_includes panel, "if membership_open"
    assert_includes panel, "recording_studio_accessible_avatars"
    refute_includes panel, "show_access:"
    refute_includes desk, "show_access"
    refute_includes panel_frame, "show_access"
    refute_includes show, "show_access"
    index = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/index.html.erb", __dir__)
    )
    refute_includes index, "show_access"
    assert_includes index, "content_for :title"
    assert_includes index, "flat_pack_page_nav(round: true, style: :default"
    refute_includes index, "recording_studio_page_nav"
    refute_includes index, "FlatPack::PageTitle::Component"
    refute_includes panel, "back_href"
    assert_includes desk, "FlatPack::List::Component.new(spacing: :dense, selectable: true)"
    assert_includes desk, "FlatPack::Chat::InboxRow::Component"
    assert_includes desk, "unread_filter"
    assert_includes desk, "messages_list_toolbar(mount: mount_recording, actor: current_actor)"
    assert_includes desk, "messages_list_header_title(mount: mount_recording, actor: current_actor)"
    refute_includes desk, "sidebar_title"
    refute_includes desk, "messages_inbox_title(mount_recording)"
    refute_includes desk, 'inbox == :my_messages ? messages_t("inbox.my_title")'
    assert_includes desk, "list_toolbar"
    assert_includes desk, "title: list_title"
    assert_includes list_toolbar, "messages_unread_filter_button"
    assert_includes list_toolbar, "unread_filter"
    assert_includes list_toolbar, "list_toolbar.present?"
    assert_includes desk, "FlatPack::Chat::Header::Component"
    refute_includes desk, "inbox.filter_all"
    refute_includes desk, "filter_unread"
    assert_includes desk, '<div class="w-full min-w-0 <%= desk_height_class %>">'
    assert_includes desk, "h-[calc(100dvh-15.5rem)]"
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

    assert_includes controller_source, "recording_studio_layout"
    refute_includes controller_source, "UsesDefaultLayout"
    refute_includes controller_source, 'layout "recording_studio/default_layout"'
    assert_includes controller_source, '"application" if devise_controller?'
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

    assert_includes application_layout, "dummy_document_attributes"
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
    assert_includes initializer, "config.otp_enabled = true"
    assert_includes initializer, "config.otp_registration_enabled = true"
    assert_includes initializer, "config.otp_login_enabled = true"
    refute File.exist?(File.expand_path("dummy/app/views/devise/sessions/new.html.erb", __dir__))
  end

  def test_dummy_pins_turbo_and_loads_flatpack_js
    application_js = File.read(File.expand_path("dummy/app/javascript/application.js", __dir__))
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))

    assert_includes application_js, 'import "@hotwired/turbo-rails"'
    assert_includes importmap, 'pin "@hotwired/turbo-rails", to: "turbo.min.js"'
    assert_includes importmap, 'pin "flat_pack/copy", to: "flat_pack/copy.js"'
    assert_includes importmap, "pin_all_from FlatPack::Engine.root.join(\"app/javascript/flat_pack/controllers\")"
    assert_includes importmap, "flat-pack--chat-timestamp-reveal"
    assert_includes importmap, "recording_studio_messages/controllers"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "vendor/bundle/**/bundler/gems/flatpack-*/app/components/**/*.rb"
    assert_includes tailwind_source, "vendor/bundle/**/bundler/gems/RecordingStudio*/app/views/**/*.erb"
    assert_includes tailwind_source, "../../../../../vendor/bundle/**/bundler/gems/RecordingStudio*/app/views/**/*.erb"
    assert_includes tailwind_source, '@source inline("pt-16")'
    assert_includes tailwind_source, '@source inline("min-h-dvh")'
    assert_includes tailwind_source, '@source "../../helpers/**/*.rb"'
    refute_includes tailwind_source, '@source inline("dummy-language-selector")'
    refute_includes tailwind_source, '@source inline("[&_button]:sr-only")'
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
    refute_includes initializer_source, '"RecordingStudioAttachable::Library"'
    refute_includes initializer_source, '"RecordingStudioAttachable::Placement"'
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    assert_includes initializer_source, "RecordingStudioMessages::MessageMount"
    assert_includes initializer_source, "RecordingStudioMessages::MessageGroup"
    assert_includes initializer_source, "RecordingStudioMessages::Message"
    assert_includes initializer_source, '"Mailbox"'
    assert_includes initializer_source, '"AdminRoot"'
    assert_includes initializer_source, '"RecordingStudioSiteSettings::SiteSetting"'
    assert_includes initializer_source, '"RecordingStudioTermsAndConditions::Terms"'
    assert_includes initializer_source, '"RecordingStudioPublishable::Publishable"'
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "This Rails app exists to prove Recording Studio Messages"
    assert_includes readme_source, "/staff/desk"
    assert_includes readme_source, "/inbox"
    assert_includes readme_source, "/recording_studio_messages/my_messages"
    assert_includes readme_source, "https://flatpack.bowerbird.io/"
  end

  def test_readme_points_at_live_flatpack_kit
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "https://flatpack.bowerbird.io/"
    assert_includes readme, "ensure_message_mount"
    assert_includes readme, "notify_each"
    assert_includes readme, "admin_notification_root"
    assert_includes readme, "two mounts"
    assert_includes readme, "Do not add a Notifications → Messages dependency"
    assert_includes readme, "docs/cursor-skills.md"
    assert_includes readme, "membership_locked: [:support]"
    assert_includes readme, "access: :inherited"
    assert_includes readme, "contacts:"
    assert_includes readme, "allow_membership_change"
    refute_includes readme, "show_access"
    refute_includes readme, "flatpack-c6p8f.ondigitalocean.app"
    refute_includes readme, "v3.0.0"
    refute_includes readme, "0.1.84"
  end

  def test_membership_lock_module_is_wired
    api = File.read(File.expand_path("../lib/recording_studio_messages.rb", __dir__))
    lock = File.read(File.expand_path("../lib/recording_studio_messages/membership_lock.rb", __dir__))
    create_group_people = File.read(
      File.expand_path("../lib/recording_studio_messages/services/create_group_people.rb", __dir__)
    )

    assert_includes api, "membership_lock"
    assert_includes api, "def membership_locked?"
    assert_includes api, "def allow_membership_change"
    assert_includes api, "MembershipLock.install_authorizer_wrap!"
    assert_includes lock, "membership_locked"
    assert_includes lock, "access_management_authorizer"
    assert_includes lock, "allow_membership_change"
    assert_includes create_group_people, "allow_membership_change"
    assert_includes create_group_people, "MountAccess.inherited?"
    assert_includes File.read(
      File.expand_path("../lib/recording_studio_messages/mount_access.rb", __dir__)
    ), ":inherited"
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
    assert_includes helper, "def message_seen_by"
    assert_includes helper, "def message_receipt_readers"
    assert_includes stream, "turbo_stream.replace messages_panel_list_id"
    assert_includes stream, "turbo_stream.replace messages_panel_composer_id"
    refute_includes controller, "ActionCable"
    refute File.exist?(File.expand_path("../app/channels", __dir__))

    message = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_message.html.erb", __dir__)
    )
    list = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_message_list.html.erb", __dir__)
    )
    refute_includes message, "state: :sent"
    refute_includes message, "MessageMeta"
    assert_includes message, "reveal_timestamp: true"
    assert_includes message, "FlatPack::Chat::SentAt::Component"
    assert_includes message, "last_message && outgoing"
    assert_includes message, "group.status"
    assert_includes message, "message_receipt_readers"
    assert_includes message, "message_groups/message_seen"
    assert_includes list, "message_seen_by"
    assert_includes list, "message_time_break?"
    assert_includes list, "message_day_break?"
  end

  def test_public_contact_does_not_reference_users_otp_internals
    roots = [
      File.expand_path("../lib", __dir__),
      File.expand_path("../app", __dir__),
      File.expand_path("../README.md", __dir__),
      File.expand_path("../CHANGELOG.md", __dir__)
    ]
    offenders = []
    roots.each do |root|
      paths = File.directory?(root) ? Dir.glob(File.join(root, "**/*.{rb,md,erb}")) : [root]
      paths.each do |path|
        text = File.read(path)
        next unless text.include?("OtpChallenge") || text.include?("OtpRateLimiter")

        offenders << path
      end
    end
    contact_test = File.read(File.expand_path("dummy/test/integration/public_contact_test.rb", __dir__))

    assert_empty offenders
    refute_includes contact_test, "OtpChallenge"
    refute_includes contact_test, "OtpRateLimiter"
    refute_includes contact_test, "Member"
  end

  def test_public_contact_and_composer_use_flatpack_heading_chat_and_modal_apis
    modal = File.read(
      File.expand_path("../app/views/recording_studio_messages/public_contacts/_modal.html.erb", __dir__)
    )
    form = File.read(
      File.expand_path("../app/views/recording_studio_messages/public_contacts/_form.html.erb", __dir__)
    )
    verify = File.read(
      File.expand_path("../app/views/recording_studio_messages/public_contacts/code.html.erb", __dir__)
    )
    sent = File.read(
      File.expand_path("../app/views/recording_studio_messages/public_contacts/sent.html.erb", __dir__)
    )
    composer = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_composer.html.erb", __dir__)
    )

    assert_includes modal, 'document.addEventListener("turbo:before-cache"'
    assert_includes modal, "title.hidden = false"
    assert_includes modal, 'document.addEventListener("turbo:frame-load"'
    assert_includes modal, "heading.hidden"
    refute_includes modal, 'modal.classList.add("hidden")'
    refute_includes modal, "flatPackModalLockCount"
    refute_includes modal, "document.body.style.overflow"
    assert_includes form, "FlatPack::Heading::Component.new(text: title, level: 1, size: :xl)"
    assert_includes verify, "RecordingStudioUser::OtpCodeForm"
    assert_includes verify, "data-public-contact-step=\"verify\""
    refute_includes form, 'h1 class="text-xl font-semibold"'
    refute_includes verify, 'h1 class="text-xl font-semibold"'
    assert_includes sent, 'size: :"3xl"'
    refute_includes sent, 'h1 class="text-3xl font-semibold"'
    assert_includes composer, "variant: :chat"
    assert_includes composer, "recording-studio-messages--composer"
    assert_includes composer, "chipTemplate"
    assert_includes composer, "messages_composer_actions"
    assert_includes composer, "composer_action_modal"
    refute_includes composer, "action.partial"
    refute_includes composer, "min-h-[var(--chat-composer-control-height)]"
    refute_includes composer, "rounded-lg"

    action_modal = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_composer_action_modal.html.erb", __dir__)
    )
    composer_js = File.read(
      File.expand_path("../app/javascript/recording_studio_messages/controllers/composer_controller.js", __dir__)
    )
    assert_includes action_modal, "FlatPack::Modal::Component"
    assert_includes action_modal, "loading: :lazy"
    assert_includes action_modal, "action.partial"
    assert_includes action_modal, "group_recording"
    assert_includes action_modal, "actor"
    assert_includes action_modal, "mount"
    assert_includes action_modal, "action"
    assert_includes composer_js, "closeOpenActionModal"
    assert_includes composer_js, "messages:composer-insert"
    assert_includes composer_js, "addReference"
    assert_includes composer_js, "[id^='messages-composer-action-']"
    message_partial = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_message.html.erb", __dir__)
    )
    assert_includes message_partial, "recording_studio_messages/message_groups/reference_card"
    card = File.read(
      File.expand_path("../app/views/recording_studio_messages/message_groups/_reference_card.html.erb", __dir__)
    )
    assert_includes card, "FlatPack::Chat::LinkCard::Component"
  end

  def test_public_contact_page_loads_flatpack_application_styles
    layout = File.read(
      File.expand_path("../app/views/layouts/recording_studio_messages/public_contact.html.erb", __dir__)
    )

    assert_includes layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes layout, 'stylesheet_link_tag "flat_pack/variables"'
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

  def dependency_requirement(*requirements)
    spec = Gem::Specification.new("widen-example", "0.0.1")
    spec.add_dependency("recording_studio", *requirements)
    spec.dependencies.find { |dependency| dependency.name == "recording_studio" }.requirement
  end

  def gemfile_constraint(gemfile, name)
    match = gemfile.match(/gem "#{Regexp.escape(name)}", "([^"]+)"/)
    match && match[1]
  end
end
