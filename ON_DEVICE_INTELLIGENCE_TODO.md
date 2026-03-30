# DocArmor On-Device Intelligence TODO

This file tracks the local-only intelligence roadmap for DocArmor. Every item in this plan must stay on-device and preserve the app's zero-network posture.

## Phase 1: OCR Foundation

- [x] Task 1: Expand local OCR suggestions
  - Status: Done
  - Goal: improve on-device OCR with issuer extraction, barcode-assisted document number detection, and stronger expiry parsing.

- [x] Task 2: OCR confidence and scan quality scoring
  - Status: Done
  - Goal: score scans for blur, low resolution, and text extraction confidence before suggesting fields.

- [x] Task 3: Document structure hints
  - Status: Done
  - Goal: detect likely front/back cards and missing reverse-side scans from local image and OCR cues.

## Phase 2: Structured Metadata

- [x] Task 4: Persist OCR-derived metadata
  - Status: Done
  - Goal: store normalized issuer, suffix, expiry, and extraction confidence for search and readiness.

- [x] Task 5: Barcode-first document parsing
  - Status: Done
  - Goal: promote barcode and machine-readable zone parsing for IDs and cards when available.

## Phase 3: Local Intelligence

- [x] Task 6: Natural language entity extraction
  - Status: Done
  - Goal: identify names, organizations, and cleanup tokens locally from OCR text.

- [x] Task 7: Better semantic local search
  - Status: Done
  - Goal: improve retrieval through richer on-device search terms and local NLP tagging.

## Phase 4: Apple Intelligence Enhancement

- [x] Task 8: Foundation Models availability layer
  - Status: Done
  - Goal: detect Apple Intelligence availability and add deterministic fallbacks before any model-assisted features.

- [x] Task 9: Guided generation for local field extraction
  - Status: Done
  - Goal: use the on-device Foundation Models framework to turn OCR text into structured document metadata when available.

- [x] Task 10: Local pack and readiness recommendations
  - Status: Done
  - Goal: generate smarter on-device suggestions for document packs, renewal prompts, and missing essentials.

## Phase 5: Intelligence UX

- [x] Task 11: Intelligence status visibility
  - Status: Done
  - Goal: surface whether Apple Intelligence is available or whether DocArmor is using deterministic local fallback logic.

- [x] Task 12: OCR suggestion source visibility
  - Status: Done
  - Goal: show whether document suggestions came from deterministic OCR heuristics or on-device model refinement.

- [x] Task 13: Shared recommendation engine surfaces
  - Status: Done
  - Goal: drive pack suggestions and readiness prompts from one local recommendation service instead of scattered UI heuristics.
