# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-22

First version of Recording Studio Messages. The engine is renamed from the addon template. Family pins are real. Threads, groups, and screens are not in this slice.

### Added
- Engine identity `recording_studio_messages` / `RecordingStudioMessages`
- Gemspec pins: `recording_studio ~> 4.2`, `recording_studio_accessible ~> 0.7.0`, `recording_studio_attachable ~> 0.4`, `recording_studio_notifications ~> 0.2.5`, `flat_pack ~> 0.1.133`
- Dummy GitHub tags for the same family, plus Root Switchable `v0.5.0` for host chrome

### Changed
- Renamed the engine from the addon template to `recording_studio_messages`
- Dummy authenticated pages use Recording Studio's default layout chrome and load Flatpack CSS/JS (including `flat_pack/application` and Turbo)
- Configuration hooks come from `RecordingStudio::Hooks` in core

### Removed
- Leftover template identity in the public README and gemspec
- Dummy starter docs pages and custom `flat_pack_sidebar` shell
- Copied Hooks, BaseService, example service, and engine sample home controller
- Example engine pages migration

### Upgrade notes
- Point host and dummy Gemfiles at Recording Studio `v4.2.0`, Accessible `v0.7.0`, Attachable `0.4.0`, Notifications `v0.2.5`, and Flatpack `v0.1.133`
- Declare the gemspec constraints above. GitHub hosting is not a reason to skip them
- There is no `recording_studio_flatpack` gem; depend on `flat_pack`
- Do not add a Notifications → Messages edge
- Do not enable Message types in this slice

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.1.0
