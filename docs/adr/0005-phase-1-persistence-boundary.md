# ADR 0005: Phase 1 Persistence Boundary

- **Status:** Accepted
- **Date:** 2026-08-04
- **Decision owners:** Tekmerion project

## Context

Tekmerion v1 requires a local-first architecture (ADR 0001) and tamper-evident records (ADR 0004). The in-memory prototype has logically proven the integrity invariants, but moving toward a physical device requires a production-shaped persistence boundary.

The full domain model supports deferred functionality such as shared communities, communication transport, and cloud synchronization. However, implementing the full schema now would violate the product freeze and distract from proving the core vertical slice on-device.

We need to establish the abstract boundaries for database persistence, file storage, and cryptographic hashing while implementing only the subset of the schema required for the first vertical slice.

## Decision

We will implement a constrained Phase 1 persistence boundary using pure Dart interfaces:

1. **IntegrityEngine**: An interface abstracting hash chain calculation. Its implementation will use the maintained Dart `crypto` package to generate real SHA-256 digests.
2. **EvidenceStorage**: An interface managing app-private original assets, verifying their preserved bytes against stored hashes, and preventing replacement by derivatives.
3. **RecordRepository**: An interface defining operations to create, read, and finalize records, enforcing append-only mutation and appending corrections.
4. **Constrained Schema**: A minimal SQLite migration plan containing only the entities required for the core loop:
   - `agreements`
   - `agreement_versions`
   - `clauses`
   - `obligations`
   - `schedule_rules`
   - `reminders`
   - `record_entries`
   - `evidence_assets`
   - `record_evidence_links`
   - `export_packages`

## Rationale

- Defining interfaces before concrete SQLite or filesystem implementations allows testing domain logic and integrity without relying on Flutter plugin availability.
- A minimal schema ensures we only persist data necessary for the "upload → confirm obligation → remind → document → link to clause → export" loop.
- Using standard `crypto` for SHA-256 avoids opaque logic and meets the technical requirements of the integrity engine.

## Consequences

- The in-memory repository will adapt to implement `RecordRepository` and use the real `IntegrityEngine`, acting as the verified behavioral reference.
- Code can be authored independently of Flutter but remains unverified regarding device execution until Flutter toolchains are available to run `sqflite` and `path_provider`.

## Deferred

Implementation of full document OCR, Android Keystore signing, notifications, and PDF generation are explicitly deferred until the persistence boundary is established and testable.
