# Tekmerion

**Peace and predictability through a trustworthy record.**

Tekmerion is a local-first lease stewardship application that keeps an agreement present throughout the life of a tenancy. A user uploads a signed lease, confirms the obligations it contains, receives reminders, documents performance or issues, links evidence to the governing clause, and exports a clear contemporaneous record.

Tekmerion is not primarily litigation software. Its first purpose is to reduce the anxiety of wondering whether obligations were remembered, fulfilled, reported, and documented.

## Product promise

> Upload the agreement once. Tekmerion helps you remember what it requires, document how you keep it, and preserve a trustworthy record so you can stop carrying the relationship in your head.

## Frozen v1 loop

```text
upload → confirm obligation → remind → document → link to clause → export
```

## v1 capabilities

- Import a signed lease as PDF or image
- Extract text and segment clauses
- Present obligation candidates for human review
- Preserve exact clause provenance
- Create deterministic reminders from confirmed dates and recurrence rules
- Capture photos, receipts, documents, and factual notes
- Finalize records into an append-only timeline
- Generate portable PDF, ZIP, and CSV exports
- Work without a cloud account or backend

## Product boundaries

Tekmerion v1 does not:

- provide legal advice;
- determine breach, liability, admissibility, or court outcomes;
- silently treat probabilistic extraction as authoritative;
- send communications automatically;
- expose records to landlords, tenants, or third parties without an explicit future sharing action;
- replace the user’s judgment when contract language is ambiguous.

## Technical direction

- Android-first
- Flutter codebase for a later iOS path
- Local-first SQLite database
- App-private evidence storage
- Stable UUIDs for future synchronization
- SHA-256 evidence hashes
- Reviewable and reproducible parsing output
- Append-only finalized records with linked corrections

## Repository status

The product is currently in **Phase 0: foundation and specification**. Implementation begins after the Constitution, product specification, domain model, architecture decision, and roadmap are complete enough that the first vertical slice can be built without unresolved product-policy decisions.

## First vertical slice

1. Create one agreement.
2. Store one source document.
3. Confirm one obligation linked to one clause.
4. Generate one reminder.
5. Finalize one record with one evidence file.
6. Export the resulting timeline and evidence index.

## Pricing principle

The spreadsheet/template version is free. The app is the paid automation layer.

## License

License not yet selected.
