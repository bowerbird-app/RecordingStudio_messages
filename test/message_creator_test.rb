# frozen_string_literal: true

require "test_helper"
require "ostruct"

class MessageCreatorTest < Minitest::Test
  FakeActor = Struct.new(:id)

  class FakeGroupRecording
    attr_reader :created_message, :record_calls, :recordable
    attr_accessor :touched

    def initialize
      @record_calls = []
      @recordable = FakeGroupRecordable.new
    end

    def id = "message-group-recording-id"

    def record(recordable_class, actor:, parent_recording: nil)
      message = OpenStruct.new
      @record_calls << { recordable_class: recordable_class, actor: actor, parent_recording: parent_recording }
      yield message
      @created_message = message
      OpenStruct.new(recordable: message)
    end

    def touch
      @touched = true
    end
  end

  class FakeGroupRecordable
    attr_reader :updates

    def update!(attrs)
      @updates = attrs
    end
  end

  def test_create_parents_message_recording_under_group_recording
    actor = FakeActor.new("actor-id")
    group_recording = FakeGroupRecording.new

    result = RecordingStudioMessages::MessageCreator.new(
      message_group_recording: group_recording,
      actor: actor,
      body: "Hello",
      content: { "kind" => "text" },
      metadata: { "source" => "test" }
    ).create!

    assert_same group_recording.created_message, result.recordable
    assert_equal [
      {
        recordable_class: RecordingStudioMessages::Message,
        actor: actor,
        parent_recording: group_recording
      }
    ], group_recording.record_calls
    assert_equal group_recording.recordable, group_recording.created_message.message_group
    assert_equal "Hello", group_recording.created_message.body
    assert_equal({ "kind" => "text" }, group_recording.created_message.content)
    assert_equal({ "source" => "test" }, group_recording.created_message.metadata)
    assert_equal actor.class.name, group_recording.created_message.sender_type
    assert_equal "actor-id", group_recording.created_message.sender_id
    assert group_recording.touched
    assert_in_delta Time.current, group_recording.recordable.updates.fetch(:last_message_at), 2
  end
end
