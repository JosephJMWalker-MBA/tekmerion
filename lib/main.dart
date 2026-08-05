import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tekmerion/src/core/integrity/sha256_integrity_engine.dart';
import 'package:tekmerion/src/features/export/application/export_share_adapter.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';
import 'package:tekmerion/src/features/export/application/record_pdf_generator.dart';
import 'package:tekmerion/src/features/export/data/sqlite_export_package_repository.dart';
import 'package:tekmerion/src/features/record/application/complete_obligation_service.dart';
import 'package:tekmerion/src/features/record/data/sqlite_record_repository.dart';
import 'package:tekmerion/src/features/timeline/application/agreement_timeline_service.dart';
import 'package:tekmerion/src/features/timeline/data/sqlite_timeline_repository.dart';

import 'src/app.dart';
import 'src/core/database/app_database.dart';
import 'src/core/storage/local_evidence_storage.dart';
import 'src/features/agreement/application/agreement_import_service.dart';
import 'src/features/agreement/data/sqlite_agreement_repository.dart';
import 'src/features/agreement/presentation/file_picker_adapter.dart';
import 'src/features/clause/data/sqlite_clause_repository.dart';
import 'src/features/obligation/data/sqlite_obligation_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final evidenceStorage = LocalEvidenceStorage(
    getRootDirectory: () => getApplicationDocumentsDirectory(),
  );

  final integrityEngine = Sha256IntegrityEngine();

  final db = await AppDatabase.instance.database;
  final agreementRepository = SqliteAgreementRepository(db);
  final clauseRepository =
      SqliteClauseRepository((_) async => db, 'tekmerion.db');
  final obligationRepository =
      SqliteObligationRepository((_) async => db, 'tekmerion.db');
  final recordRepository = SqliteRecordRepository(
    integrityEngine: integrityEngine,
    evidenceStorage: evidenceStorage,
  );

  final importService = AgreementImportService(
    filePicker: FilePickerAdapter(),
    evidenceStorage: evidenceStorage,
    agreementRepository: agreementRepository,
  );

  final completeObligationService = CompleteObligationService(
    filePicker: FilePickerAdapter(),
    evidenceStorage: evidenceStorage,
    recordRepository: recordRepository,
    obligationRepository: obligationRepository,
  );

  final timelineRepository = SqliteTimelineRepository(db);
  final timelineService = AgreementTimelineService(
    timelineRepository: timelineRepository,
  );

  final exportPackageRepository = SqliteExportPackageRepository(db);
  final exportShareAdapter = SharePlusExportAdapter();
  final exportService = RecordPackageExportService(
    agreementRepo: agreementRepository,
    clauseRepo: clauseRepository,
    obligationRepo: obligationRepository,
    recordRepo: recordRepository,
    timelineRepo: timelineRepository,
    evidenceStorage: evidenceStorage,
    exportRepo: exportPackageRepository,
    pdfGenerator: RecordPdfGenerator(),
  );

  runApp(
    TekmerionApp(
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
