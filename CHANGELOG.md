# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-15

### Added

- LICENSE file (MIT)
- CHANGELOG.md following Keep a Changelog format
- CONTRIBUTING.md with contribution guidelines
- SECURITY.md with vulnerability reporting policy
- CODE_OF_CONDUCT.md (Contributor Covenant v2.1)
- SUPPORT.md with support channels
- Package.swift metadata comment block

### Changed

- Migrated API URLs to getfeedbackkit.com
- Standardized documentation across all FeedbackKit SDKs

## [1.0.0] - 2026-02-14

### Added

- Initial release of FeedbackKit Vapor SDK
- **SDK Operations** (X-API-Key authenticated)
  - Feedback: list, get, submit
  - Voting: vote and unvote
  - Comments: list and create
  - SDK user registration
  - Event tracking
- **Admin Operations** (Bearer token authenticated)
  - Authentication (register, login, token management)
  - Project management (CRUD, API keys)
  - Member and invite management
  - Dashboard and analytics
  - Feedback management with status updates
  - Subscription information
  - Integration management (Slack, GitHub, Notion, ClickUp, Linear, Monday.com, Trello, Airtable, Asana, Basecamp)
- Environment configuration (production, staging, local, custom)
- FeedbackKitError typed error handling
- Usage outside Vapor request context
- Swift 6.2 concurrency support
- macOS 13+ platform support

[1.1.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK/releases/tag/1.1.0
[1.0.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK/releases/tag/1.0.0
