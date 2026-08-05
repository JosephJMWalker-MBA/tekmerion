import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../application/export_state.dart';
import '../application/record_package_export_service.dart';

class RecordPackageExportScreen extends StatefulWidget {
  const RecordPackageExportScreen({
    super.key,
    required this.agreementId,
    required this.exportService,
  });
  final String agreementId;
  final RecordPackageExportService exportService;

  @override
  State<RecordPackageExportScreen> createState() =>
      _RecordPackageExportScreenState();
}

class _RecordPackageExportScreenState extends State<RecordPackageExportScreen> {
  ExportStatus _status = const ExportStatus();
  bool _isGenerating = false;

  void _startExport() {
    setState(() {
      _isGenerating = true;
    });

    widget.exportService.generateCompleteExport(widget.agreementId).listen(
      (status) {
        setState(() {
          _status = status;
        });
      },
      onDone: () {
        setState(() {
          _isGenerating = false;
        });
      },
      onError: (Object e) {
        setState(() {
          _status = ExportStatus(
            state: ExportState.failed,
            message: 'An error occurred during generation.',
            error: e.toString(),
          );
          _isGenerating = false;
        });
      },
    );
  }

  void _sharePackage() {
    if (_status.exportPackageId != null) {
      // Typically we would retrieve the actual file path from managed storage
      // For this slice, we represent the intent to share
      // ignore: deprecated_member_use
      Share.share('Tekmerion Record Package generated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Record Package')),
      body: Padding(
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
              'Generates a secure, self-contained zip file containing the original agreement, '
              'all confirmed obligations, timeline records, evidence files, and a '
              'human-readable PDF summary. This package is neutral and portable.',
            ),
            const SizedBox(height: 48),
            if (_status.state != ExportState.idle) ...[
              LinearProgressIndicator(value: _status.progress),
              const SizedBox(height: 16),
              Text(
                _status.message ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (_status.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _status.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 32),
            ],
            const Spacer(),
            if (_status.state == ExportState.completed)
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Save or Share Package'),
                onPressed: _sharePackage,
              )
            else
              ElevatedButton(
                onPressed: _isGenerating ? null : _startExport,
                child: const Text('Generate Package'),
              ),
          ],
        ),
      ),
    );
  }
}
