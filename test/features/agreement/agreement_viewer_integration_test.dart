import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_version.dart';
import 'package:tekmerion/src/features/agreement/presentation/agreement_viewer_screen.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/features/clause/presentation/manual_clause_screen.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';

import 'package:tekmerion/src/features/clause/domain/clause.dart';

class MockEvidenceStorage implements EvidenceStorage {
  EvidenceVerificationState verificationState =
      EvidenceVerificationState.verifiedUnchangedSinceIngestion;
  String returnedPath = '/fake/path.pdf';
  bool wasVerifyCalled = false;

  @override
  Future<void> deleteDraftAsset(String storageIdentifier) async {}

  @override
  Future<bool> exists(String storageIdentifier) async => true;

  @override
  Future<String> getLocalFilePath(String storageIdentifier) async =>
      returnedPath;

  @override
  Future<EvidenceEnvelope> ingestCapturedBytes(
          {required dynamic bytes,
          required String originalFilename,
          required String mimeType,
          String? derivedFromEvidenceId}) async =>
      throw UnimplementedError();

  @override
  Future<EvidenceEnvelope> ingestExternalFile(
          {required String sourceFilePath,
          required String originalFilename,
          required String mimeType,
          String? derivedFromEvidenceId}) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> openOriginalBytes(String storageIdentifier) async =>
      throw UnimplementedError();

  @override
  Future<EvidenceVerificationState> verify(
      {required String storageIdentifier,
      required String expectedSha256,
      required int expectedByteSize}) async {
    wasVerifyCalled = true;
    return verificationState;
  }
}

class MockClauseRepository implements ClauseRepository {
  List<Clause> createdDrafts = [];
  List<String> confirmedIds = [];

  @override
  Future<void> confirmClause(String clauseId) async {
    confirmedIds.add(clauseId);
  }

  @override
  Future<void> createDraftClause(Clause clause) async {
    createdDrafts.add(clause);
  }

  @override
  Future<Clause?> getClauseById(String id) async => null;

  @override
  Future<List<Clause>> getClausesForAgreementVersion(
          String agreementVersionId) async =>
      [];

  @override
  Future<void> updateDraftClause(Clause clause) async {}
}

void main() {
  final agreement = Agreement(
    id: 'a1',
    title: 'Test Lease',
    agreementType: 'lease',
    status: AgreementStatus.active,
    createdAt: DateTime.now(),
  );

  final version = AgreementVersion(
    id: 'v1',
    agreementId: 'a1',
    sourceEvidenceAssetId: 'e1',
    versionLabel: 'v1',
    status: AgreementVersionStatus.active,
    importedAt: DateTime.now(),
  );

  final evidence = EvidenceEnvelope(
    evidenceId: 'e1',
    originalFilename: 'doc.pdf',
    mimeType: 'pdf',
    byteSize: 100,
    sha256: 'abc',
    captureMethod: EvidenceCaptureMethod.inAppCapture,
    ingestedAt: DateTime.now(),
    storageIdentifier: 'm1',
    assetRole: EvidenceAssetRole.original,
  );

  testWidgets('Viewer blocks display if integrity fails', (tester) async {
    final mockStorage = MockEvidenceStorage();
    mockStorage.verificationState = EvidenceVerificationState.hashMismatch;
    final mockRepo = MockClauseRepository();

    await tester.pumpWidget(MaterialApp(
      home: AgreementViewerScreen(
        agreement: agreement,
        version: version,
        evidence: evidence,
        storage: mockStorage,
        clauseRepository: mockRepo,
      ),
    ));

    await tester.pumpAndSettle();

    expect(mockStorage.wasVerifyCalled, isTrue);
    expect(find.text('Integrity Failure'), findsOneWidget);
    expect(find.textContaining('will not use it for clause creation'),
        findsOneWidget);
    expect(find.text('Add a clause'), findsNothing);
  });

  testWidgets('Viewer allows adding clause if integrity passes',
      (tester) async {
    final mockStorage = MockEvidenceStorage();
    final mockRepo = MockClauseRepository();
    // We cannot render real pdfrx on headless tests without some setup, but we expect it to show Add a clause.

    await tester.pumpWidget(MaterialApp(
      home: AgreementViewerScreen(
        agreement: agreement,
        version: version,
        evidence: evidence,
        storage: mockStorage,
        clauseRepository: mockRepo,
      ),
    ));

    await tester.pumpAndSettle();

    expect(mockStorage.wasVerifyCalled, isTrue);
    expect(find.text('Verified unchanged since import into Tekmerion.'),
        findsOneWidget);
    expect(find.text('Add a clause'), findsOneWidget);
  });

  testWidgets('Manual Clause Screen creates and confirms clause exactly',
      (tester) async {
    final mockRepo = MockClauseRepository();

    await tester.pumpWidget(MaterialApp(
      home: ManualClauseScreen(
        agreementVersionId: 'v1',
        pageStart: 2,
        pageEnd: 2,
        repository: mockRepo,
      ),
    ));

    await tester.pumpAndSettle();

    // Verify initial values
    expect(find.text('2'), findsNWidgets(2)); // pageStart and pageEnd fields

    // Fill form
    await tester.enterText(
        find.byType(TextFormField).first, 'Exact text of clause');

    // Try to review
    await tester.tap(find.text('Review Clause'));
    await tester.pumpAndSettle();

    // Ensure we are in reviewing state
    expect(
        find.text(
            'Please review the clause carefully. Manual clauses must match the document precisely.'),
        findsOneWidget);

    // Save
    await tester.tap(find.text('Confirm & Save'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(mockRepo.createdDrafts, hasLength(1));
    expect(mockRepo.confirmedIds, hasLength(1));
    expect(mockRepo.createdDrafts.first.sourceText,
        equals('Exact text of clause'));
    expect(mockRepo.createdDrafts.first.pageStart, equals(2));
    expect(mockRepo.createdDrafts.first.reviewState,
        equals(ClauseReviewState.draft)); // Initial insertion
  });
}
