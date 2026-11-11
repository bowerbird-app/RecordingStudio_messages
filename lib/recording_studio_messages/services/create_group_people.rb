# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class CreateGroupPeople
      def initialize(mount:, actor:, admin:, members:)
        @mount = mount
        @actor = actor
        @admin = admin
        @members = members
      end

      def grant!(group_recording)
        RecordingStudioMessages.allow_membership_change do
          grant_owner!(group_recording)
          grant_edits!(group_recording) if @members
        end
      end

      private

      def grant_owner!(group_recording)
        return unless defined?(RecordingStudioAccessible)
        return if MountAccess.inherited?(@mount)

        result = grant_role!(group_recording, owner, :admin)
        return if result.success?

        raise RecordingStudioMessages::Error, result.error
      end

      def grant_edits!(group_recording)
        manager = manager_for(group_recording)
        raise RecordingStudioMessages::Error, Copy.t("errors.cannot_start") if manager.blank?

        granted = []
        ([@actor] + @members).each do |person|
          next if skip_edit?(person, granted)

          result = grant_role!(group_recording, person, :edit, manager: manager)
          raise RecordingStudioMessages::Error, result.error unless result.success?

          granted << Contacts.identity(person)
        end
      end

      def skip_edit?(person, granted)
        return true if person.blank?
        return true if Contacts.identity(person) == Contacts.identity(owner) && MountAccess.members?(@mount)

        granted.include?(Contacts.identity(person))
      end

      def grant_role!(group_recording, actor, role, manager: @actor)
        RecordingStudioAccessible.grant_access(
          recording: group_recording,
          actor: actor,
          role: role,
          manager_actor: manager
        )
      end

      def owner
        return @actor if MountAccess.inherited?(@mount)

        @admin.presence || @actor
      end

      def manager_for(group_recording)
        return @actor if admin_on?(@actor, group_recording)

        ancestor = group_recording
        while ancestor
          holder = admin_holder_on(ancestor, group_recording)
          return holder if holder

          ancestor = ancestor.parent_recording
        end
        nil
      end

      def admin_holder_on(recording, group)
        RecordingStudioAccessible.access_recordings_for(recording).each do |access_recording|
          actor = access_recording.recordable&.actor
          return actor if actor.present? && admin_on?(actor, group)
        end
        nil
      end

      def admin_on?(actor, recording)
        RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :admin)
      end
    end
  end
end
