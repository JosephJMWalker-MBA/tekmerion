# Tekmerion Roadmap

## Guiding Rule

The v1 product is frozen around:

```text
upload → confirm obligation → remind → document → link to clause → export
```

New ideas are recorded, not added, unless they are necessary to complete this loop reliably.

## Phase 0 — Foundation

### Goal

Create enough product and architecture clarity that the first vertical slice can be implemented without unresolved policy decisions.

### Deliverables

- [x] README
- [x] Constitution
- [x] Product specification
- [x] Domain model
- [x] Local-first Flutter ADR
- [x] Evidence-integrity ADR
- [x] Roadmap
- [x] Define export manifest schema
- [x] Define parser-stage artifact schema
- [x] Define finalized-record correction behavior in testable terms
- [x] Choose Flutter package/application identifier (`com.aerialsoft.tekmerion`)
- [x] Choose license (proprietary; all rights reserved)
- [x] Define initial issue-label taxonomy and milestone plan
- [ ] Create custom labels and milestones in GitHub administration
- [x] Confirm minimum supported Android version (API 24 / Android 7.0)
- [x] Select and commit the first synthetic lease parser fixture

### Exit criteria

A developer can build the first vertical slice without making product-policy decisions.

## Phase 1 — Vertical Slice

### Goal

Prove the complete product loop with one agreement, one obligation, one reminder, one record, one evidence file, and one export.

### Scope

- Flutter project scaffold
- Local database schema and migrations
- App-private file repository
- Agreement creation
- PDF/image import
- SHA-256 hashing
- Basic text extraction
- Manual clause selection if automated segmentation is not ready
- One obligation confirmation flow
- One deterministic schedule rule
- **Phase 1J:** Reminder Engine
  - [x] pure deterministic ReminderEngine
  - [x] ReminderInstance persistence
  - [x] non-destructive v4-to-v5 migration
  - [x] derived due status
  - [x] occurrence identity
  - [x] guarded state transitions
  - [x] notification-state separation
  - [ ] reconciliation
  - [ ] operating-system notification scheduling
  - [ ] Today and Upcoming UI
  - [ ] Android manual verification
- Local notification
- Record drafting and finalization
- Photo or file attachment
- Timeline item
- PDF report and JSON/CSV manifest
- Unit and integration tests for append-only behavior

### Exit criteria

The first vertical slice passes the Product Specification acceptance criteria on a physical Android device.

## Phase 2 — Lease Parsing Harness

### Goal

Build a research-grade, reproducible parsing pipeline inspired by the Label Lens methodology.

### Scope

- Corpus of representative lease documents
- Embedded-text extraction
- OCR fallback
- Page image preservation
- Clause segmentation
- Party extraction candidates
- Date extraction
- Recurrence extraction
- Responsibility and obligation candidates
- Confidence and ambiguity queue
- Ground-truth annotation format
- Regression fixtures
- Parser versioning
- Stage-level metrics
- Error taxonomy

### Exit criteria

Parser quality is measurable, regressions are visible, and every confirmed obligation retains exact source provenance.

## Phase 3 — Tenant MVP

### Goal

Complete the frozen lease-stewardship experience for initial Android release.

### Scope

- Calm onboarding and privacy explanation
- Full agreement overview
- Obligation register
- Today and upcoming reminders
- Repeatable evidence capture
- Payment and receipt workflow
- Maintenance reporting records
- Communication sent/received records
- Move-in baseline workflow
- Move-out comparison workflow
- Agreement and clause viewer
- Timeline filters
- Full export package
- Backup and restore
- Dark mode and accessibility review
- Store listing assets and privacy disclosures

### Commercial model

- Free spreadsheet/template
- Paid app, initially targeted at a $4.99 one-time purchase
- No subscription dependency for core personal records

### Exit criteria

A tenant can use Tekmerion from lease upload through ordinary recurring stewardship without legal expertise or cloud registration.

## Phase 4 — Reliability and Release

### Goal

Prepare a trustworthy public release.

### Scope

- Threat model and privacy review
- Evidence-storage failure testing
- Backup/restore disaster tests
- Large-document performance testing
- Low-end Android device testing
- Parser fallback behavior
- Export validation
- Accessibility testing
- Crash reporting that excludes document contents
- App-store policy review
- Google Play developer registration and release track setup
- Closed testing
- Support and data-recovery documentation

## Deferred Horizon A — Communication Bridge

Tekmerion may become the structured interface through which a party composes and sends agreement-related communications.

Potential capabilities:

- compose from an obligation or record;
- attach only selected evidence;
- preserve exact approved content;
- send through email, share sheet, exported letter, or future portal adapters;
- track created, approved, sent, delivered, replied, and resolved without overstating legal service;
- link replies into the agreement timeline.

This horizon requires a separate ADR and privacy review.

## Deferred Horizon B — Shared Property RecordSpaces

Voluntary, consent-governed coordination for people who share a property or agreement environment.

Potential capabilities:

- verified membership;
- private records by default;
- granular sharing;
- independent attestations to a shared issue;
- collective factual requests;
- landlord or property-manager response;
- aggregate timeline without merging private files;
- consent grant and revocation events.

This must not become a rumor board, harassment tool, public rating system, or manufactured-consensus engine.

## Deferred Horizon C — Broader Agreements

After the lease workflow is proven, the same primitives may support:

- service contracts;
- construction projects;
- employment agreements;
- insurance obligations;
- vehicle transactions;
- HOA agreements;
- research collaborations.

Expansion should occur through templates and domain packs, not by weakening the agreement-centered model.

## Explicitly Deferred

- Conversational legal advice
- Automatic breach determination
- Court outcome prediction
- Public landlord or tenant scoring
- Automatic accusations
- Certified legal service
- Blockchain by default
- Mandatory cloud storage
- Social-feed behavior
- Advertising based on private agreement content

## Current Next Action

Create the GitHub custom labels and milestones when administrative tooling permits, then scaffold Flutter with `--org com.aerialsoft`, project name `tekmerion`, and Android `minSdk 24`.
