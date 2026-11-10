# frozen_string_literal: true

require "test_helper"

class ComposerActionRegistryTest < Minitest::Test
  def setup
    @actions = RecordingStudioMessages.configuration.composer_actions
    @previous = @actions.dup
    @actions.clear
  end

  def teardown
    @actions.clear
    @previous.each { |key, value| @actions[key] = value }
  end

  def test_if_filters_registered_composer_actions
    RecordingStudioMessages.register_composer_action(
      :always,
      label: "Always",
      icon: "plus",
      partial: "dummy/always"
    )
    RecordingStudioMessages.register_composer_action(
      :staff_only,
      label: "Staff",
      icon: "plus",
      partial: "dummy/staff",
      if: ->(_group, actor, _mount) { actor == :staff }
    )

    kept = RecordingStudioMessages.composer_actions_for(:group, :staff, :mount).map(&:key)
    hidden = RecordingStudioMessages.composer_actions_for(:group, :customer, :mount).map(&:key)

    assert_equal %w[always staff_only], kept
    assert_equal %w[always], hidden
  end
end
