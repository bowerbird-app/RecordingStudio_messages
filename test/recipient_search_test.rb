# frozen_string_literal: true

require "test_helper"

class RecipientSearchTest < Minitest::Test
  FakeRecipient = Struct.new(:id, :email, :active, keyword_init: true) do
    def self.name = "User"
    def model_name = ActiveModel::Name.new(self.class)
  end

  def config
    RecordingStudioMessages::MessagesConfig.new(:site).tap do |messages|
      messages.container_type = "SiteMessages"
      messages.recipient_actor_types = ["User"]
      messages.recipient_search = ->(query:, limit:, **) { @search_args = [query, limit]; @recipients }
      messages.recipient_allowed = ->(recipient:, **) { recipient.active == true }
      messages.recipient_label = ->(recipient:) { recipient.email }
    end
  end

  def test_returns_no_results_below_minimum_query_length
    @recipients = [FakeRecipient.new(id: 1, email: "a@example.com", active: true)]

    assert_empty RecordingStudioMessages::RecipientSearch.new(
      messages_config: config,
      query: "a",
      actor: :actor,
      container_recording: :recording
    ).results
  end

  def test_shapes_and_filters_results
    @recipients = [
      FakeRecipient.new(id: 1, email: "active@example.com", active: true),
      FakeRecipient.new(id: 2, email: "inactive@example.com", active: false)
    ]

    results = RecordingStudioMessages::RecipientSearch.new(
      messages_config: config,
      query: "ac",
      actor: :actor,
      container_recording: :recording
    ).results

    assert_equal [{ type: "User", id: "1", label: "active@example.com", description: "active@example.com" }], results
    assert_equal ["ac", 10], @search_args
  end

  def test_fails_closed_without_hooks
    assert_empty RecordingStudioMessages::RecipientSearch.new(
      messages_config: RecordingStudioMessages::MessagesConfig.new(:site),
      query: "alex",
      actor: :actor,
      container_recording: :recording
    ).results
  end
end
