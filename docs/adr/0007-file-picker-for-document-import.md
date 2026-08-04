# 7. File Picker for Document Import

Date: 2026-08-04

## Status

Accepted

## Context

Tekmerion requires a way for users to import signed PDF agreements into the application's trustworthy storage boundary. We need a solution that:

1. Allows users to select PDF files from their local device storage or cloud providers (e.g., Google Drive, iCloud).
2. Preserves the original file bytes without mutation during the selection process.
3. Does not require broad, preemptive storage permissions (like `READ_EXTERNAL_STORAGE` or `READ_MEDIA_DOCUMENTS` on Android) which degrade trust and complicate review.
4. Supports Android API 24+ (our minimum version).

## Decision

We will use the [`file_picker`](https://pub.dev/packages/file_picker) package for document selection.

### Justification

1. **Native Integration & Permissions**: `file_picker` uses the native Storage Access Framework (SAF) document picker on Android and `UIDocumentPickerViewController` on iOS. This delegates file selection to the OS, allowing the user to grant access to a specific file without requiring broad app-wide storage permissions.
2. **Filtering**: It natively supports filtering by extension (e.g., `.pdf`), improving the UX.
3. **Maturity & License**: The package is highly maintained, widely used in the Flutter ecosystem, and licensed under the MIT License.
4. **API Compatibility**: It fully supports Android API 24+ and seamlessly handles modern scoped storage limitations without forcing legacy permission requests.

## Consequences

- We can proceed with Phase 1D (Import Agreement) without adding invasive permissions to `AndroidManifest.xml`.
- If a future requirement demands bulk ingestion or background scanning (which is against current design goals anyway), this SAF-based approach would be insufficient and require re-evaluation.
- We must handle edge cases gracefully: the user canceling the picker, zero-byte files, and non-PDF selections.
