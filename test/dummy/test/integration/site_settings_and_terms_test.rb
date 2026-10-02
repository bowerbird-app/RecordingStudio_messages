# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SiteSettingsAndTermsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
  end

  test "dummy host registers site settings, terms, and publishable" do
    assert_equal ["Workspace"], RecordingStudioSiteSettings.configuration.site_root_types
    types = RecordingStudio.configuration.recordable_types.map(&:to_s)
    assert_includes types, "RecordingStudioSiteSettings::SiteSetting"
    assert_includes types, "RecordingStudioTermsAndConditions::Terms"
    assert_includes types, "RecordingStudioPublishable::Publishable"
    assert_includes types, "AdminRoot"
    assert_includes ApplicationController.ancestors, RecordingStudioTermsAndConditions::ForcesAcceptance
    assert RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioSiteSettings::SiteSetting)
    section_keys = AdminRoot.recording_studio_admin_section_keys_for(nil, nil, nil).map(&:to_s)
    assert_includes section_keys, "site_settings"
    assert_includes section_keys, "terms"

    admin_root = AdminRoot.find_by!(name: "Admin")
    admin_recording = RecordingStudio::Recording.find_by!(recordable: admin_root)

    assert_nil admin_recording.parent_recording_id
    assert RecordingStudioAccessible.authorized?(actor: @staff, recording: admin_recording, role: :admin)
    assert RecordingStudioSiteSettings.recording_for(RecordingStudio.root_recording_for(Workspace.find_by!(name: "Studio Workspace")))
  end

  test "staff opens site settings from admin and terms stays quiet until something is live" do
    sign_in @staff

    get root_path

    assert_response :success
    assert_select "a[href=?]", recording_studio_admin_admin.root_path, text: "Admin"

    get recording_studio_admin_admin.root_path

    assert_response :success
    assert_includes response.body, "Name, logos, and the browser tab icon."

    get recording_studio_admin_admin.section_path("terms")

    assert_response :success
    assert_includes response.body, "Terms and Conditions"

    get recording_studio_site_settings.settings_path

    assert_response :success
    assert_includes response.body, "Site name and logos"
    assert_select "input[name='site_setting[name]'][value=?]", "Studio Workspace"

    get "/"

    assert_response :success
    assert_select "h1", text: "Dummy host"
  end
end
