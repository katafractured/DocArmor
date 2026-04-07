# DocArmor — Agent Instructions

## Project Purpose

iOS document vault app. Stores, encrypts, and organizes sensitive documents on-device. Features on-device OCR (no cloud), Siri integration, widgets, and a share extension for importing documents from other apps.

## Tech Stack

- Swift / SwiftUI
- SwiftData (local persistence)
- On-device encryption
- VisionKit / Vision framework (on-device OCR)
- App Intents / SiriKit
- WidgetKit (widget extension)
- Share Extension

## Targets

| Target | Bundle ID | Purpose |
|---|---|---|
| DocArmor | (main app) | Document vault |
| DocArmorShareExtension | (share ext) | Import docs from other apps |
| DocArmorWidgetExtension | (widget) | Home/lock screen widgets |

## Key Directories

```
DocArmor/           # Main app Swift source
DocArmorShareExtension/   # Share extension
DocArmorWidgetExtension/  # Widget extension
DocArmor.xcodeproj  # Xcode project
AppInfo.plist       # App metadata
PRODUCT_TODO.md     # Current known TODOs
ON_DEVICE_INTELLIGENCE_TODO.md  # On-device AI feature planning
```

## How to Build

```bash
xcodebuild -scheme DocArmor -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Architectural Patterns

- SwiftData as the primary persistence layer
- All document processing (OCR) runs on-device — no network calls for document analysis
- Encryption at the SwiftData / file level — documents encrypted at rest
- Share Extension communicates with main app via App Group shared container

## Constraints

- **Never send document content to a remote server** — on-device only is a core product promise
- On-device OCR only — do not add cloud OCR (Google Vision, AWS Textract, etc.)
- SwiftData schema changes require migration — handle carefully
- Share Extension and Widget Extension have memory limits — keep them lightweight
- Read `PRODUCT_TODO.md` and `ON_DEVICE_INTELLIGENCE_TODO.md` before adding features to understand current roadmap
