# Project Management

## Working phases

Tekmerion uses phase-prefixed issue titles as the durable planning convention.

### Phase 0 — Foundation

Product policy, architecture decisions, schemas, fixtures, and implementation constraints. Exit when the first vertical slice can be built without unresolved product-policy decisions.

### Phase 1 — Vertical Slice

One complete offline path:

```text
upload → confirm obligation → remind → document → link to clause → export
```

### Phase 2 — Parsing Harness

Research-grade document processing, ground truth, stage artifacts, metrics, error taxonomy, and regression testing.

### Phase 3 — Tenant MVP

Complete Android product experience for ordinary lease stewardship.

### Phase 4 — Reliability and Release

Security, backup and restore, minimum-device testing, accessibility, store compliance, closed testing, and release operations.

## Label taxonomy

Use the repository's default GitHub labels where they accurately fit, especially:

- `documentation` — specifications, ADRs, research synthesis, and public explanations;
- `enhancement` — product or implementation capability;
- `bug` — behavior that violates a frozen requirement or executable invariant;
- `good first issue` — tightly scoped work with no unresolved product decision;
- `help wanted` — work for which outside implementation or specialist review is explicitly welcome;
- `question` — unresolved decision requiring an answer before implementation;
- `wontfix` — rejected scope that conflicts with the Constitution or product freeze.

Desired custom labels, to create in GitHub when repository administration permits:

- `phase:0-foundation`
- `phase:1-vertical-slice`
- `phase:2-parsing-harness`
- `phase:3-tenant-mvp`
- `phase:4-release`
- `area:agreement`
- `area:parser`
- `area:evidence-integrity`
- `area:reminders`
- `area:record`
- `area:export`
- `area:privacy`
- `decision-required`
- `deferred-horizon`
- `product-freeze`

## Milestone plan

Desired GitHub milestones:

1. `Phase 0 — Foundation`
2. `Phase 1 — First Vertical Slice`
3. `Phase 2 — Parsing Harness`
4. `Phase 3 — Tenant MVP`
5. `Phase 4 — Android Release`

Until those milestones are created in GitHub, phase-prefixed issue titles and this document are the source of truth.

## Issue discipline

- New ideas that do not complete the frozen v1 loop are documented as deferred issues.
- Product-policy decisions are recorded in ADRs or governing specifications, not left only in issue comments.
- A closed implementation issue must identify the test or acceptance criterion that demonstrates completion.
- A parser regression must preserve the failing artifact and must not be hidden by rewriting ground truth without review.
- Evidence-integrity defects are treated as release-blocking until explicitly reclassified.
