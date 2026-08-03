# ADR 0001: Local-First Flutter Architecture

- **Status:** Accepted for v1 foundation
- **Date:** 2026-08-03
- **Decision owners:** Tekmerion project

## Context

Tekmerion v1 must support a private agreement record containing leases, extracted clauses, confirmed obligations, reminders, photos, receipts, documents, and append-only finalized entries.

The product is Android-first, but an iOS version is expected later. The user already has an Apple developer account but not yet a Google Play developer account. The first release should remain inexpensive to operate, compatible with a one-time purchase, and usable without an account or cloud dependency.

The app will contain sensitive personal records. Requiring a backend before the core workflow is proven would increase cost, privacy exposure, synchronization complexity, and deployment burden.

## Decision

Tekmerion v1 will use:

- Flutter for the mobile application;
- Android as the first publication target;
- SQLite for structured local data;
- app-private filesystem storage for original evidence;
- stable UUIDs for all primary entities;
- SHA-256 hashes for ingested evidence identity;
- local notifications for deterministic reminders;
- PDF, ZIP, and CSV generation on-device;
- explicit user-driven backup and restore;
- no required backend or user account.

## Rationale

### Flutter

Flutter provides one application codebase for Android-first delivery while preserving a practical path to iOS. Tekmerion is primarily document review, forms, reminders, media capture, timelines, and export—workflows that do not require a native-only architecture for v1.

### Local-first

Local-first storage supports the product’s privacy promise and avoids making the user trust an unproven cloud service with leases, addresses, payments, and evidence.

### No backend for v1

The frozen product loop does not require server coordination:

```text
upload → confirm obligation → remind → document → link to clause → export
```

A backend would be premature until communication bridges, synchronization, or shared RecordSpaces are deliberately introduced.

### Stable UUIDs and ownership fields

Although synchronization is deferred, local numeric IDs alone would make future migration unnecessarily expensive. Stable UUIDs, ownership, and visibility fields preserve optional future sync without implementing distributed-system complexity now.

## Parsing Architecture

Document processing must be modular and reproducible.

Proposed pipeline:

```text
source file
  → file validation and hashing
  → page extraction/rendering
  → embedded-text extraction
  → OCR fallback for image pages
  → normalized page text
  → clause segmentation
  → structured candidate extraction
  → human review
  → confirmed obligation rules
```

Each stage should preserve:

- input artifact identity;
- parser or ruleset version;
- structured output;
- warnings and confidence;
- page and character provenance;
- deterministic rerun capability where possible.

Confirmed reminders must never depend on an opaque model response at notification time.

## Persistence Boundaries

### SQLite

Stores:

- agreements and versions;
- parties and subjects;
- clauses and candidates;
- confirmed obligations;
- schedule rules and reminders;
- record metadata;
- evidence metadata and hashes;
- export manifests.

### App-private filesystem

Stores:

- original imported agreements;
- original evidence files;
- generated previews and thumbnails;
- export packages;
- backup artifacts.

Database rows reference files through managed storage identifiers rather than arbitrary external paths.

## Append-Only Rule

Draft records may be edited.

After `finalized_at` is set:

- the record is immutable through repository APIs;
- corrections create a new `RecordEntry` referencing the original;
- original evidence links remain preserved;
- timeline rendering may show the latest correction while retaining the full chain.

SQLite triggers may later reinforce invariants, but the first enforcement point is the domain repository layer with tests.

## Export Strategy

The first export package should contain:

```text
tekmerion-export/
  manifest.json
  report.pdf
  agreement/
    original-file
  evidence/
    original-files
  data/
    agreements.csv
    obligations.csv
    timeline.csv
    evidence-index.csv
```

The manifest records:

- export generation time;
- application and schema version;
- included agreement and record IDs;
- file paths and SHA-256 hashes;
- filters used;
- disclaimers.

## Consequences

### Positive

- strong privacy posture;
- no recurring server cost;
- suitable for one-time app pricing;
- usable offline;
- faster MVP iteration;
- later iOS path;
- data model prepared for future synchronization.

### Negative

- user is responsible for backup in v1;
- device loss can cause data loss without backup;
- no automatic cross-device access;
- OCR and export performance depend on device capability;
- future synchronization will require a deliberate migration and conflict model;
- Flutter plugins for document rendering, OCR, notifications, and media capture must be evaluated carefully.

## Deferred Decisions

Separate ADRs will be required before adding:

- cloud synchronization;
- identity and authentication;
- email or communication transport adapters;
- shared RecordSpaces;
- trusted third-party timestamping;
- platform-specific native services;
- jurisdictional rule packs.

## Revisit Criteria

Reconsider this decision only if testing shows that:

- required OCR cannot run acceptably on target Android devices;
- export generation is unreliable on-device;
- a mandatory product requirement genuinely needs a backend;
- Flutter blocks a core evidence or accessibility workflow;
- app-store constraints require a different distribution architecture.
