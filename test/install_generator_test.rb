# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_messages/install/install_generator"
require "generators/recording_studio_messages/container/container_generator"

class InstallGeneratorTest < Minitest::Test
  INSTALL_TEMPLATE_PATH = File.expand_path(
    "../lib/generators/recording_studio_messages/install/templates/INSTALL.md",
    __dir__
  )

  def build_generator(destination_root, options = {})
    RecordingStudioMessages::Generators::InstallGenerator.new([], options, destination_root: destination_root)
  end

  def test_mount_engine_uses_configured_mount_path
    generator = build_generator("/tmp", mount_path: "/messages")
    routes = []

    generator.stub(:route, ->(value) { routes << value }) { generator.mount_engine }

    assert_equal ["mount RecordingStudioMessages::Engine, at: \"/messages\""], routes
  end

  def test_install_guide_mentions_authorization_and_recipients
    install_guide = File.read(INSTALL_TEMPLATE_PATH)

    assert_includes install_guide, "recording_studio_accessible >= 0.4.1"
    assert_includes install_guide, "default container `:edit` authorization"
    assert_includes install_guide, "Do not grant broad root access"
    assert_includes install_guide, "recipient_search"
  end

  def test_container_generator_model_declares_root_container
    Dir.mktmpdir do |dir|
      generator = RecordingStudioMessages::Generators::ContainerGenerator.new(["SiteMessages"], { root: true }, destination_root: dir)
      generator.create_model

      model = File.read(File.join(dir, "app/models/site_messages.rb"))
      assert_includes model, "class SiteMessages < ApplicationRecord"
      assert_includes model, "root: true"
      assert_includes model, "allowed_parent_types: []"
    end
  end
end
