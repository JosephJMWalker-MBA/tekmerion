import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_version.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';

import '../../clause/presentation/manual_clause_screen.dart';

enum ViewerUiState {
  verifying,
  loading,
  ready,
  integrityFailure,
  renderFailure,
}

class AgreementViewerScreen extends StatefulWidget {
  const AgreementViewerScreen({
    super.key,
    required this.agreement,
    required this.version,
    required this.evidence,
    required this.storage,
    required this.clauseRepository,
    required this.obligationRepository,
  });

  final Agreement agreement;
  final AgreementVersion version;
  final EvidenceEnvelope evidence;
  final EvidenceStorage storage;
  final ClauseRepository clauseRepository;
  final ObligationRepository obligationRepository;

  @override
  State<AgreementViewerScreen> createState() => _AgreementViewerScreenState();
}

class _AgreementViewerScreenState extends State<AgreementViewerScreen> {
  ViewerUiState _state = ViewerUiState.verifying;
  String? _localPath;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _verifyAndLoad();
  }

  Future<void> _verifyAndLoad() async {
    try {
      final verificationState = await widget.storage.verify(
        storageIdentifier: widget.evidence.storageIdentifier,
        expectedSha256: widget.evidence.sha256,
        expectedByteSize: widget.evidence.byteSize,
      );

      if (verificationState !=
          EvidenceVerificationState.verifiedUnchangedSinceIngestion) {
        if (mounted) {
          setState(() {
            _state = ViewerUiState.integrityFailure;
          });
        }
        return;
      }

      final path = await widget.storage
          .getLocalFilePath(widget.evidence.storageIdentifier);

      if (mounted) {
        setState(() {
          _localPath = path;
          _state = ViewerUiState.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = ViewerUiState.renderFailure;
        });
      }
    }
  }

  void _onAddClause() {
    if (_state != ViewerUiState.ready) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManualClauseScreen(
          agreement: widget.agreement,
          version: widget.version,
          pageStart: _currentPage,
          pageEnd: _currentPage,
          repository: widget.clauseRepository,
          obligationRepository: widget.obligationRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.agreement.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Version: ${widget.version.versionLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'File: ${widget.evidence.originalFilename}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_state == ViewerUiState.ready)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.green.shade900,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified unchanged since import into Tekmerion.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: _state == ViewerUiState.ready
          ? FloatingActionButton.extended(
              onPressed: _onAddClause,
              label: const Text('Add a clause'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewerUiState.verifying:
      case ViewerUiState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying integrity...'),
            ],
          ),
        );
      case ViewerUiState.integrityFailure:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Integrity Failure',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This document no longer matches the preserved record. Tekmerion will not use it for clause creation until the issue is resolved.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case ViewerUiState.renderFailure:
        return const Center(
          child: Text('Failed to load the document.'),
        );
      case ViewerUiState.ready:
        if (_localPath == null) return const SizedBox();
        return PdfViewer.file(
          _localPath!,
          params: PdfViewerParams(
            onViewerReady: (document, controller) {
              if (mounted) {
                setState(() {});
              }
            },
            onPageChanged: (pageNumber) {
              if (mounted) {
                setState(() {
                  _currentPage = pageNumber ?? 1;
                });
              }
            },
          ),
        );
    }
  }
}
