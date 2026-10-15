# frozen_string_literal: true

require "test_helper"

class FlatpackCardStylesTest < ActiveSupport::TestCase
  test "legacy outlined and elevated card styles map onto the 0.1.237 API" do
    outlined = FlatPack::Card::Component.new(style: :outlined, hover: :subtle)
    assert_equal :default, outlined.instance_variable_get(:@style)
    assert_equal :strong, outlined.instance_variable_get(:@border)
    assert_equal :subtle, outlined.instance_variable_get(:@hover)
    assert_equal :none, outlined.instance_variable_get(:@shadow)

    elevated = FlatPack::Card::Component.new(style: :elevated)
    assert_equal :default, elevated.instance_variable_get(:@style)
    assert_equal :md, elevated.instance_variable_get(:@shadow)
    assert_equal :default, elevated.instance_variable_get(:@border)
  end

  test "current card styles stay unchanged" do
    card = FlatPack::Card::Component.new(style: :shaded, shadow: :sm, border: :none)

    assert_equal :shaded, card.instance_variable_get(:@style)
    assert_equal :sm, card.instance_variable_get(:@shadow)
    assert_equal :none, card.instance_variable_get(:@border)
  end
end
