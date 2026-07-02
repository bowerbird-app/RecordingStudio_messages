> **Architecture Documentation**
> *   **Canonical Source:** [bowerbird-app/recording_studio_messages](https://github.com/bowerbird-app/recording_studio_messages/tree/main/docs/recording_studio_messages)
> *   **Last Updated:** May 5, 2026
>
> *Maintainers: Please update the date above when modifying this file.*

---

# RecordingStudioMessages Configuration

This document explains how to configure **RecordingStudioMessages** in your host Rails application.

---

## Quick Start

After installing the gem, run the install generator:

```bash
rails generate recording_studio_messages:install
```

This will:

1. Mount the engine in your routes (`/recording_studio_messages` by default).
2. Create `config/initializers/recording_studio_messages.rb` with example settings.
3. Optionally create `config/recording_studio_messages.yml` for environment-specific configuration.

---

## Configuration Options

| Option              | Type    | Default                          | Description                                 |
|---------------------|---------|----------------------------------|---------------------------------------------|
| `api_key`           | String  | `ENV["RECORDING_STUDIO_MESSAGES_API_KEY"]`    | API key for external service integration.  |
| `enable_feature_x`  | Boolean | `false`                          | Toggle optional feature X.                 |
| `timeout`           | Integer | `5`                              | Timeout (seconds) for external calls.      |

### RecordingStudio v3 Host-App Declarations

The dummy host app pins RecordingStudio to `recording_studio/v3.0.0` and keeps strict recordable declarations enabled:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = ["Workspace", "Folder", "Page"]
  config.require_recordable_declarations = true
end

class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
end

class Folder < ApplicationRecord
  recording_studio_recordable label: "Folder", root: false, allowed_parent_types: ["Workspace", "Folder"]
end
```

Use `RecordingStudio.validate_recordable_declarations!`, `RecordingStudio.root_recordable_types`, and
`RecordingStudio.allowed_parent_types_for("Page")` to verify the host app wiring.

---

## Configuration Methods

### 1. Ruby Initializer (Recommended)

Edit `config/initializers/recording_studio_messages.rb`:

```ruby
RecordingStudioMessages.configure do |config|
  config.api_key          = ENV["RECORDING_STUDIO_MESSAGES_API_KEY"]
  config.enable_feature_x = true
  config.timeout          = 10
end
```

This approach is flexible and allows dynamic values, environment variables, and Rails credentials.

### 2. YAML Configuration

If you prefer environment-specific static settings, create `config/recording_studio_messages.yml`:

```yaml
development:
  api_key: "dev-key"
  enable_feature_x: true
  timeout: 5

production:
  api_key: <%= ENV["RECORDING_STUDIO_MESSAGES_API_KEY"] %>
  enable_feature_x: false
  timeout: 5
```

The engine loads this file automatically via `Rails.application.config_for(:recording_studio_messages)`.

### 3. `config.x` Namespace

You can also set values in `config/application.rb` or environment files:

```ruby
# config/environments/production.rb
config.x.recording_studio_messages.api_key = ENV["RECORDING_STUDIO_MESSAGES_API_KEY"]
config.x.recording_studio_messages.timeout = 10
```

---

## Load Order & Precedence

Configuration is merged in the following order (later sources override earlier ones):

1. **Defaults** – defined in `RecordingStudioMessages::Configuration#initialize`.
2. **YAML** – `config/recording_studio_messages.yml` loaded via `config_for`.
3. **`config.x.recording_studio_messages`** – values set in Rails config files.
4. **Initializer** – `RecordingStudioMessages.configure` block in `config/initializers/recording_studio_messages.rb`.

> **Tip:** For most use cases, stick with the Ruby initializer and use environment variables for secrets.

---

## Accessing Configuration at Runtime

```ruby
RecordingStudioMessages.configuration.api_key
# => "your-api-key"

RecordingStudioMessages.configuration.enable_feature_x
# => true

RecordingStudioMessages.configuration.to_h
# => { api_key: "...", enable_feature_x: true, timeout: 5 }
```

You can access these values from anywhere in your application or from within the engine's controllers, models, and jobs.

---

## Secret Management

For sensitive values like `api_key`, we recommend:

- **Environment variables** – `ENV["RECORDING_STUDIO_MESSAGES_API_KEY"]`
- **Rails credentials** – `Rails.application.credentials.recording_studio_messages[:api_key]`

Avoid committing secrets to version control. The generator templates use `ENV` by default to encourage this practice.

---

## Extending Configuration

To add new options:

1. Add `attr_accessor` in `lib/recording_studio_messages/configuration.rb`.
2. Set a sensible default in `#initialize`.
3. Update `#to_h` if you want the option included in hash export.
4. Document the new option in this file and in the initializer template.

---

## Troubleshooting

| Issue                                  | Solution                                                                 |
|----------------------------------------|--------------------------------------------------------------------------|
| YAML not loading                       | Ensure `config/recording_studio_messages.yml` exists and has valid YAML syntax.       |
| Initializer values not applied         | Make sure the initializer runs after the engine initializer (default).   |
| `config.x` values ignored              | Verify you're setting them in the correct environment file.             |

---

## Files Reference

| File                                                        | Purpose                                      |
|-------------------------------------------------------------|----------------------------------------------|
| `lib/recording_studio_messages/configuration.rb`                         | Configuration class with defaults.           |
| `lib/recording_studio_messages/engine.rb`                                | Engine initializer that loads host config.   |
| `lib/generators/recording_studio_messages/install/install_generator.rb`  | Install generator that creates config files. |
| `lib/generators/recording_studio_messages/install/templates/`            | Templates for initializer and YAML files.    |

---

Happy configuring!
