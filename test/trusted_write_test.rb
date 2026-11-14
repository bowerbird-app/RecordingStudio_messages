# frozen_string_literal: true

require "test_helper"

class TrustedWriteTest < Minitest::Test
  def setup
    @mount = Object.new
    @previous = Thread.current[RecordingStudioMessages::TrustedWrite::THREAD_KEY]
    Thread.current[RecordingStudioMessages::TrustedWrite::THREAD_KEY] = nil
  end

  def teardown
    Thread.current[RecordingStudioMessages::TrustedWrite::THREAD_KEY] = @previous
  end

  def test_context_is_nil_outside_the_block
    assert_nil RecordingStudioMessages.trusted_write_context

    seen = RecordingStudioMessages.trusted_write(action: :create_group, mount_recording: @mount) do
      RecordingStudioMessages.trusted_write_context
    end

    assert_equal :create_group, seen.action
    assert_same @mount, seen.mount_recording
    assert_predicate seen, :frozen?
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  def test_nested_writes_restore_the_outer_context
    inner = nil

    RecordingStudioMessages.trusted_write(action: :create_group, mount_recording: @mount) do
      RecordingStudioMessages.trusted_write(action: :send_message, mount_recording: @mount) do
        inner = RecordingStudioMessages.trusted_write_context
      end

      assert_equal :create_group, RecordingStudioMessages.trusted_write_context.action
      assert_same @mount, RecordingStudioMessages.trusted_write_context.mount_recording
    end

    assert_equal :send_message, inner.action
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  def test_context_is_restored_when_the_block_raises
    during = nil

    assert_raises(RuntimeError) do
      RecordingStudioMessages.trusted_write(action: :rename_group, mount_recording: @mount) do
        during = RecordingStudioMessages.trusted_write_context
        raise "write failed"
      end
    end

    assert_equal :rename_group, during.action
    assert_same @mount, during.mount_recording
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  def test_an_unknown_action_does_not_replace_the_current_context
    assert_raises(ArgumentError) do
      RecordingStudioMessages.trusted_write(action: :create_group, mount_recording: @mount) do
        RecordingStudioMessages.trusted_write(action: :publish, mount_recording: @mount) { flunk }
      end
    end

    assert_nil RecordingStudioMessages.trusted_write_context
  end

  def test_services_mark_only_the_vetted_writes
    create_group = source("services/create_group.rb")
    send_persist = source("services/send_message_persist.rb")
    rename_group = source("services/rename_group.rb")
    ensure_mount = source("services/ensure_mount.rb")
    delivery = source("public_contact/delivery.rb")
    inherited = source("public_contact/inherited.rb")

    assert_includes create_group, "trusted_write(action: :create_group, mount_recording: @mount_recording)"
    assert_includes send_persist, "trusted_write(action: :send_message, mount_recording: group_mount)"
    assert_equal 2, send_persist.scan("trusted_write(action: :send_message").size
    assert_includes rename_group, "trusted_write(action: :rename_group, mount_recording: mount)"
    refute_includes ensure_mount, "trusted_write"
    assert_includes delivery, "RecordingStudioMessages.create_group"
    assert_includes delivery, "RecordingStudioMessages.send_message"
    assert_includes inherited, "RecordingStudioMessages.create_group"
    assert_includes inherited, "send_contact_message"
    refute_includes delivery, "RecordingStudio.record!"
    refute_includes inherited, "RecordingStudio.record!"
    refute_includes delivery, "trusted_write"
    refute_includes inherited, "trusted_write"

    Dir[File.expand_path("../app/controllers/**/*.rb", __dir__)].each do |path|
      refute_includes File.read(path), "trusted_write", path
    end
  end

  def test_readme_documents_the_marker_and_a_host_policy
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudioMessages.trusted_write_context"
    assert_includes readme, ":create_group"
    assert_includes readme, ":send_message"
    assert_includes readme, ":rename_group"
    assert_includes readme, "config.authorize_write"
  end

  private

  def source(path)
    File.read(File.expand_path("../lib/recording_studio_messages/#{path}", __dir__))
  end
end
