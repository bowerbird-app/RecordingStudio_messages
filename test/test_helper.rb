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
Time.zone ||= "UTC"
require "recording_studio_messages"
