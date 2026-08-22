# frozen_string_literal: true

require "test_helper"

class RecordingStudioMessagesTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.1.0", ::RecordingStudioMessages::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioMessages::Engine
  end

  def test_gemspec_pins_recording_studio_family
    gemspec = File.read(File.expand_path("../recording_studio_messages.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.7"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_attachable", "~> 0.4"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_notifications", "~> 0.2"'
    assert_includes gemspec, 'spec.add_dependency "flat_pack", "~> 0.1.133"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_publishable"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
  end

  def test_dummy_gemfile_pins_verified_family_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.7.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.2.5"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.133"'
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
    refute_includes initializer_source, "MessageMount"
    refute_includes initializer_source, "MessageGroup"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "This Rails app exists to prove Recording Studio Messages"
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "https://flatpack.bowerbird.io/"
  end

  def test_readme_points_at_live_flatpack_kit
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "https://flatpack.bowerbird.io/"
    refute_includes readme, "flatpack-c6p8f.ondigitalocean.app"
    refute_includes readme, "v3.0.0"
    refute_includes readme, "0.1.84"
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_messages/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end
end
