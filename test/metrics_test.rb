# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
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
end
