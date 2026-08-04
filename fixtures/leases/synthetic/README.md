# Synthetic Lease Fixtures

These files are fictional test data created for Tekmerion development. They are not legal forms, legal advice, or recommended lease language.

## Fixture 001

`residential-lease-v1.txt` is the canonical source text for the first parser and vertical-slice fixture. It intentionally contains:

- two parties with distinct roles;
- one property and unit address;
- fixed start and end dates;
- monthly rent recurrence;
- a one-time move-in deadline;
- landlord and tenant maintenance obligations;
- written-notice and access clauses;
- a monthly smoke-detector check;
- communication-channel metadata;
- clauses that should not become automatic legal conclusions.

`residential-lease-v1.expected.json` records the human-authored ground truth. Parser output must remain separate from this file so tests can compare candidates against an independent expected result.

## Fixture policy

1. Fixtures committed to the public repository must be synthetic, public-domain, or otherwise licensed for this use.
2. Real leases must be redacted and kept outside the public repository unless explicit permission permits publication.
3. Ground truth is authored manually and versioned.
4. A parser regression must not rewrite expected results merely to make a failing test pass; changes require a documented correction to the fixture or specification.
5. Page coordinates and OCR artifacts will be added when PDF and image derivatives are generated.
