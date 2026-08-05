# 0011. Deterministic Reminder Generation

Date: 2026-08-05

## Status

Accepted

## Context

Phase 1J introduces the deterministic Reminder Engine. Instead of allowing reminders to float independently of their source contracts, Tekmerion must generate reminder instances strictly from a user-confirmed `ScheduleRule`.

To preserve the append-only and deterministic nature of the application:
1. Re-running the generation logic on the same rule must not result in duplicate reminders.
2. Generating a recurring timeline for future occurrences must strictly follow timezone-aware semantics.
3. Overriding or changing a rule must create clearly distinguishable superseding occurrences.
4. An occurrence should remain permanently identifiable regardless of presentation timezones or subsequent data synchronization.

## Decision

We will adopt a pure, functional approach to reminder candidate generation.

1. **Generation Engine**: The `ReminderEngine` will be a pure domain service. It accepts a `ScheduleRule`, a window (start and end bounds), a clock, and a generation version. It outputs deterministic candidate `ReminderInstance` objects.
2. **Timezone Authority**: The `timezone` string on the `ScheduleRule` is the strict authority for local time matching (e.g. "always land on the 1st of the month at 9:00 AM local"). 
3. **UTC Storage**: All `dueAt` and `remindAt` properties of a generated instance are calculated once during generation and strictly stored as UTC instants (`DateTime` in UTC). Presentation layers will handle localization.
4. **Daylight Saving Edge Cases**: 
   - **Spring Forward (Nonexistent Time)**: If the local rule attempts to schedule a time that is skipped by DST, the engine fast-forwards to the start of the next valid hour.
   - **Fall Back (Ambiguous Time)**: If the local rule schedules a time that occurs twice, the engine picks the *first* (earlier) occurrence.
5. **Deterministic Keys**: Each occurrence is uniquely identified by an `occurrenceKey`. 
   `occurrenceKey = sha256(scheduleRuleId + "|" + dueAt.toIso8601String() + "|" + generationVersion)`
   This ensures idempotency in the persistence layer.

## Consequences

- **Positive**: We can re-evaluate rules safely at startup without duplicating reminders. Generating massive futures is safe because it maps uniquely.
- **Positive**: We strictly avoid the classic bug of shifting reminders due to device timezone changes, as the original timezone is locked into the calculation.
- **Negative**: The engine requires a robust timezone database (IANA), meaning we must bundle `timezone` data with the app to handle historic and future DST rules accurately.

## Persistence and State Transitions

6. **Notification Delivery Separation**: The logical state of a reminder (`scheduled`, `completed`, `cancelled`) is completely decoupled from its OS notification delivery state (`NotificationSchedulingState`). This prevents notification failures or missing permissions from corrupting the legal workflow state.
7. **Strict Terminal Timestamps**: State transitions to terminal states (`acknowledged`, `dismissed`, `completed`, `cancelled`, `superseded`, `expired`) must record a specific terminal timestamp corresponding to the exact transition moment.
8. **One-Way Transitions**: A reminder that has entered a terminal state may never return to an active state (`scheduled` or `due`).
9. **Atomic Updates**: Database state transitions are performed via single atomic `UPDATE` statements that require the current state to match expectations (`expectedCurrentState`), preventing race conditions.
10. **Idempotent Insertions**: Persistence relies on the unique constraint `(schedule_rule_id, occurrence_key)`. Insertions use `ConflictAlgorithm.ignore` to safely handle redundant generations.

## Phase 1J Status

**Implemented and tested (1J-A & 1J-B):**
- pure deterministic ReminderEngine
- ReminderInstance persistence
- non-destructive v4-to-v5 migration
- derived due status
- occurrence identity
- guarded state transitions
- notification-state separation

**Implemented and tested (1J-C):**
- pure `ReminderReconciliationPlanner`
- collision-resilient `NotificationIdGenerator`
- `ReminderReconciliationService` with single-flight coalescing concurrency
- atomic canonical transaction execution of `ReconciliationPlan`
- structured `LocalNotificationAdapter` boundary

**Deferred:**
- actual operating-system notification plugin (e.g. `flutter_local_notifications`)
- Today and Upcoming UI
- Android manual verification
