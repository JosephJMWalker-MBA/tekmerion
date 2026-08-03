# Tekmerion Product Specification

## 1. Purpose

Tekmerion is a local-first lease stewardship application. It helps a tenant keep a signed lease present throughout the tenancy, confirm what the agreement requires, receive reminders, document performance or issues, attach evidence, and export a trustworthy contemporaneous record.

The primary user outcome is peace of mind.

## 2. Primary User

A residential tenant who wants to:

- understand and remember their obligations;
- document faithful performance;
- report issues clearly;
- preserve receipts, photos, notices, and communications;
- reduce anxiety about whether they have done what the lease requires.

The first release is tenant-centered but not anti-landlord. The product should also create cleaner communication and more reliable property records for responsible landlords.

## 3. Frozen Core Loop

```text
upload → confirm obligation → remind → document → link to clause → export
```

A feature belongs in v1 only when it is necessary to complete this loop reliably.

## 4. Core User Journey

### 4.1 Onboarding

The app explains:

- records remain local to the device by default;
- Tekmerion is not legal advice;
- machine extraction creates reviewable candidates, not final conclusions;
- the user controls final obligations and records.

### 4.2 Upload Agreement

The user imports a PDF or image-based lease.

The app:

- preserves the original file;
- calculates SHA-256;
- extracts text;
- records import timestamp and available metadata;
- creates an agreement version.

### 4.3 Parse Review

The parser proposes:

- parties;
- property address;
- effective dates;
- clause boundaries;
- obligation candidates;
- due dates;
- recurrence patterns;
- responsibility candidates.

Each candidate displays:

- exact source text;
- page and clause location;
- suggested structured values;
- confidence or ambiguity;
- Confirm, Correct, or Reject actions.

Nothing becomes a confirmed obligation without user action.

### 4.4 Agreement Overview

The agreement home presents:

- current agreement version;
- today and upcoming obligations;
- unresolved items;
- recent records;
- quick access to the source document;
- export and backup status.

Primary prompt:

> What does this agreement require now?

### 4.5 Reminder

A reminder is created only from confirmed structured data.

It includes:

- obligation title;
- responsible party;
- due date or recurrence;
- source clause reference;
- requested documentation type, when configured.

Reminder actions:

- Document completion
- Snooze
- Mark not applicable
- Open clause

### 4.6 Add Record

The user records performance, an observation, a communication, a payment, or an issue.

Required fields:

- record type;
- factual title or description;
- occurred-at date/time;
- linked agreement;
- linked obligation when applicable.

Optional fields:

- factual note;
- photo;
- video;
- receipt;
- document;
- location;
- communication metadata;
- status update.

The app separately stores `occurred_at` and `recorded_at`.

### 4.7 Finalize Record

Draft records may be edited.

Before finalization, the app shows a review screen containing:

- factual description;
- linked obligation and clause;
- evidence list;
- timestamps;
- status effect;
- warning that later corrections will be appended.

Final action label:

> Add to Record

After finalization:

- the record becomes immutable;
- evidence hashes are stored;
- corrections create linked records;
- the timeline updates deterministically.

### 4.8 Timeline

The timeline may be filtered by:

- obligation;
- record type;
- party;
- status;
- date range;
- unresolved items.

Each item shows:

- occurred-at and recorded-at values;
- record classification;
- source clause;
- evidence count;
- current status;
- correction links.

### 4.9 Export

The user can export:

- a human-readable PDF report;
- a ZIP package with originals and manifests;
- a CSV timeline and obligation register.

The export must clearly distinguish user entries, imported sources, extracted candidates, and confirmed structured data.

## 5. Frozen v1 Screens

1. Onboarding and privacy statement
2. Agreement upload
3. Parse review
4. Agreement overview
5. Obligation register
6. Today and upcoming reminders
7. Add record
8. Evidence capture and attachment
9. Finalize record review
10. Timeline
11. Agreement document and clause viewer
12. Export
13. Settings and backup

## 6. Record Types

- Firsthand observation
- Performance or completion
- Payment or transaction
- Communication sent
- Communication received
- Imported source document
- Another party's assertion
- User interpretation
- Resolution or outcome
- Correction

The UI must not imply that every record type has equal evidentiary weight.

## 7. Obligation Statuses

- Draft
- Confirmed
- Upcoming
- Due
- Fulfilled
- Reported
- Acknowledged
- Awaiting response
- Missed
- Disputed
- Not applicable
- Superseded

Tekmerion must not automatically assign legal conclusions such as breach, negligence, or illegality.

## 8. Parsing Requirements

### Included

- OCR for image-based pages
- document text normalization
- page-preserving text extraction
- clause segmentation
- date extraction
- recurrence extraction
- party and responsibility candidates
- obligation template matching
- confidence and ambiguity flags
- reproducible parse artifacts

### Human confirmation required

- whether a clause creates an obligation;
- who is responsible;
- due dates or recurrence when ambiguous;
- relationship between clauses and obligations;
- legal meaning.

## 9. Reminder Requirements

- Derived only from confirmed obligations
- Reproducible from stored rule data
- Local notifications for v1
- User-editable schedule
- Snooze and completion actions
- No cloud dependency
- No reminder silently deleted when an agreement version changes

## 10. Evidence Requirements

For every evidence asset, store when available:

- stable UUID;
- original filename;
- MIME type;
- byte size;
- SHA-256 hash;
- imported-at timestamp;
- source metadata;
- capture method;
- local storage reference;
- ownership and visibility fields;
- linked record entries.

The app must not claim that hashing proves authenticity, authorship, or admissibility.

## 11. Privacy and Backup

- No account required in v1
- App-private local storage
- Explicit export
- User-initiated backup and restore
- Optional device-level biometric gate may be considered only if it does not delay the core slice
- No analytics that expose agreement contents or evidence

## 12. Accessibility and Tone

Tekmerion should feel calm, factual, and non-accusatory.

Design principles:

- plain language;
- visible provenance;
- restrained status colors;
- dark mode support;
- readable document viewer;
- accessible text scaling;
- no fear-based legal marketing;
- no gamification of conflict.

## 13. Explicit Non-Goals

- Automatic legal interpretation
- Court outcome prediction
- Landlord or tenant reputation scores
- Public reviews
- Group chat
- Tenant coalition features
- Landlord portal
- Cloud synchronization
- Automatic email sending
- Certified notice or service
- Third-party trusted timestamping
- Jurisdiction-specific remedies

## 14. First Vertical Slice Acceptance Criteria

A user can:

1. create one agreement;
2. import one source document;
3. review one extracted clause;
4. confirm one obligation linked to that clause;
5. create one reminder from confirmed rule data;
6. respond to the reminder by adding one record;
7. attach one image or receipt;
8. finalize the record;
9. view it in the timeline;
10. export a PDF and evidence manifest.

The slice fails if:

- a candidate obligation becomes final without confirmation;
- the source clause cannot be traced;
- a finalized record can be silently edited;
- the export omits evidence identity or timestamps;
- the flow requires a backend.

## 15. Success Measure

The MVP succeeds when an ordinary tenant can use Tekmerion without legal expertise and can truthfully say:

> I know what I agreed to, I know what is due, and I no longer have to keep proving to myself that I handled it.
