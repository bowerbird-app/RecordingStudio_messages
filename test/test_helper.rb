# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
begin
  require "minitest/mock"
rescue LoadError
  # Minitest 6 removed minitest/mock. Tests that call Object#stub need the
  # minitest-mock gem, or they skip this require and use a local helper.
end
require "rails"
require "active_record"
require "active_support/time"
require "i18n"
Time.zone ||= "UTC"
require "recording_studio_messages"

locale_file = File.expand_path("../config/locales/en.yml", __dir__)
I18n.load_path << locale_file unless I18n.load_path.include?(locale_file)
I18n.backend.load_translations
I18n.available_locales = Array(I18n.available_locales) | %i[en]
I18n.default_locale = :en
