# Tekmerion Domain Model

## Design Goals

The v1 model must support a private, local-first lease workflow while preserving a future path to communication bridges, shared property records, and consent-governed RecordSpaces.

The model must not assume:

- one agreement has only two parties;
- one property has only one agreement;
- one device owner owns every future record;
- all evidence shares one visibility scope;
- all communications are free-text notes;
- local identifiers can never synchronize later.

All primary entities use stable UUIDs.

## Core Entities

### Workspace

A local container for agreements and records.

Fields:

- `id`
- `name`
- `created_at`
- `updated_at`
- `owner_party_id`
- `archive_state`

v1 uses one default workspace. The entity exists to avoid hard-coding one global user-owned database.

### Subject

The real-world thing around which agreements may cluster.

Examples:

- property;
- apartment unit;
- service project;
- employment relationship.

Fields:

- `id`
- `subject_type`
- `display_name`
- `address`
- `metadata_json`

For v1, the principal subject is a rental property or unit.

### Party

A person or organization participating in an agreement.

Fields:

- `id`
- `party_type`
- `display_name`
- `contact_data`
- `is_local_user`
- `created_at`

### Agreement

The continuing relationship governed by one or more source documents.

Fields:

- `id`
- `workspace_id`
- `subject_id`
- `title`
- `agreement_type`
- `status`
- `start_date`
- `end_date`
- `lifecycle_stage`
- `governing_jurisdiction_text`
- `created_at`
- `archived_at`

Lifecycle stages:

- setup;
- move-in;
- active;
- renewal planning;
- termination planning;
- move-out;
- reconciliation;
- archived.

### AgreementParty

Joins parties to agreements with roles.

Fields:

- `id`
- `agreement_id`
- `party_id`
- `role`
- `effective_from`
- `effective_to`

Roles may include tenant, landlord, property manager, guarantor, occupant, or other.

### AgreementVersion

A preserved source version of the agreement.

Fields:

- `id`
- `agreement_id`
- `version_label`
- `effective_from`
- `effective_to`
- `source_evidence_asset_id`
- `status`
- `imported_at`
- `supersedes_version_id`

Statuses:

- draft;
- active;
- superseded;
- terminated.

### Clause

A page-preserving segment of an agreement version.

Fields:

- `id`
- `agreement_version_id`
- `parent_clause_id`
- `heading`
- `clause_number`
- `source_text`
- `normalized_text`
- `page_start`
- `page_end`
- `character_start`
- `character_end`
- `parse_confidence`
- `review_state`

### ObligationCandidate

Machine-extracted structured data awaiting confirmation.

Fields:

- `id`
- `clause_id`
- `candidate_type`
- `responsible_party_candidate_id`
- `benefited_party_candidate_id`
- `description_candidate`
- `due_date_candidate`
- `recurrence_candidate`
- `confidence`
- `ambiguity_flags`
- `parser_version`
- `created_at`
- `review_state`

Review states:

- pending;
- confirmed;
- corrected;
- rejected.

### Obligation

A user-confirmed responsibility linked to source provenance.

Fields:

- `id`
- `agreement_id`
- `source_clause_id`
- `source_type`
- `responsible_party_id`
- `benefited_party_id`
- `title`
- `description`
- `obligation_category`
- `schedule_rule_id`
- `status`
- `confirmed_at`
- `confirmed_by_party_id`
- `superseded_by_obligation_id`

Source types:

- contractual;
- statutory;
- user-entered;
- external-authority;
- inferred-but-confirmed.

### ScheduleRule

Deterministic reminder rule.

Fields:

- `id`
- `rule_type`
- `timezone`
- `start_at`
- `end_at`
- `recurrence_expression`
- `lead_time_seconds`
- `grace_period_seconds`
- `source_text`
- `confirmed_at`

The v1 implementation should store structured fields rather than opaque natural-language schedules.

### Reminder

A generated or manually created prompt tied to an obligation.

Fields:

- `id`
- `obligation_id`
- `scheduled_for`
- `state`
- `generated_from_rule_id`
- `created_at`
- `completed_by_record_entry_id`

States:

- scheduled;
- delivered;
- snoozed;
- completed;
- dismissed;
- not_applicable.

### RecordEntry

A user-created event or statement in the agreement record.

Fields:

- `id`
- `workspace_id`
- `agreement_id`
- `obligation_id`
- `record_type`
- `title`
- `factual_description`
- `interpretation_text`
- `occurred_at`
- `recorded_at`
- `timezone`
- `location_data`
- `state`
- `created_by_party_id`
- `corrects_record_entry_id`
- `finalized_at`
- `visibility_scope`

States:

- draft;
- finalized;
- corrected.

Finalized entries are immutable at the application layer.

Record types:

- firsthand_observation;
- performance;
- payment;
- communication_sent;
- communication_received;
- imported_source;
- other_party_assertion;
- user_interpretation;
- resolution;
- correction.

### EvidenceAsset

An original file or captured media object.

Fields:

- `id`
- `workspace_id`
- `owner_party_id`
- `original_filename`
- `mime_type`
- `byte_size`
- `sha256`
- `storage_uri`
- `capture_method`
- `source_metadata_json`
- `imported_at`
- `captured_at`
- `visibility_scope`
- `deletion_state`

### RecordEvidenceLink

Links evidence to records without forcing one evidence file to belong to only one event.

Fields:

- `id`
- `record_entry_id`
- `evidence_asset_id`
- `relationship_type`
- `caption`
- `display_order`

### CommunicationProtocol

Agreement-level communication expectations.

Fields:

- `id`
- `agreement_id`
- `primary_channel`
- `official_notice_address`
- `official_notice_email`
- `emergency_method`
- `expected_response_interval`
- `email_counts_as_written_notice`
- `formal_delivery_requirements_text`
- `confirmed_at`

### CommunicationThread

Deferred implementation, retained in the model direction.

Fields:

- `id`
- `agreement_id`
- `obligation_id`
- `subject`
- `created_at`

### CommunicationMessage

Deferred implementation.

Fields:

- `id`
- `thread_id`
- `record_entry_id`
- `author_party_id`
- `approved_content`
- `created_at`
- `approved_at`

### DeliveryAttempt

Deferred implementation for transport adapters.

Fields:

- `id`
- `message_id`
- `channel`
- `recipient`
- `sent_at`
- `delivery_state`
- `provider_metadata_json`

The state must not imply legal service or receipt unless verified.

### ExportPackage

A reproducible export event.

Fields:

- `id`
- `workspace_id`
- `agreement_id`
- `format`
- `generated_at`
- `filter_parameters_json`
- `manifest_sha256`
- `storage_uri`
- `generator_version`

## Visibility Scopes

The v1 UI uses only `private`, but the schema may support:

- `private`;
- `selected_parties`;
- `agreement`;
- `community`.

No future scope may be activated without explicit consent workflows.

## Key Relationships

```text
Workspace
  ├── Subject
  ├── Party
  ├── Agreement
  │     ├── AgreementParty
  │     ├── AgreementVersion
  │     │      └── Clause
  │     │             └── ObligationCandidate
  │     ├── Obligation
  │     │      ├── ScheduleRule
  │     │      ├── Reminder
  │     │      └── RecordEntry
  │     ├── CommunicationProtocol
  │     └── RecordEntry
  │            └── RecordEvidenceLink
  │                    └── EvidenceAsset
  └── ExportPackage
```

## Invariants

1. Every confirmed obligation has an agreement.
2. Every contractual obligation has a source clause unless the user explicitly records why provenance is unavailable.
3. Every clause belongs to an immutable agreement version.
4. Every reminder derived by the system references a confirmed schedule rule.
5. `recorded_at` is system-generated and never earlier than local creation.
6. `occurred_at` may differ from `recorded_at` and remains user-editable only before finalization.
7. Finalized records cannot be updated in place.
8. Corrections reference the record they correct.
9. Evidence hash is calculated at ingestion and never overwritten.
10. Deleting an agreement must not silently delete evidence shared with another retained record.
11. Export generation records the exact included filters and generator version.
12. Candidate extraction never becomes a confirmed obligation without human action.

## First Vertical Slice Entities

The initial implementation needs only:

- Workspace
- Subject
- Party
- Agreement
- AgreementParty
- AgreementVersion
- Clause
- ObligationCandidate
- Obligation
- ScheduleRule
- Reminder
- RecordEntry
- EvidenceAsset
- RecordEvidenceLink
- ExportPackage

Communication transport and shared community entities remain deferred.
