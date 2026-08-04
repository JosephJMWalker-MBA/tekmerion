# ADR 0004: Evidence Integrity and Tamper-Evident Records

- **Status:** Accepted for v1 foundation
- **Date:** 2026-08-03
- **Decision owners:** Tekmerion project

## Context

Tekmerion is intended to maintain a trustworthy contemporaneous record of agreement performance. Its value depends not only on organizing photos, receipts, documents, and statements, but also on preserving originals and detecting later mutation.

The application must make precise technical claims. Hashes and signatures can establish that stored bytes and finalized payloads have or have not changed since a controlled point in the Tekmerion workflow. They do not independently prove that an event occurred, that a scene was not staged, that a device clock was correct, that a user authored a statement, or that a court must admit the material.

## Decision

Tekmerion v1 will implement a local-first integrity envelope around evidence and finalized records.

### Evidence ingestion

For every evidence asset:

1. preserve the original bytes in app-private storage;
2. record whether the asset was captured in-app or externally imported;
3. compute SHA-256 immediately after durable storage;
4. record MIME type, byte size, original filename, ingestion time, available source metadata, and capture method;
5. never overwrite the stored hash;
6. treat previews, thumbnails, OCR renderings, annotations, crops, compressed copies, and redactions as separate derivative assets;
7. retain an explicit `derived_from_evidence_id` relationship for derivatives.

### In-app capture

For evidence captured through Tekmerion:

- save the original encoded output without in-place editing;
- record capture-start, capture-complete, ingestion, and finalization times separately when available;
- preserve available metadata without rewriting the original file;
- clearly label the evidence as `in_app_capture`.

Tekmerion may state that the preserved file is unchanged since capture into the Tekmerion workflow when verification succeeds.

### External import

For imported evidence:

- preserve the imported bytes exactly;
- label the asset `external_import`;
- state that pre-ingestion provenance is unknown;
- make no claim about editing or manipulation before import.

### Finalized record payload

When a user selects **Add to Record**, Tekmerion will canonicalize and hash a versioned payload containing at minimum:

- record ID;
- agreement and agreement-version IDs;
- obligation and source-clause provenance;
- record classification;
- factual description and separate interpretation text;
- occurred-at, recorded-at, timezone, and finalization timestamps;
- evidence IDs and SHA-256 values;
- correction linkage;
- schema version.

The canonical payload hash is stored as `record_hash`.

### Append-only chain

Each finalized record will participate in an agreement-scoped integrity chain:

```text
chain_hash = SHA-256(previous_chain_hash || record_hash || canonical_chain_metadata)
```

The chain is intended to detect mutation, substitution, or reordering of included entries. It does not prove that an omitted terminal segment never existed when only a partial package is available.

### Device signature

Where supported, Tekmerion will sign the finalized `chain_hash` using a non-exportable signing key managed through Android Keystore. The signature metadata will identify:

- algorithm;
- key identifier;
- public key or certificate information;
- signature bytes;
- verification state;
- whether hardware-backed protection or attestation was available.

Loss or invalidation of a signing key must not make evidence unreadable or prevent ordinary hash verification.

### Export verification

A Record Package will contain enough information for an independent verifier to check:

- evidence file hashes;
- finalized-record hashes;
- correction relationships;
- chain continuity for the included scope;
- available signatures;
- manifest integrity;
- missing or excluded material warnings.

Verification language must use precise states such as:

- `verified_unchanged_since_ingestion`;
- `signature_verified`;
- `chain_verified_for_included_scope`;
- `original_preserved`;
- `pre_ingestion_history_unknown`;
- `verification_failed`;
- `not_verifiable`.

Tekmerion will not display a generic `authentic` badge.

## Trusted time boundary

Device timestamps are useful metadata but are not independent proof of time. V1 will preserve nullable fields for a future trusted timestamp token without requiring network access:

- `trusted_timestamp_token`;
- `timestamp_authority`;
- `timestamp_verified_at`;
- `timestamp_verification_status`.

Any RFC 3161 or equivalent timestamp-authority integration requires a separate ADR.

## Product language

Recommended:

> Tekmerion preserves originals and produces tamper-evident records that can help establish integrity and provenance.

Not permitted without separate legal and technical validation:

- “Tekmerion makes evidence legally admissible.”
- “Tekmerion proves a photo is true.”
- “Tekmerion guarantees an image was never edited.”
- “Tekmerion creates self-authenticating evidence.”

## Required invariants

1. Evidence hashes are calculated from preserved original bytes and never overwritten.
2. Derivatives never replace originals.
3. Finalized records cannot be edited in place.
4. Corrections create new finalized records referencing prior records.
5. Canonicalization is versioned and reproducible.
6. One-byte mutation of an included file causes verification failure.
7. Reordering or substituting an included chain item causes chain verification failure.
8. Exports state whether they contain the complete agreement chain or a selected scope.
9. Hash verification remains possible without the original signing key.
10. Tekmerion distinguishes technical integrity from factual truth and legal admissibility.

## Consequences

### Positive

- stronger third-party presentation and authentication support;
- precise detection of post-ingestion mutation;
- original-source preservation consistent with Label Lens methodology;
- defensible product language;
- future compatibility with trusted timestamps and interoperable provenance standards.

### Negative

- canonicalization, key lifecycle, export verification, and derivative handling add implementation complexity;
- local device security cannot independently establish authorship, truthful timestamps, or event reality;
- partial exports require careful completeness warnings;
- signing-key loss and device migration need explicit recovery behavior.

## Deferred decisions

Separate ADRs are required before adding:

- trusted third-party timestamps;
- C2PA manifests;
- server-backed witnessing or notarization;
- certified delivery;
- jurisdiction-specific evidence certifications;
- claims of self-authentication or court readiness.
