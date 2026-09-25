# frozen_string_literal: true

module RecordingStudioMessages
  # Mount-level membership lock. When a Messages mount key is locked, Accessible
  # manage/grant/update/revoke for conversations under that mount is denied, and
  # the panel hides + Access / avatars. Trusted code paths call
  # +allow_membership_change+ (CreateGroup owner grant; Support sync_staff_grants).
  module MembershipLock
    THREAD_KEY = :recording_studio_messages_allow_membership_change

    module_function

    def membership_locked?(mount_recording)
      return false if mount_recording.blank?
      return false unless mount_recording.recordable_type == MESSAGE_MOUNT_TYPE

      key = mount_recording.recordable&.key
      parent = mount_recording.parent_recording
      return false if key.blank? || parent.blank?

      locked_keys_for(parent.recordable_type).include?(key.to_s)
    end

    def membership_locked_for_group?(group_recording)
      return false if group_recording.blank?
      return false unless group_recording.recordable_type == MESSAGE_GROUP_TYPE

      membership_locked?(group_recording.parent_recording)
    end

    def membership_management_blocked?(recording)
      return false if membership_change_allowed?
      return false unless recording&.recordable_type == MESSAGE_GROUP_TYPE

      membership_locked_for_group?(recording)
    end

    def allow_membership_change
      previous = Thread.current[THREAD_KEY]
      Thread.current[THREAD_KEY] = true
      yield
    ensure
      Thread.current[THREAD_KEY] = previous
    end

    def membership_change_allowed?
      Thread.current[THREAD_KEY] == true
    end

    def locked_keys_for(parent_type)
      options = RecordingStudio.capability_options(:messages, for: parent_type) || {}
      normalize_locked_keys(options[:membership_locked], mount_keys_from(options))
    end

    def install_authorizer_wrap!
      return unless defined?(RecordingStudioAccessible)

      config = RecordingStudioAccessible.configuration
      return if config.access_management_authorizer.equal?(@membership_lock_authorizer)

      @membership_lock_inner = config.access_management_authorizer
      @membership_lock_authorizer = membership_lock_authorizer_proc
      config.access_management_authorizer = @membership_lock_authorizer
    end

    def invoke_authorizer(callable, recording:, actor:, controller:)
      return false unless callable

      kwargs = { recording: recording, actor: actor, controller: controller }
      !!call_with_compatible_kwargs(callable, kwargs)
    rescue StandardError
      false
    end

    def call_with_compatible_kwargs(callable, kwargs)
      callable.call(**kwargs)
    rescue ArgumentError
      begin
        callable.call(recording: kwargs[:recording], actor: kwargs[:actor])
      rescue ArgumentError
        callable.call(recording: kwargs[:recording])
      end
    end

    def normalize_locked_keys(locked, mount_keys)
      return [] if locked.blank? || locked == false
      return mount_keys if locked == true

      Array(locked).map(&:to_s)
    end

    def mount_keys_from(options)
      Array(options[:keys] || options[:key]).map(&:to_s)
    end

    def membership_lock_authorizer_proc
      lambda do |recording:, actor: nil, controller: nil, **|
        next false if membership_management_blocked?(recording)

        invoke_authorizer(
          @membership_lock_inner,
          recording: recording,
          actor: actor,
          controller: controller
        )
      end
    end
  end
end
