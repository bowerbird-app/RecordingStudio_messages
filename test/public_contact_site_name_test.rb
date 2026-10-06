# frozen_string_literal: true

require "test_helper"

class PublicContactSiteNameTest < Minitest::Test
  Root = Struct.new(:recordable)
  Recording = Struct.new(:root_recording)
  Named = Struct.new(:name)

  def test_powered_by_uses_the_root_name_when_site_settings_are_absent
    recording = Recording.new(Root.new(Named.new("Quiet Crop")))

    assert_equal "Powered by Quiet Crop", RecordingStudioMessages::PublicContact::SiteName.powered_by(recording)
  end

  def test_powered_by_is_blank_without_a_name
    assert_nil RecordingStudioMessages::PublicContact::SiteName.powered_by(nil)
    assert_nil RecordingStudioMessages::PublicContact::SiteName.powered_by(Recording.new(nil))
    assert_nil RecordingStudioMessages::PublicContact::SiteName.powered_by(Recording.new(Root.new(Object.new)))
    assert_nil RecordingStudioMessages::PublicContact::SiteName.powered_by(Recording.new(Root.new(Named.new("  "))))
  end

  def test_site_settings_name_wins_over_the_root_name
    recording = Recording.new(Root.new(Named.new("Workspace")))

    with_site_settings("Quiet Crop") do
      assert_equal "Powered by Quiet Crop", RecordingStudioMessages::PublicContact::SiteName.powered_by(recording)
    end
  end

  def test_blank_site_settings_name_falls_back_to_the_root_name
    recording = Recording.new(Root.new(Named.new("Workspace")))

    with_site_settings(nil) do
      assert_equal "Powered by Workspace", RecordingStudioMessages::PublicContact::SiteName.powered_by(recording)
    end
  end

  private

  def with_site_settings(name)
    previous = Object.const_defined?(:RecordingStudioSiteSettings) ? RecordingStudioSiteSettings : nil
    Object.send(:remove_const, :RecordingStudioSiteSettings) if previous
    settings = Module.new
    settings.define_singleton_method(:name_for) { |_root| name }
    Object.const_set(:RecordingStudioSiteSettings, settings)
    yield
  ensure
    Object.send(:remove_const, :RecordingStudioSiteSettings) if Object.const_defined?(:RecordingStudioSiteSettings)
    Object.const_set(:RecordingStudioSiteSettings, previous) if previous
  end
end
