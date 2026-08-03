# ADR 0002: Publisher Identity and App Identifiers

- **Status:** Accepted
- **Date:** 2026-08-03
- **Decision owners:** Tekmerion project

## Context

Aerial-Soft was used as the publisher identity for the prior App Store release, Big Joke. Tekmerion is Android-first but is being built in Flutter with a later iOS release path. The application identifier should therefore be stable, conventional, and usable across both ecosystems.

The prior Apple bundle identifier used the form `Aerial-Soft.Big-Joke`. Apple permits hyphens in bundle identifiers, but Android application IDs use Java/Kotlin-style package naming. A shared reverse-DNS identifier avoids separate naming conventions and reduces future configuration mistakes.

## Decision

Aerial-Soft is the permanent publisher identity for Tekmerion and the default publisher identity for future apps unless a later project has a documented reason to use another entity.

Tekmerion will use:

```text
Publisher display identity: Aerial-Soft
Android applicationId:      com.aerialsoft.tekmerion
iOS bundle identifier:      com.aerialsoft.tekmerion
Flutter organization value: com.aerialsoft
Dart package name:           tekmerion
Suggested App Store SKU:     TEKMERION-IOS-001
```

## Rationale

- Preserves continuity with the existing Aerial-Soft publishing history.
- Uses one immutable identifier across Android and iOS.
- Follows conventional reverse-DNS naming.
- Avoids hyphens and capitalization differences that are unsuitable for Android package-style identifiers.
- Keeps the customer-facing publisher identity independent from the technical identifier format.

## Consequences

- Flutter scaffolding must be generated with `--org com.aerialsoft` and project name `tekmerion`.
- Android manifests, Gradle configuration, signing records, store listings, notification channels, deep links, and backup configuration must use `com.aerialsoft.tekmerion` where an application identifier is required.
- Xcode and App Store Connect must use the exact iOS bundle identifier `com.aerialsoft.tekmerion`.
- Once either store receives a production build under this identifier, it must be treated as permanent.

## Non-Decision

This ADR does not determine the legal ownership structure, trademark status, public developer account name, support URL, privacy-policy domain, or whether Aerial-Soft should later be incorporated. Those questions are separate from the technical publisher namespace.
