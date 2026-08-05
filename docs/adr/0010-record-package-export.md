# 10. Record Package Export

Date: 2026-08-04

## Status

Accepted

## Context

Tekmerion requires a way to export a self-contained, human-readable, hash-verifiable Record Package for a single agreement. The export must be understandable without Tekmerion installed and help a neutral third party understand the relationship, obligations, timeline events, and supporting evidence. The package must serve as a neutral record, avoiding advocacy, liability assignment, or legal interpretation.

## Decisions

1. **Architecture and Scope**
   - The export is filesystem-based using a temporary staging directory to assemble the package before generating the final ZIP archive.
   - The export process performs a 16-step transaction: initializing, verifying sources, generating machine-readable data, copying original files, rendering a PDF, generating a verification report, hashing all components, writing the manifest, creating the ZIP, verifying the ZIP, persisting metadata, and cleanup.
   - The generation process acts entirely locally. We explicitly reject cloud uploads or automated email deliveries to preserve local-first integrity.

2. **Format and Completeness Semantics**
   - **Machine-Readable**: JSON is the authoritative format, strictly adhering to the `export-manifest.schema.json`.
   - **Human-Readable**: A structured PDF acts as a presentation artifact of the canonical facts. The PDF is *not* the authoritative record, but a visual aid designed to distinguish firsthand observations, performances, and third-party assertions clearly.
   - **Selective Disclosure**: Exports can optionally filter by date range, specific obligations, or omit specific evidence. Partial exports must fail-safe by explicitly stating they are incomplete, declaring what was omitted (via counts), and modifying chain verification semantics accordingly.
   - **Original Preservation**: The package includes all original agreement sources and evidence files. If an original agreement source file fails integrity verification prior to export, a complete export will "fail closed". Optional evidence that fails verification will also fail the export by default (strict policy for v1).

3. **Dependencies**
   - **`pdf`**: A pure Dart PDF generator. Chosen because Dart lacks native PDF rendering capabilities, and writing raw PDF structures is error-prone. Its Apache 2.0 license and active maintenance fit our project constraints.
   - **`archive`**: A pure Dart ZIP implementation used to package the staging directory. Chosen because `dart:io` lacks a full ZIP archiver.
   - **`share_plus`**: A platform channel plugin to invoke the Android/iOS native Save and Share intents. `dart:io` cannot invoke the Storage Access Framework (SAF) natively.

## Consequences

- The Record Package stands alone as a self-verifiable cryptographic bundle. 
- The inclusion of unmodified originals ensures neutral third-party verification is possible.
- Managing export metadata (`ExportPackageRepository`) requires appending to local state without overwriting prior exports, ensuring a verifiable history of data disclosure.



## Status Summary

**Implemented and Tested:**
- ExportService and DTOs mapping exactly to the schema.
- Strict file integrity and validation checks during staging.
- UI integration, generating streams, and sharing functionality via `share_plus`.

**Deferred:**
- Large-file benchmarking.
- Full Draft 2020-12 validator support.

**Known Limitations:**
- This package does not constitute legal admissibility or authenticity on its own.
- The resulting ZIP is a standard archive, not cryptographically immutable container format.