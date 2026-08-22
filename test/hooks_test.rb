# frozen_string_literal: true

require "test_helper"

class HooksTest < Minitest::Test
  def test_does_not_ship_a_copied_hooks_class
    refute File.exist?(File.expand_path("../lib/recording_studio_messages/hooks.rb", __dir__))
    refute defined?(RecordingStudioMessages::Hooks)
  end

  def test_configuration_hooks_are_core_recording_studio_hooks
    configuration = RecordingStudioMessages::Configuration.new

    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  end

  def test_engine_runs_addon_hooks_through_configuration
    called = false
    RecordingStudioMessages.configuration.hooks.after_initialize { called = true }

    initializer = RecordingStudioMessages::Engine.initializers.find do |entry|
      entry.name == "recording_studio_messages.after_initialize"
    end
    initializer.block.call(Object.new)

    assert called
  ensure
    RecordingStudioMessages.configuration.hooks.clear!
  end
end
