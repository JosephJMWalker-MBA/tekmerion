# 0009: Confirmed Obligation Immutability

## Status
Accepted

## Context
When a user extracts a structured requirement from a legal clause, they create an `Obligation`. During the drafting phase, the user is actively analyzing the clause and configuring the `Obligation` and its associated `ScheduleRule`. Once the user has defined the responsible party, what must be done, when it is due, and explicitly confirms the obligation, this entity represents a historical record of the user's understanding of the contract at that point in time. 

Allowing a confirmed obligation to be silently updated in-place destroys the audit trail. If an obligation's schedule, responsibility, or description changes after confirmation, we lose the ability to answer: "What did we believe the obligation was yesterday?" Furthermore, any reminders or records tied to the obligation's prior state become disconnected from the reality in which they were created.

## Decision
We will enforce immutability for confirmed obligations at the repository level.
1. **Draft State:** An obligation begins in the `draft` state. In this state, it can be updated and refined.
2. **Confirmation:** The user must explicitly confirm the obligation, setting its `status` to `confirmed` and populating `confirmedAt`.
3. **Immutability:** Once an obligation is confirmed (i.e. `status != draft`), the repository will reject any updates to the obligation or its associated `ScheduleRule`.
4. **Corrections & Superseding:** If a confirmed obligation needs to be changed (due to an error, amendment, or renegotiation), the system must not overwrite the existing record. Instead, the user must create a new obligation that supersedes the old one. The new obligation will populate its `supersededByObligationId` field on the old obligation (or the new obligation tracks what it supersedes, depending on the exact link direction, but in Phase 1F we simply defer editing of confirmed obligations entirely).

## Consequences
- **Auditability:** The system maintains a strict, append-only history of the user's interpretations.
- **Complexity:** The UI must clearly differentiate between drafting an obligation and amending a confirmed one. For Phase 1F, editing after confirmation is disabled entirely to enforce this boundary.
- **Database:** Repositories must actively check the existing state of an obligation before applying an `UPDATE` operation, throwing an exception if the obligation is not in a `draft` state.
