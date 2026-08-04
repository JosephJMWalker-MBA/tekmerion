import 'package:flutter/material.dart';
import 'features/agreement/presentation/agreement_home_screen.dart';
import 'features/agreement/application/agreement_import_service.dart';
import 'features/clause/domain/clause_repository.dart';
import 'core/storage/evidence_storage.dart';

class TekmerionApp extends StatelessWidget {
  const TekmerionApp({
    super.key,
    required this.importService,
    required this.clauseRepository,
    required this.evidenceStorage,
  });

  final AgreementImportService importService;
  final ClauseRepository clauseRepository;
  final EvidenceStorage evidenceStorage;

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
        evidenceStorage: evidenceStorage,
      ),
    );
  }
}
