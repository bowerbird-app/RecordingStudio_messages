# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  MCP_TOOLS = {
    "messages.sent_over_time" => "messages-sent_over_time",
    "message_groups.created_over_time" => "message_groups-created_over_time",
    "contact_intents.submitted_over_time" => "contact_intents-submitted_over_time",
    "contact_intents.converted" => "contact_intents-converted"
  }.freeze

  def test_access_can_view_is_false_without_actor_or_admin_root
    context = Object.new
    def context.access_grant
      nil
    end

    refute RecordingStudioMessages::Api::Access.can_view?(context)
  end

  def test_metrics_module_exposes_operations_api
    assert_equal :operations, RecordingStudioMessages::Metrics::API
    assert_equal({ api: [:operations] }, RecordingStudioMessages::Metrics::EXPOSE)
  end

  def test_metrics_file_registers_definitions_with_can_view
    source = File.read(File.expand_path("../lib/recording_studio_messages/metrics.rb", __dir__))

    assert_includes source, "RecordingStudioMetrics.register("
    assert_includes source, "api_authorize: access_check"
    assert_includes source, "RecordingStudioMessages::Api::Access.can_view?(context)"
    refute_includes source, "RecordingStudioMetrics::Api.register!"
  end

  def test_docs_name_mcp_tools_and_timeseries_windows
    readme = File.read(File.expand_path("../README.md", __dir__))
    how = File.read(File.expand_path("../docs/how-it-works.md", __dir__))

    MCP_TOOLS.each do |identifier, tool|
      assert_includes readme, identifier
      assert_includes readme, tool
      assert_includes how, identifier
      assert_includes how, tool
    end

    assert_includes readme, "`from`, `to`, and `interval` apply to timeseries only"
    assert_includes how, "`from`, `to`, `interval`"
    assert_includes how, "none (breakdown)"
  end
end
