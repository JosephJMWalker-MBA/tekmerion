# Changelog

## 0.0.1 (2026-08-04)

- Flutter environment established
- Android scaffold
- SHA-256 verified
- Managed evidence ingestion
- SQLite persistence
- 36 invariant tests passing
- Phase 1D: Import Agreement feature complete (Domain models, Repository, Import Service, HomeScreen UI)
- Integrated file_picker for PDF selection
- UI states implemented: Idle, Ingesting, Database saving, Success, Failure
- Phase 1E: Agreement Viewer and Manual Clause selection (AgreementViewerScreen, ManualClauseScreen, Clause domain and repository)
- Phase 1F: Obligation confirmation (Obligation Confirmation UI, Stepper flow, Obligation and ScheduleRule domain, SqliteObligationRepository, V3 migrations)
## [0.0.7] - 2026-08-04

### Added
- Phase 1G: Complete Obligation
- The user can select a confirmed obligation, upload evidence of completion (e.g., a receipt), and attach a note to finalize it into an immutable record.
- **Phase 1I**: Record Package Export
- Generate a self-contained ZIP archive with a cryptographic manifest, human-readable PDF, and original files.
- Added `CompleteObligationService` for securely drafting and finalizing completion records.
- Added `CompleteObligationScreen` for the user interface of completing an obligation.
- Added `ObligationsListScreen` to see a list of obligations (with fulfilled obligations sorted at the bottom).
- Updated `SqliteObligationRepository` to transition status to `fulfilled`.

## [0.0.6] - 2026-08-04

## [0.0.8] - 2026-08-04

### Added
- Phase 1H: Agreement Timeline
- Added `TimelineEvent` domain model and `TimelineRepository` to construct a chronologically ordered `UNION ALL` projection of all canonical events for an agreement.
- Implemented tie-breaking determinism by including `displayPriority` and canonical `id` in the sort order.
- Added `AgreementTimelineScreen` with timeline rendering, grouping events by Month and Year.
- Integrated the View Timeline action into the Agreement Home Screen.
- Extended the test suite, achieving 68 passing tests, with no analyzer warnings.


## [0.0.9] - 2026-08-05

### Added
- **Phase 1J-A & 1J-B: Deterministic Reminder Engine & Persistence**
- Implemented and tested: pure deterministic ReminderEngine
- Implemented and tested: ReminderInstance persistence
- Implemented and tested: non-destructive v4-to-v5 migration
- Implemented and tested: derived due status
- Implemented and tested: occurrence identity
- Implemented and tested: guarded state transitions
- Implemented and tested: notification-state separation
- Deferred: reconciliation, operating-system notification scheduling, Today and Upcoming UI, Android manual verification

- **Phase 1J-C: System Reconciliation & Notification Translation**
- Implemented and tested: Reconciliation algorithm to coalesce concurrency.
- Implemented and tested: Collision-resistant, deterministic 31-bit Android-safe notification ID generation derived from occurrence keys.
- Implemented and tested: Secure transaction boundaries over Reminder and Timeline domains.

- **Phase 1J-D: Today and Upcoming UI**
- Implemented and tested: `ReminderTemporalStatusResolver` to derive time-dependent statuses (`dueToday`, `overdue`, `upcoming`, etc.).
- Implemented and tested: `ReminderViewService` that projects `ReminderInstance` with domain facts (`Agreement`, `Obligation`, `Clause`) into `ReminderCardViewModel`.
- Implemented and tested: `TodayRemindersScreen` and `UpcomingRemindersScreen` providing filtered views.
- Implemented and tested: `ReminderCard` displaying contextual metadata and actionable intents.
- Implemented and tested: Record Package generation, cryptographic staging, human-readable PDF, schema validation.
- Implemented and tested: UI integration for triggering export, handling stream lifecycles, and invoking native share intents.
- Implemented and tested: Large-file benchmarking
- Operating Limit: Advisory warning only (macOS generation takes ~2.5s for 100MB, peak RSS ~380MB).
