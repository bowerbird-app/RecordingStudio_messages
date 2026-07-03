# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioMessages::Configuration.new
  end

  def test_multiple_message_keys_and_container_collection
    @configuration.messages(:support) { |messages| messages.container_type = "SupportMessages" }
    @configuration.messages(:site) { |messages| messages.container_type = "SiteMessages" }

    assert_equal %w[SupportMessages SiteMessages], @configuration.container_recordable_types
    assert_equal :support, @configuration.message_config!(:support).key
  end

  def test_default_create_group_authorization_is_container_edit
    config = @configuration.messages(:support)

    assert_equal({ type: :container_access, role: :edit }, config.effective_create_group_authorization)
  end

  def test_action_authorization_config_validates_action
    config = @configuration.messages(:site)
    config.container_type = "SiteMessages"
    config.create_group_authorization = { type: :action, action: :"recording_studio_messages.create_group" }

    assert config.validate!
  end

  def test_unknown_role_fails_configuration
    config = @configuration.messages(:site)
    config.container_type = "SiteMessages"
    config.create_group_authorization = { type: :container_access, role: :owner }

    assert_raises(RecordingStudioMessages::ConfigurationError) { config.validate! }
  end

  def test_recipient_defaults_fail_closed
    config = @configuration.messages(:site)

    assert_empty config.recipient_actor_types
    assert_nil config.recipient_search
    assert_nil config.recipient_allowed
    assert_equal 2, config.minimum_recipient_query_length
    assert_equal 10, config.recipient_search_limit
    assert_equal 50, config.max_recipients
  end

  def test_hooks_registry_is_configured
    calls = []

    @configuration.hooks.after_initialize { calls << :after_initialize }
    @configuration.hooks.run(:after_initialize)

    assert_equal [:after_initialize], calls
  end
end
