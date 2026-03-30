# DocArmor Versioning Policy

DocArmor uses semantic versioning for releases and a monotonically increasing integer for build numbers.

## Release Version

Format:

`MAJOR.MINOR.PATCH`

Examples:

- `1.1.0`
- `1.1.1`
- `1.2.0`

Rules:

- Increment `PATCH` for bug fixes, warning cleanup, stability work, and minor polish that does not materially expand the product surface.
- Increment `MINOR` for meaningful user-facing feature additions that remain backward-compatible.
- Increment `MAJOR` only for substantial product shifts, breaking migrations, or major conceptual changes.

## Build Number

Xcode setting:

`CURRENT_PROJECT_VERSION`

Rules:

- Build numbers must always increase.
- Do not reuse a build number for the same marketing version.
- Use a single global build-number stream across the app and extensions.
- Increment the build number for every TestFlight or App Store upload.

## Current Baseline

Current release line:

- Marketing version: `1.1.0`
- Build number: `3`

## Recommended Usage

- Keep local development on the current marketing version until a release decision is made.
- Bump only the build number for internal distribution builds.
- Bump the marketing version when the release scope changes in a user-visible way.

Examples:

- Next internal/TestFlight build on the current release line: `1.1.0 (4)`
- Bug-fix follow-up release: `1.1.1`
- Next feature release after the current intake/import expansion: `1.2.0`

## Scope

This policy applies to:

- `DocArmor`
- `DocArmorWidgetExtension`
- `DocArmorShareExtension`

All targets should share the same marketing version and build number.
