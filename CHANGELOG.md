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
