import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/core/database/app_database.dart';
import 'src/core/storage/local_evidence_storage.dart';
import 'src/features/agreement/application/agreement_import_service.dart';
import 'src/features/agreement/data/sqlite_agreement_repository.dart';
import 'src/features/agreement/presentation/file_picker_adapter.dart';

import 'src/features/clause/data/sqlite_clause_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final evidenceStorage = LocalEvidenceStorage(
    getRootDirectory: () => getApplicationDocumentsDirectory(),
  );

  final db = await AppDatabase.instance.database;
  final agreementRepository = SqliteAgreementRepository(db);
  final clauseRepository =
      SqliteClauseRepository((_) async => db, 'tekmerion.db');

  final importService = AgreementImportService(
    filePicker: FilePickerAdapter(),
    evidenceStorage: evidenceStorage,
    agreementRepository: agreementRepository,
  );

  runApp(TekmerionApp(
    importService: importService,
    clauseRepository: clauseRepository,
    evidenceStorage: evidenceStorage,
  ));
}
