# frozen_string_literal: true

module RecordingStudioMessages
  module InboxCardRegistration
    def prepare(context, config)
      source = Services::InboxCard.build(**options_from(context, config))
      return ::RecordingStudioDashboard::Preparation.empty unless source.visible?

      ::RecordingStudioDashboard::Preparation.content(source)
    end

    def register_dashboard_widget!
      return unless defined?(::RecordingStudioDashboard)
      return if dashboard_widget_registered?

      ::RecordingStudioDashboard.register_widget(
        InboxCard::WIDGET_ID,
        component: self,
        default_span: 6,
        supported_spans: [6, 12],
        options: %i[title mine mount limit],
        empty: :hide
      )
    end

    private

    def options_from(context, config)
      options = config.to_h.transform_keys(&:to_sym)
      {
        actor: actor_from(context),
        title: options[:title],
        mine: options[:mine] == true,
        mount: resolve_mount(options[:mount], context),
        limit: options.fetch(:limit, Services::InboxCard::PREVIEW_LIMIT)
      }
    end

    def actor_from(context)
      return if context.nil?
      return context.actor if context.respond_to?(:actor)

      context
    end

    def resolve_mount(mount, context)
      return if mount.nil?
      return mount.call(context) if mount.is_a?(Proc)

      mount
    end

    def dashboard_widget_registered?
      ::RecordingStudioDashboard.registry.widget(InboxCard::WIDGET_ID)
      true
    rescue KeyError
      false
    end
  end
end
