import 'package:flutter/material.dart';

import 'core/storage/evidence_storage.dart';
import 'features/agreement/application/agreement_import_service.dart';
import 'features/agreement/presentation/agreement_home_screen.dart';
import 'features/clause/domain/clause_repository.dart';
import 'features/export/application/export_share_adapter.dart';
import 'features/export/application/record_package_export_service.dart';
import 'features/export/domain/export_package_repository.dart';
import 'features/obligation/domain/obligation_repository.dart';
import 'features/record/application/complete_obligation_service.dart';
import 'features/timeline/application/agreement_timeline_service.dart';

class TekmerionApp extends StatelessWidget {
  const TekmerionApp({
    super.key,
    required this.importService,
    required this.clauseRepository,
    required this.obligationRepository,
    required this.evidenceStorage,
    required this.completeObligationService,
    required this.timelineService,
    required this.exportService,
    required this.exportPackageRepository,
    required this.exportShareAdapter,
  });

  final AgreementImportService importService;
  final ClauseRepository clauseRepository;
  final ObligationRepository obligationRepository;
  final EvidenceStorage evidenceStorage;
  final CompleteObligationService completeObligationService;
  final AgreementTimelineService timelineService;
  final RecordPackageExportService exportService;
  final ExportPackageRepository exportPackageRepository;
  final ExportShareAdapter exportShareAdapter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tekmerion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF355C4D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8CB8A3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: AgreementHomeScreen(
        importService: importService,
        clauseRepository: clauseRepository,
        obligationRepository: obligationRepository,
        evidenceStorage: evidenceStorage,
        completeObligationService: completeObligationService,
        timelineService: timelineService,
        exportService: exportService,
        exportPackageRepository: exportPackageRepository,
        exportShareAdapter: exportShareAdapter,
      ),
    );
  }
}
