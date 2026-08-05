import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tekmerion/src/features/export/application/export_share_adapter.dart';
import 'package:tekmerion/src/features/export/domain/export_package.dart';
import 'package:tekmerion/src/features/export/domain/export_package_repository.dart';

import '../application/export_state.dart';
import '../application/record_package_export_service.dart';

class RecordPackageExportScreen extends StatefulWidget {
  const RecordPackageExportScreen({
    super.key,
    required this.agreementId,
    this.agreementTitle,
    required this.exportService,
    required this.exportPackageRepository,
    required this.exportShareAdapter,
  });

  final String agreementId;
  final String? agreementTitle;
  final RecordPackageExportService exportService;
  final ExportPackageRepository exportPackageRepository;
  final ExportShareAdapter exportShareAdapter;

  @override
  State<RecordPackageExportScreen> createState() =>
      _RecordPackageExportScreenState();
}

class _RecordPackageExportScreenState extends State<RecordPackageExportScreen> {
  ExportStatus _status = const ExportStatus();
  bool _isGenerating = false;
  String? _shareErrorMessage;
  ExportPackage? _latestPriorExport;
  bool _isLoadingPrior = true;
  StreamSubscription<ExportStatus>? _exportSubscription;

  @override
  void initState() {
    super.initState();
    _loadPriorExport();
  }

  @override
  void dispose() {
    _exportSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPriorExport() async {
    try {
      final packages = await widget.exportPackageRepository
          .getPackagesForAgreement(widget.agreementId);
      if (mounted) {
        setState(() {
          _isLoadingPrior = false;
          if (packages.isNotEmpty) {
            final sortedPackages = [...packages]
              ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
            _latestPriorExport = sortedPackages.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPrior = false;
        });
      }
    }
  }

  void _startExport() {
    if (_isGenerating) return;

    _exportSubscription?.cancel();

    setState(() {
      _isGenerating = true;
      _shareErrorMessage = null;
      _status = const ExportStatus(state: ExportState.collecting);
    });

    _exportSubscription =
        widget.exportService.generateCompleteExport(widget.agreementId).listen(
      (status) {
        if (mounted) {
          setState(() {
            _status = status;
          });
          if (status.state == ExportState.completed) {
            _loadPriorExport();
          }
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _status = const ExportStatus(
              state: ExportState.failed,
            );
            _isGenerating = false;
          });
        }
      },
    );
  }

  Future<void> _sharePackage() async {
    if (_status.state != ExportState.completed ||
        _status.packageFilePath == null) {
      return;
    }

    final file = File(_status.packageFilePath!);
    bool isReadableFile = false;
    try {
      isReadableFile = file.existsSync() &&
          file.statSync().type == FileSystemEntityType.file;
    } catch (_) {}

    if (!isReadableFile) {
      if (mounted) {
        setState(() {
          _shareErrorMessage =
              'The generated package file is missing. Please try generating again.';
        });
      }
      return;
    }

    setState(() {
      _shareErrorMessage = null;
    });

    final filename = _status.packageFilePath!.split('/').last;

    final result = await widget.exportShareAdapter.sharePackage(
      filePath: _status.packageFilePath!,
      filename: filename,
      mimeType: 'application/zip',
    );

    if (!mounted) return;

    if (result == ExportShareResult.failed) {
      setState(() {
        _shareErrorMessage =
            'Could not share the Record Package. Please try again.';
      });
    }
  }

  String _getStateDescription(ExportState state) {
    switch (state) {
      case ExportState.idle:
        return 'Ready to prepare your Record Package.';
      case ExportState.collecting:
        return 'Organizing the agreement history…';
      case ExportState.verifyingSources:
        return 'Verifying included files…';
      case ExportState.generatingData:
        return 'Preparing the machine-readable record…';
      case ExportState.generatingPdf:
        return 'Creating the presentation PDF…';
      case ExportState.packaging:
        return 'Building the Record Package…';
      case ExportState.verifyingPackage:
        return 'Verifying the completed package…';
      case ExportState.completed:
        return 'Your Record Package is ready.';
      case ExportState.failed:
        return 'The Record Package could not be completed.';
      case ExportState.selectingScope:
        return 'Selecting package scope...';
    }
  }

  String _abbreviateHash(String? hash) {
    if (hash == null || hash.isEmpty) return '';
    if (hash.length <= 12) return hash;
    return '${hash.substring(0, 12)}...';
  }

  String _getFileSizeString(String? filePath) {
    if (filePath == null) return '0 B';
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
    } catch (_) {}
    return '0 B';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.agreementTitle != null
        ? 'Export: ${widget.agreementTitle}'
        : 'Export Record Package';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    Widget content;
    if (_status.state == ExportState.idle) {
      content = _buildIdleState();
    } else if (_status.state == ExportState.failed) {
      content = _buildFailedState();
    } else if (_status.state == ExportState.completed) {
      content = _buildCompletedState();
    } else {
      content = _buildActiveGenerationState();
    }

    return SingleChildScrollView(
      child: content,
    );
  }

  Widget _buildIdleState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Complete Record Package',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'The Record Package contains the complete agreement history, original files, machine-readable data, manifest, and presentation PDF.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Note: Generating this package will verify all cryptographic hashes before exporting.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 32),
          if (!_isLoadingPrior && _latestPriorExport != null) ...[
            const Text(
              'Prior exports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  "Generated: ${_latestPriorExport!.generatedAt.toLocal().toString().split('.').first}",
                ),
                subtitle: Text(
                  "Completeness: ${_latestPriorExport!.completenessState}\nHash: ${_abbreviateHash(_latestPriorExport!.manifestSha256)}",
                ),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 32),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _startExport,
            child: const Text('Generate Record Package'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGenerationState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: _status.progress),
          const SizedBox(height: 24),
          Text(
            _getStateDescription(_status.state),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          const SizedBox(height: 64),
          const ElevatedButton(
            onPressed: null, // Disabled during active generation
            child: Text('Generate Record Package'),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 24),
          const Text(
            'The Record Package could not be completed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'One or more included files could not be verified.\nNo completed package was saved.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Return to agreement'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startExport,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    final generatedAtText =
        _latestPriorExport?.generatedAt.toLocal().toString().split('.').first ??
            '';
    final filenameText = _status.packageFilePath?.split('/').last ?? '';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            _getStateDescription(_status.state),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filename',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(filenameText),
                  const SizedBox(height: 12),
                  const Text(
                    'Generated',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(generatedAtText),
                  const SizedBox(height: 12),
                  const Text(
                    'Size',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_getFileSizeString(_status.packageFilePath)),
                  const SizedBox(height: 12),
                  const Text(
                    'Manifest SHA-256',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_abbreviateHash(_latestPriorExport?.manifestSha256)),
                  const SizedBox(height: 12),
                  const Text(
                    'Completeness',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_latestPriorExport?.completenessState ?? ''),
                  const SizedBox(height: 12),
                  const Text(
                    'Warnings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text("${_latestPriorExport?.warningCount ?? 0}"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Verified against the generated manifest.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (_shareErrorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _shareErrorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Save or Share'),
            onPressed: _sharePackage,
          ),
        ],
      ),
    );
  }
}
