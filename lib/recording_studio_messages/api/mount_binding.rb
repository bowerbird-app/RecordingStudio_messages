# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module MountBinding
      module_function

      def wrap(mount)
        case mount
        when Proc
          Singleton.new(resolver: mount)
        when Symbol, String
          Singleton.new(key: mount.to_s)
        when Hash
          Parent.new(mount)
        else
          raise configuration_error("mount must be a proc, a message center key, or a parent recordable type and key")
        end
      end

      def configuration_error(message)
        ::RecordingStudioApi::ConfigurationError.new(message)
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

      class None
        def parent?
          false
        end

        def recordable_type
          nil
        end

        def resolve(_context = nil)
          nil
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

        def resolve(context)
          parent = context.recording
          return if parent.blank? || parent.recordable_type != recordable_type

          parent.message_mount(key)
        end
      end
    end
  end
end
