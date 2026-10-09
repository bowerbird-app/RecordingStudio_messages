# frozen_string_literal: true

require "test_helper"

class MetricsDependencyTest < Minitest::Test
  def test_gemspec_and_lockfiles_pin_metrics
    gemspec = File.read(File.expand_path("../recording_studio_messages.gemspec", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    root_lock = File.read(File.expand_path("../Gemfile.lock", __dir__))
    dummy_lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_metrics", "~> 0.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.2.0"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.2.0"'
    assert_includes root_lock, "remote: https://github.com/bowerbird-app/RecordingStudio_metrics.git"
    assert_includes root_lock, "tag: v0.2.0"
    assert_includes root_lock, "recording_studio_metrics (0.2.0)"
    assert_includes dummy_lock, "remote: https://github.com/bowerbird-app/RecordingStudio_metrics.git"
    assert_includes dummy_lock, "tag: v0.2.0"
    assert_includes dummy_lock, "recording_studio_metrics (0.2.0)"
    assert_includes root_lock, "recording_studio_messages (0.6.0)"
    assert_includes dummy_lock, "recording_studio_messages (0.6.0)"
  end

  def test_engine_registers_metrics_on_reload
    initializer = RecordingStudioMessages::Engine.initializers.find do |item|
      item.name == "recording_studio_messages.metrics"
    end

    assert initializer
  end
end
