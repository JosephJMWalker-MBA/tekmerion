import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/export/application/export_share_adapter.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';
import 'package:tekmerion/src/features/export/domain/export_package_repository.dart';
import 'package:tekmerion/src/features/timeline/application/agreement_timeline_service.dart';
import 'package:tekmerion/src/features/timeline/domain/timeline_event.dart';
import 'package:tekmerion/src/features/timeline/domain/timeline_repository.dart';
import 'package:tekmerion/src/features/timeline/presentation/agreement_timeline_screen.dart';

class MockTimelineRepository implements TimelineRepository {
  MockTimelineRepository({required this.mockEvents});
  final List<TimelineEvent> mockEvents;

  @override
  Future<List<TimelineEvent>> getTimelineForAgreement(
    String agreementId,
  ) async {
    return mockEvents;
  }
}

class FakeRecordPackageExportService implements RecordPackageExportService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExportPackageRepository implements ExportPackageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExportShareAdapter implements ExportShareAdapter {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now().toUtc();

  final agreement = Agreement(
    id: 'a1',
    title: 'Test Lease',
    agreementType: 'lease',
    status: AgreementStatus.active,
    createdAt: now.subtract(const Duration(days: 10)),
  );

  final events = [
    TimelineEvent(
      id: 'e1',
      agreementId: 'a1',
      eventType: TimelineEventType.recordFinalized,
      occurredAt: now,
      recordedAt: now,
      title: 'Record finalized',
      summary: 'Rent Paid',
      provenanceType: TimelineEventProvenance.system,
      sourceObjectType: 'RecordEntry',
      sourceObjectId: 'r1',
      integrityState: TimelineIntegrityState.verified,
    ),
    TimelineEvent(
      id: 'e2',
      agreementId: 'a1',
      eventType: TimelineEventType.clauseConfirmed,
      occurredAt: now.subtract(const Duration(days: 2)),
      recordedAt: now.subtract(const Duration(days: 2)),
      title: 'Clause confirmed',
      summary: 'Clause 1',
      provenanceType: TimelineEventProvenance.user,
      sourceObjectType: 'Clause',
      sourceObjectId: 'c1',
      integrityState: TimelineIntegrityState.verified,
    ),
  ];

  testWidgets(
      'AgreementTimelineScreen displays grouped events and newest first',
      (WidgetTester tester) async {
    final mockRepo = MockTimelineRepository(mockEvents: events);
    final timelineService =
        AgreementTimelineService(timelineRepository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: AgreementTimelineScreen(
          agreement: agreement,
          timelineService: timelineService,
          exportService: FakeRecordPackageExportService(),
          exportPackageRepository: FakeExportPackageRepository(),
          exportShareAdapter: FakeExportShareAdapter(),
        ),
      ),
    );

    // Wait for events to load
    await tester.pumpAndSettle();

    expect(find.text('Agreement Timeline'), findsOneWidget);

    // Check titles
    expect(find.text('Record finalized'), findsOneWidget);
    expect(find.text('Clause confirmed'), findsOneWidget);

    // Check grouping (today's date)
    final dateFormat = DateFormat('MMMM d, yyyy');
    expect(find.text(dateFormat.format(now)), findsOneWidget);
    expect(
      find.text(dateFormat.format(now.subtract(const Duration(days: 2)))),
      findsOneWidget,
    );

    // Check integrity indicator
    expect(find.byIcon(Icons.shield), findsWidgets);
  });

  testWidgets('AgreementTimelineScreen filters events',
      (WidgetTester tester) async {
    final mockRepo = MockTimelineRepository(mockEvents: events);
    final timelineService =
        AgreementTimelineService(timelineRepository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: AgreementTimelineScreen(
          agreement: agreement,
          timelineService: timelineService,
          exportService: FakeRecordPackageExportService(),
          exportPackageRepository: FakeExportPackageRepository(),
          exportShareAdapter: FakeExportShareAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial state: both visible
    expect(find.text('Record finalized'), findsOneWidget);
    expect(find.text('Clause confirmed'), findsOneWidget);

    // Open filter menu
    await tester.tap(find.byType(PopupMenuButton<TimelineFilter>));
    await tester.pumpAndSettle();

    // Select Clauses
    await tester.tap(find.text('Clauses'));
    await tester.pumpAndSettle();

    // Now only clause should be visible
    expect(find.text('Clause confirmed'), findsOneWidget);
    expect(find.text('Record finalized'), findsNothing);
  });

  testWidgets('AgreementTimelineScreen shows empty state',
      (WidgetTester tester) async {
    final mockRepo = MockTimelineRepository(mockEvents: []);
    final timelineService =
        AgreementTimelineService(timelineRepository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: AgreementTimelineScreen(
          agreement: agreement,
          timelineService: timelineService,
          exportService: FakeRecordPackageExportService(),
          exportPackageRepository: FakeExportPackageRepository(),
          exportShareAdapter: FakeExportShareAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No events have occurred yet.'), findsOneWidget);
  });
}
