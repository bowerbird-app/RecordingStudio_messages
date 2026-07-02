# frozen_string_literal: true

require "test_helper"

class RecordingStudioMessagesTest < Minitest::Test
  def test_has_version
    refute_nil RecordingStudioMessages::VERSION
  end

  def test_engine_is_isolated
    assert_kind_of Class, RecordingStudioMessages::Engine
    assert_equal RecordingStudioMessages, RecordingStudioMessages::Engine.isolated? && RecordingStudioMessages
  end
end
