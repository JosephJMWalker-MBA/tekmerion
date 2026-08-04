# 0008: pdfrx for Read-Only Document Viewing

## Date
2026-08-04

## Status
Accepted

## Context
Phase 1E of Tekmerion requires allowing the user to view a preserved agreement PDF and manually select a clause. 
The viewer must respect the core integrity boundaries: it must be completely read-only, must not manipulate or compress the original bytes, and must only render the exact managed asset associated with an Agreement Version.

Choosing a PDF rendering engine in Flutter involves weighing licensing, application size, performance, and maintenance.

### Alternatives Considered
- **Syncfusion Flutter PDFViewer**: Highly capable, but requires accepting either its Community License or a commercial license. Adding a proprietary licensing dependency for a relatively simple read-only viewer in a $4.99 proprietary application is unnecessary and adds legal risk.
- **pdfx**: Uses a similar PDFium backend but its development cadence and maintenance have been less consistent recently.

## Decision
We will use `pdfrx` as the preferred PDF viewer.

- **Package and Version**: `pdfrx` (v2.4.x)
- **Purpose**: Render exact managed originals securely within the app's UI to enable manual clause selection.
- **License**: MIT
- **Supported Platforms**: Android, iOS, web, macOS, Windows, Linux.
- **Maintenance**: Actively maintained and currently compatible with the installed Dart SDK (3.12.2) and Flutter version.
- **Android API Compatibility**: Compatible with the modern Android requirements of the project.
- **Application-size implications**: Bundles PDFium for rendering on some platforms, which will increase the APK/app bundle size. This is an acceptable tradeoff for native, high-quality, local PDF rendering without relying on external web services or system viewers that could compromise the integrity boundary.

### Integrity Constraints
The viewer is strictly a read-only projection of the preserved evidence asset.
- The viewer receives only the managed preserved original via `PdfViewer.file`.
- No editing, manipulation, rotation, compression, or page-deletion functionality is exposed.
- Tekmerion will perform a real-time SHA-256 verification of the file *before* initializing the viewer. If the hash does not match the database record, the viewer will be blocked with an integrity warning.

## Consequences
- **Positive**: We avoid complex licensing issues (Syncfusion) and gain a reliable, cross-platform, local PDF renderer.
- **Negative**: The app size increases due to the PDFium engine, but this is standard for robust local PDF support in Flutter.
