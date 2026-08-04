# Tekmerion Development

## Current branch state

The `phase-1/bootstrap` branch contains the Flutter package metadata, application shell, initial record-domain prototype, and executable invariant tests.

The native Android and iOS project directories must be generated with the local Flutter SDK so the files match the installed stable toolchain.

From the repository root:

```bash
flutter create \
  --org com.aerialsoft \
  --platforms=android,ios \
  --project-name tekmerion \
  .
```

Review generated changes before committing. Preserve the existing `lib/`, `test/`, documentation, schemas, fixtures, proprietary license, and product specifications.

## Permanent identifiers

```text
Flutter organization:   com.aerialsoft
Dart package:           tekmerion
Android applicationId:  com.aerialsoft.tekmerion
iOS bundle identifier:  com.aerialsoft.tekmerion
Android minSdk:          24
```

After generation, explicitly confirm Android `minSdk` is 24. Do not rely on an implicit tool default.

## Required local checks

```bash
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## First implementation order

1. Generate native platform scaffolding.
2. Confirm identifiers and Android API 24 minimum.
3. Replace the in-memory repository only after its invariant tests pass.
4. Add SQLite migrations and managed app-private file storage.
5. Implement one agreement import path.
6. Drive one clause and obligation through manual confirmation.
7. Add one deterministic reminder.
8. Capture one original evidence asset and calculate SHA-256.
9. Finalize one append-only record.
10. Export one hash-verifiable Record Package.

## Architecture discipline

- The in-memory repository is a behavioral prototype, not production persistence.
- Production hashing must use a vetted SHA-256 implementation; test fakes must never appear as verification output.
- A parser candidate never becomes a confirmed obligation without explicit user action.
- Original files are preserved byte-for-byte. Previews and annotations are derivatives.
- Finalized records are corrected by appending a new record, never by overwriting.
- No backend or account may be introduced into the first vertical slice.
