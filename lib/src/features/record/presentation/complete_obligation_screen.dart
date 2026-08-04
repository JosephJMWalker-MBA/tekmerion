import 'package:flutter/material.dart';
import '../../obligation/domain/obligation.dart';
import '../application/complete_obligation_service.dart';

class CompleteObligationScreen extends StatefulWidget {
  const CompleteObligationScreen({
    super.key,
    required this.obligation,
    required this.agreementVersionId,
    required this.service,
  });

  final Obligation obligation;
  final String agreementVersionId;
  final CompleteObligationService service;

  @override
  State<CompleteObligationScreen> createState() =>
      _CompleteObligationScreenState();
}

class _CompleteObligationScreenState extends State<CompleteObligationScreen> {
  final _formKey = GlobalKey<FormState>();

  String _note = '';
  DateTime _occurredAt = DateTime.now();
  bool _pickEvidence = false;

  bool _isSaving = false;
  String? _statusMessage;

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _occurredAt) {
      setState(() {
        _occurredAt = picked;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
      _statusMessage = 'Starting...';
    });

    try {
      final result = await widget.service.completeObligation(
        obligationId: widget.obligation.id,
        agreementVersionId: widget.agreementVersionId,
        note: _note,
        occurredAt: _occurredAt,
        pickEvidence: _pickEvidence,
        onStateChange: (state) {
          if (!mounted) return;
          setState(() {
            switch (state) {
              case 'selecting_evidence':
                _statusMessage = 'Waiting for receipt selection...';
                break;
              case 'ingesting_evidence':
                _statusMessage = 'Saving receipt securely...';
                break;
              case 'saving_record':
                _statusMessage = 'Drafting completed record...';
                break;
              case 'updating_obligation':
                _statusMessage = 'Updating obligation status...';
                break;
              case 'completed':
                _statusMessage = 'Record finalized successfully!';
                break;
            }
          });
        },
      );

      if (!mounted) return;

      if (result == null && _pickEvidence) {
        // User probably canceled file selection
        setState(() {
          _isSaving = false;
          _statusMessage = 'File selection canceled.';
        });
        return;
      }

      // Show success and pop
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obligation completed and recorded!')),
      );

      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _statusMessage = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Obligation'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Obligation Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Title: ${widget.obligation.title}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('Description: ${widget.obligation.description}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Proof of Completion',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  'Occurred At: ${_occurredAt.toLocal().toString().split(' ').first}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _isSaving ? null : () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Optional Note / Factual Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onSaved: (val) => _note = val ?? '',
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Attach Receipt/Document'),
                subtitle: const Text('Provide evidence of completion'),
                value: _pickEvidence,
                onChanged: _isSaving
                    ? null
                    : (val) {
                        setState(() {
                          _pickEvidence = val;
                        });
                      },
              ),
              const SizedBox(height: 24),
              if (_isSaving)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusMessage ?? ''),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete & Finalize Record'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
