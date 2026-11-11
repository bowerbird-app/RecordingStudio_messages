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

  def test_register_composer_action_requires_exactly_one_of_partial_or_src
    error = assert_raises(ArgumentError) do
      RecordingStudioMessages.register_composer_action(:neither, label: "No", icon: "plus")
    end
    assert_includes error.message, "exactly one of partial: or src:"

    error = assert_raises(ArgumentError) do
      RecordingStudioMessages.register_composer_action(
        :both,
        label: "Both",
        icon: "plus",
        partial: "dummy/always",
        src: "/dummy/page_picker"
      )
    end
    assert_includes error.message, "exactly one of partial: or src:"
  end

  def test_src_action_is_lazy_and_resolves_a_callable
    RecordingStudioMessages.register_composer_action(
      :pages,
      label: "Attach a page",
      icon: "document-text",
      title: "Pick a page",
      size: :md,
      src: ->(_group, _actor, mount) { "/dummy/page_picker?mount_id=#{mount}" }
    )
    action = RecordingStudioMessages.composer_actions_for(:group, :staff, "mount-1").first

    assert action.lazy?
    assert_equal "Pick a page", action.modal_title
    assert_equal :md, action.modal_size
    assert_equal "/dummy/page_picker?mount_id=mount-1", action.resolved_src(:group, :staff, "mount-1")
  end

  def test_partial_action_is_eager
    RecordingStudioMessages.register_composer_action(
      :note,
      label: "Note",
      icon: "plus",
      partial: "dummy/note"
    )
    action = RecordingStudioMessages.composer_actions_for(:group, :staff, :mount).first

    refute action.lazy?
    assert_equal "Note", action.modal_title
    assert_equal :sm, action.modal_size
    assert_nil action.resolved_src(:group, :staff, :mount)
  end
end
