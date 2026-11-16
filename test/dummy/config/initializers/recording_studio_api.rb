# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudioApi.configure do |config|
  config.documentation_enabled = true
  config.documentation_access = :public
  config.openapi_title = "Messages API"
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_fail_closed = false
  config.api_management_authorization_required = false
end

# Notifications through 0.19 and Users through 0.31 register :id paths
# without recordable_type. API 0.26 raises. Messages passes recordable_type.
# This only opts those other callers out so the dummy can boot.
module RecordingStudioMessagesDummyApiScope
  def register_endpoint(name, **kwargs)
    path = kwargs[:path].to_s
    scoped = path.match?(%r{(?:^|/):(?:id|recording_id)(?:/|$)})
    if scoped && kwargs[:recordable_type].blank? && !kwargs.key?(:scope_id)
      kwargs[:scope_id] = false
    end

    super
  end
end
RecordingStudioApi.singleton_class.prepend(RecordingStudioMessagesDummyApiScope)
