# ADR 0003: Minimum Supported Android Version

- **Status:** Accepted
- **Date:** 2026-08-03
- **Decision owners:** Tekmerion project

## Context

Tekmerion is intended to reduce anxiety for ordinary tenants, including people using older or lower-cost Android devices. Broad device access therefore matters. At the same time, the app depends on a currently supported Flutter runtime, on-device document processing, local notifications, secure app-private storage, camera/file access, and reliable export generation.

The current Flutter supported-platform matrix supports Android API levels 24 and later. Current ML Kit text recognition requires API level 23 or later, so it does not require raising the Flutter floor further.

## Decision

Tekmerion v1 will use:

```text
Minimum Android SDK: API 24
Minimum Android release: Android 7.0 (Nougat)
```

The target and compile SDK versions will follow current Google Play and Flutter requirements at build and release time, but the minimum supported version remains API 24 unless testing establishes a concrete incompatibility.

## Rationale

- Uses the lowest Android API level currently supported by Flutter.
- Preserves access for users with older devices rather than optimizing only for recent premium hardware.
- Supports the required OCR, reminder, evidence capture, local storage, and export capabilities.
- Avoids voluntarily excluding users who may benefit most from a low-cost peace-of-mind tool.
- Keeps the minimum-version decision grounded in supported tooling rather than arbitrary market positioning.

## Implementation Requirements

- Configure Android `minSdk` as `24`.
- Test the complete vertical slice on at least one API 24 emulator or physical device.
- Test notifications both below and above API 26 because notification channels were introduced in Android 8.0.
- Test storage, document import, camera capture, PDF generation, ZIP export, and restore behavior on the minimum API.
- Do not add a dependency that raises `minSdk` without recording the decision and its user-access impact.

## Consequences

### Positive

- Broad supported-device reach.
- Alignment with Tekmerion's accessibility and affordability goals.
- One explicit compatibility floor for plugin evaluation and CI.

### Negative

- Additional compatibility testing for older Android behavior.
- Some newer platform conveniences require conditional implementations.
- Low-end devices may need conservative OCR, image, and export resource limits.

## Revisit Criteria

Raise the minimum only if:

- Flutter drops support for API 24;
- a core, non-replaceable dependency requires a higher API;
- security or data-integrity testing reveals an unacceptable platform limitation; or
- reliable operation on API 24 cannot be achieved after reasonable optimization.

A higher minimum must be justified by a documented product requirement, not developer convenience alone.
