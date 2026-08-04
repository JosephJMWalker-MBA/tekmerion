import 'package:flutter/material.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/obligation/presentation/obligations_list_screen.dart';
import 'package:tekmerion/src/features/record/application/complete_obligation_service.dart';
import 'package:tekmerion/src/features/timeline/application/agreement_timeline_service.dart';
import 'package:tekmerion/src/features/timeline/presentation/agreement_timeline_screen.dart';

import '../application/agreement_import_service.dart';
import 'agreement_viewer_screen.dart';

enum ImportUiState {
  idle,
  selecting,
  ingesting,
  savingAgreement,
  completed,
  failed,
}

class AgreementHomeScreen extends StatefulWidget {
  const AgreementHomeScreen({
    super.key,
    required this.importService,
    required this.clauseRepository,
    required this.obligationRepository,
    required this.evidenceStorage,
    required this.completeObligationService,
    required this.timelineService,
  });

  final AgreementImportService importService;
  final ClauseRepository clauseRepository;
  final ObligationRepository obligationRepository;
  final EvidenceStorage evidenceStorage;
  final CompleteObligationService completeObligationService;
  final AgreementTimelineService timelineService;

  @override
  State<AgreementHomeScreen> createState() => _AgreementHomeScreenState();
}

class _AgreementHomeScreenState extends State<AgreementHomeScreen> {
  ImportUiState _state = ImportUiState.idle;
  ImportResult? _result;
  String? _errorMessage;

  Future<void> _handleImport() async {
    if (_state != ImportUiState.idle &&
        _state != ImportUiState.completed &&
        _state != ImportUiState.failed) {
      return; // Prevent concurrent imports
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await widget.importService.importLease(
        onStateChange: (stateName) {
          if (!mounted) return;
          setState(() {
            switch (stateName) {
              case 'selecting':
                _state = ImportUiState.selecting;
                break;
              case 'ingesting':
                _state = ImportUiState.ingesting;
                break;
              case 'savingAgreement':
                _state = ImportUiState.savingAgreement;
                break;
              case 'completed':
                _state = ImportUiState.completed;
                break;
            }
          });
        },
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _state = ImportUiState.idle;
        });
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = ImportUiState.failed;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tekmerion'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              'What does this agreement require now?',
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Upload the agreement once. Tekmerion helps you remember what it requires, document how you keep it, and preserve a trustworthy record.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            _buildStatusSection(textTheme),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: (_state == ImportUiState.idle ||
                      _state == ImportUiState.completed ||
                      _state == ImportUiState.failed)
                  ? _handleImport
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Import Lease'),
            ),
            const SizedBox(height: 12),
            Text(
              'Phase 1 bootstrap: this screen intentionally exposes the frozen loop before storage and import are connected.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(TextTheme textTheme) {
    switch (_state) {
      case ImportUiState.idle:
        return const Card(
          child: ListTile(
            leading: Icon(Icons.description),
            title: Text('Choose your signed lease'),
            subtitle: Text('Start by importing a PDF agreement.'),
          ),
        );
      case ImportUiState.selecting:
        return const Card(
          child: ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Selecting file...'),
          ),
        );
      case ImportUiState.ingesting:
      case ImportUiState.savingAgreement:
        return const Card(
          child: ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Preserving your original document...'),
          ),
        );
      case ImportUiState.failed:
        return Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: Icon(
              Icons.error,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            title: Text(
              'Import failed',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            subtitle: Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        );
      case ImportUiState.completed:
        if (_result == null) return const SizedBox.shrink();
        final evidence = _result!.evidence;
        final sizeKb = (evidence.byteSize / 1024).toStringAsFixed(1);
        final shortSha = evidence.sha256.substring(0, 12);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Your agreement is ready',
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  'Title: ${_result!.agreement.title}',
                  style: textTheme.bodyLarge,
                ),
                Text(
                  'File: ${evidence.originalFilename}',
                  style: textTheme.bodyMedium,
                ),
                Text('Size: $sizeKb KB', style: textTheme.bodyMedium),
                Text(
                  'Imported: ${_result!.agreement.createdAt.toLocal().toString().split('.').first}',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('Document Integrity', style: textTheme.titleSmall),
                Text('SHA-256: $shortSha...', style: textTheme.bodySmall),
                const Text(
                  'Status: Verified Original',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AgreementViewerScreen(
                          agreement: _result!.agreement,
                          version: _result!.version,
                          evidence: _result!.evidence,
                          storage: widget.evidenceStorage,
                          clauseRepository: widget.clauseRepository,
                          obligationRepository: widget.obligationRepository,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.file_open),
                  label: const Text('Open Document'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ObligationsListScreen(
                          agreement: _result!.agreement,
                          agreementVersionId: _result!.version.id,
                          obligationRepository: widget.obligationRepository,
                          completeObligationService:
                              widget.completeObligationService,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View Obligations'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AgreementTimelineScreen(
                          agreement: _result!.agreement,
                          timelineService: widget.timelineService,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('View Timeline'),
                ),
              ],
            ),
          ),
        );
    }
  }
}
