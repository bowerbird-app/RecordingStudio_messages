# frozen_string_literal: true

module RecordingStudioMessages
  class Configuration
    DEFAULT_TIME_BREAK_AFTER = 15.minutes

    attr_accessor :api_key, :enable_feature_x, :timeout,
                  :admin_notification_root,
                  :public_contact_recipient_resolver, :public_contact_sent_icon,
                  :public_contact_sign_in_after_verification,
                  :public_contact_success_redirect_url, :public_contact_success_redirect_label
    attr_reader :hooks, :layout, :read_receipts, :time_break_after

    def initialize
      @hooks = RecordingStudio::Hooks.new
      assign_defaults
    end

    def read_receipts=(value)
      @read_receipts = ActiveModel::Type::Boolean.new.cast(value)
    end

    def time_break_after=(value)
      @time_break_after = coerce_time_break_after(value)
    end

    def layout=(value)
      @layout = RecordingStudio::Layout.accept(value)
    end

    def to_h
      {
        api_key: api_key,
        enable_feature_x: enable_feature_x,
        timeout: timeout,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def resolved_admin_notification_root
      value = admin_notification_root
      value = value.call if value.respond_to?(:call)
      return value if defined?(RecordingStudio::Recording) && value.instance_of?(RecordingStudio::Recording)

      nil
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end

    def composer_actions
      @composer_actions ||= {}
    end

    def message_embeds
      @message_embeds ||= {}
    end

    private

    def assign_defaults
      @api_key = ENV.fetch("RECORDING_STUDIO_MESSAGES_API_KEY", nil)
      @enable_feature_x = false
      @timeout = 5
      @admin_notification_root = @layout = nil
      @public_contact_recipient_resolver = nil
      @public_contact_sent_icon = "rocket-launch"
      # Deprecated no-op. A verified public contact code always signs the visitor in.
      @public_contact_sign_in_after_verification = false
      @public_contact_success_redirect_url = @public_contact_success_redirect_label = nil
      @read_receipts = false
      @time_break_after = DEFAULT_TIME_BREAK_AFTER
    end

    def coerce_time_break_after(value)
      return DEFAULT_TIME_BREAK_AFTER if value.blank?
      return value if value.is_a?(ActiveSupport::Duration)

      value.to_i.minutes
    end
  end
end
