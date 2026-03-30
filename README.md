# DocArmor

DocArmor is a privacy-first iOS document vault for storing personal IDs, insurance cards, travel documents, and other sensitive records on-device.

The app is built around a simple promise: your documents stay local, encrypted, and under your control. There is no backend, no account system, no analytics SDK, and no cloud sync requirement.

## What It Does

- Stores document pages encrypted on-device
- Locks access behind Face ID, Touch ID, or device passcode
- Organizes documents by type, category, and household member
- Tracks expirations and schedules local reminders
- Supports encrypted backup and restore
- Exposes quick-access and readiness widgets through a widget extension

## Security Model

- Document image data is encrypted at rest
- Vault keys are stored in the Apple Keychain
- SwiftData is configured for local-only storage
- Backup/export flows are designed around encrypted archives, not plaintext vault dumps
- The app does not make network calls as part of its document storage workflow

This repository is the open-source codebase for DocArmor. Anyone can inspect, build, audit, and contribute to the project source.

## Open Source and App Store Distribution

DocArmor is open source, but the App Store version is distributed as a signed, compiled binary built and released by Katafract LLC.

That means:

- This repository contains the source code
- The App Store version is the official compiled distribution
- App Store releases may include signing, provisioning, metadata, and release-process steps that do not live entirely in source control

If you want to run the app yourself, build it from this repository in Xcode with your own Apple signing setup.

## Requirements

- Xcode 26 or newer
- iOS 26.2 SDK / deployment target as currently configured in this repository
- An Apple Developer account if you want to run on physical devices or distribute builds

## Project Structure

- `DocArmor/` contains the main iOS app
- `DocArmorWidgetExtension/` contains the widget extension target
- `AppInfo.plist` contains the main app target plist configuration

## Privacy

Documentation links used by the app:

- App page: `https://katafract.com/apps/docarmor`
- Support: `https://katafract.com/support/docarmor`
- Privacy: `https://katafract.com/privacy/docarmor`
- Terms: `https://katafract.com/terms/docarmor`

## Project Policies

- Versioning policy: [`VERSIONING.md`](VERSIONING.md)
- Security architecture: [`SECURITY.md`](SECURITY.md)

## Status

DocArmor is under active development. Security-sensitive changes should be reviewed carefully, especially anything touching encryption, key handling, backup/restore, file import/export, or widget data sharing.
