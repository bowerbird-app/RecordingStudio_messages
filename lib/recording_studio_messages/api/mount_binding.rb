# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module MountBinding
      module_function

      ACTOR_INBOX = :actor_inbox

      def wrap(mount)
        return ActorInbox.instance if actor_inbox_mount?(mount)

        wrap_center(mount)
      end

      def actor_inbox_mount?(mount)
        mount == ACTOR_INBOX || mount.to_s == ACTOR_INBOX.to_s
      end

      def wrap_center(mount)
        case mount
        when Proc then Singleton.new(resolver: mount)
        when Symbol, String then Singleton.new(key: mount.to_s)
        when Hash then Parent.new(mount)
        else
          raise configuration_error(
            "mount must be :actor_inbox, a proc, a message center key, or a parent recordable type and key"
          )
        end
      end

      def configuration_error(message)
        ::RecordingStudioApi::ConfigurationError.new(message)
      end

      class ActorInbox
        def self.instance
          @instance ||= new
        end

        def parent?
          false
        end

        def actor_inbox?
          true
        end

        def recordable_type
          nil
        end

        def resolve(_context = nil)
          nil
        end
      end

      class Singleton
        def initialize(resolver: nil, key: nil)
          @resolver = resolver
          @key = key.to_s
          raise MountBinding.configuration_error("mount key is required") if @resolver.nil? && @key.blank?
        end

        def parent?
          false
        end

        def actor_inbox?
          false
        end

        def recordable_type
          nil
        end

        def resolve(_context = nil)
          return @resolver.call if @resolver

          matches = recordings_for_key
          return matches.first if matches.one?
          return if matches.empty?

          raise RecordingStudioMessages::Error, "Mount key #{@key} matches #{matches.size} message centers"
        end

        private

        def recordings_for_key
          ids = RecordingStudioMessages::MessageMount.where(key: @key).pluck(:id)
          RecordingStudio::Recording.unscoped.kept.where(
            recordable_type: MESSAGE_MOUNT_TYPE,
            recordable_id: ids
          ).to_a
        end
      end

      class Parent
        attr_reader :recordable_type, :key

        def initialize(mount)
          values = mount.transform_keys(&:to_sym)
          raise MountBinding.configuration_error("mount parent uses recordable_type and key") if values.key?(:type)

          @recordable_type = values[:recordable_type].to_s
          @key = values[:key].to_s
          return if @recordable_type.present? && @key.present?

          raise MountBinding.configuration_error("mount parent needs recordable_type and key")
        end

        def parent?
          true
        end

        def actor_inbox?
          false
        end

        def resolve(context)
          parent = context.recording
          return if parent.blank? || parent.recordable_type != recordable_type

          parent.message_mount(key)
        end
      end
    end
  end
end
