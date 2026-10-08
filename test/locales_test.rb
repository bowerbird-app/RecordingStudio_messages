# frozen_string_literal: true

require "test_helper"
require "yaml"
require_relative "../app/helpers/recording_studio_messages/copy_helper"
require_relative "../app/helpers/recording_studio_messages/public_contact_helper"

class LocalesTest < Minitest::Test
  Copy = RecordingStudioMessages::Copy

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_dummy_french_covers_every_engine_english_key
    english = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en"))
    french = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr"))
    missing = english - french

    assert_empty missing, "dummy fr.yml is missing keys present in engine en.yml: #{missing.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    I18n.with_locale(:en) do
      assert_equal "Contact", Copy.t("contact.title")
      assert_equal "Send message", Copy.t("contact.submit")
      assert_equal "Verify it's you", Copy.t("contact.verify_title")
      assert_equal "Message sent", Copy.t("contact.sent_title")
      assert_equal "Write a message", Copy.t("composer.placeholder")
      assert_equal "Nothing here yet. Write the first line.", Copy.t("inbox.empty_thread")
      assert_equal "Sent.", Copy.t("flashes.sent")
      assert_equal "Fresh code on the way.", Copy.t("flashes.code_resent")
      assert_equal "Enter your name.", Copy.t("errors.enter_name")
      assert_equal "Powered by Quiet Crop", Copy.t("contact.powered_by", name: "Quiet Crop")
    end
  end

  def test_component_text_overrides_win_including_nil
    assert_equal "Contact", Copy.value(Copy::UNSET, "contact.title")
    assert_equal "Write to us", Copy.value("Write to us", "contact.title")
    assert_nil Copy.value(nil, "contact.title")
  end

  def test_public_contact_helper_arguments_override_locale_defaults
    helper = PublicContactHelperHost.new
    locals = helper.public_contact_form(Object.new, title: "Write to us", submit_label: "Ship it", heading: true)

    assert_equal "Write to us", locals[:title]
    assert_equal "Ship it", locals[:submit_label]

    defaults = helper.public_contact_form(Object.new, heading: true)
    assert_equal "Contact", defaults[:title]
    assert_equal "Send message", defaults[:submit_label]
  end

  def test_host_translation_overrides_english
    I18n.backend.store_translations(:en, acme_title)
    assert_equal "Write to us", Copy.t("contact.title")
  ensure
    I18n.backend.store_translations(:en, default_title)
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_messages.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale)
    yaml = YAML.safe_load_file(path, aliases: true)
    yaml.fetch(locale).fetch("recording_studio").fetch("messages")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end

  def acme_title
    { recording_studio: { messages: { contact: { title: "Write to us" } } } }
  end

  def default_title
    { recording_studio: { messages: { contact: { title: "Contact" } } } }
  end
end

class PublicContactHelperHost
  include RecordingStudioMessages::PublicContactHelper

  def params
    {}
  end

  def render(_partial, **locals)
    locals
  end
end
