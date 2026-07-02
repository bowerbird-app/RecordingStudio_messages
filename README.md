# RecordingStudioMessages

RecordingStudioMessages is a Rails mountable engine that adds configurable, app-agnostic messaging to RecordingStudio apps.

## Dependencies

Add the gem and its required ecosystem dependencies:

```ruby
gem "recording_studio"
gem "recording_studio_accessible", ">= 0.4.1"
gem "flat_pack"
gem "recording_studio_messages"
```

`recording_studio_accessible >= 0.4.1` is required for optional custom action checks. The engine fails during load if the dependency is missing or too old.

## Install

```bash
bin/rails generate recording_studio_messages:install
bin/rails generate recording_studio_messages:migrations
bin/rails generate recording_studio_messages:container SiteMessages --root
bin/rails generate recording_studio_messages:container SupportMessages --parent-types Workspace
bin/rails db:migrate
```

Register all recordable types in the host app:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "SiteMessages",
    "SupportMessages",
    "RecordingStudioMessages::MessageGroup",
    "RecordingStudioMessages::Message"
  ]
end
```

Seed or create container recordings explicitly. The engine does not auto-create containers during requests.

## Configuration

```ruby
RecordingStudioMessages.configure do |config|
  config.current_actor = -> { Current.actor }
  config.layout = "application"

  config.messages :support_messages do |messages|
    messages.name = "Support messages"
    messages.container_type = "SupportMessages"
    # Default create authorization is explicit container access:
    # { type: :container_access, role: :edit }
  end

  config.messages :site_messages do |messages|
    messages.name = "Site messages"
    messages.container_type = "SiteMessages"
    messages.create_group_authorization = {
      type: :action,
      action: :"recording_studio_messages.create_group"
    }
  end
end
```

Use action authorization only for shared-root/private-child cases where broad `:edit` access on the root would expose other groups. Do not grant broad root access solely to allow private group creation.

Existing groups always use normal `RecordingStudioAccessible.authorized?` checks: `:view` to read, `:edit` to post, and `:admin` to manage participants.

## Recipients

Recipient search fails closed until the host app configures `recipient_actor_types`, `recipient_search`, and `recipient_allowed`. Submitted recipients are resolved only from allowlisted actor types, de-duplicated, capped, and revalidated before access is granted.

## UI

The engine renders a FlatPack single-panel chat UI:

- group index with bounded pagination
- new message screen with FlatPack composer
- thread screen with upward history pagination and composer when the actor has `:edit`

