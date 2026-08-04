# 0006: SQLite Persistence

## Context

Tekmerion requires local, append-only persistence to maintain a trustworthy record of evidence, timeline events, and agreements without relying on a centralized cloud database for primary integrity.

While file storage was implemented in Phase 1B (via `path_provider`) for managing the bytes of the evidence assets, flat files lack the relational indexing and transactional atomicity needed for managing structured domain models (e.g., retrieving records chronologically, enforcing relationships between clauses and obligations, and atomically finalizing draft records).

## Decision

We will use SQLite as the primary structured storage mechanism, using the `sqflite` package.

### Dependency Details
- **Package**: `sqflite` (production) and `sqflite_common_ffi` (testing)
- **Purpose**: Local relational persistence for structured domain entities.
- **License**: MIT
- **Maintenance Status**: Actively maintained by flutter.dev (Flutter Community).
- **Android API 24 Compatibility**: `sqflite` utilizes `android.database.sqlite` natively, supporting API 21+ seamlessly.
- **Why plain Dart storage is insufficient**: Structured querying, indexing, and transactional ACID guarantees are necessary to ensure finalization never ends up in a partial state.

### Architecture Boundaries

1.  **Repository Contract**: The `RecordRepository` domain interface remains the sole boundary.
2.  **No Bytes in SQLite**: Raw evidence bytes remain in managed file storage (Phase 1B). SQLite only stores integrity metadata (digests, byte sizes, storage identifiers).
3.  **Strict Transactional Finalization**: `RecordRepository.finalize` must occur in a single database transaction. If the evidence cannot be cryptographically verified during finalization, the entire transaction must roll back, ensuring no partial finalization state can leak.
4.  **Schema and Migrations**: An explicit schema versioning and migration runner will be implemented. Schema Version 1 includes tables for agreements, versions, clauses, obligations, rules, reminders, records, and evidence links.

## Consequences

-   **Pros**: Real ACID compliance. Complex joins and indexed querying are fast. Easy to inspect offline with standard SQLite tools.
-   **Cons**: The schema adds boilerplate vs. NoSQL. Test environments on desktop/macOS must use `sqflite_common_ffi` rather than standard `sqflite`.
