import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../agreement/domain/agreement.dart';
import '../../agreement/domain/agreement_version.dart';
import '../../clause/domain/clause.dart';
import '../domain/obligation.dart';
import '../domain/obligation_repository.dart';
import '../domain/schedule_rule.dart';

class ObligationConfirmationScreen extends StatefulWidget {
  const ObligationConfirmationScreen({
    super.key,
    required this.agreement,
    required this.version,
    required this.clause,
    required this.repository,
  });

  final Agreement agreement;
  final AgreementVersion version;
  final Clause clause;
  final ObligationRepository repository;

  @override
  State<ObligationConfirmationScreen> createState() =>
      _ObligationConfirmationScreenState();
}

class _ObligationConfirmationScreenState
    extends State<ObligationConfirmationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  String _title = '';
  String _description = '';
  String _responsibleParty = '';
  String _category = 'financial';

  ScheduleRuleType _scheduleType = ScheduleRuleType.manualOnly;
  DateTime? _dueDate;
  int _monthlyDay = 1;
  int _intervalDays = 7;

  bool _isSaving = false;

  void _submit() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final obligationId = const Uuid().v4();
      final obligation = Obligation(
        id: obligationId,
        agreementId: widget.agreement.id,
        sourceClauseId: widget.clause.id,
        sourceType: ObligationSourceType.contractual,
        responsiblePartyId: _responsibleParty,
        title: _title,
        description: _description,
        obligationCategory: _category,
        status: ObligationStatus.draft,
        createdAt: DateTime.now(),
      );

      await widget.repository.createDraftObligation(obligation);

      if (_scheduleType != ScheduleRuleType.manualOnly) {
        final ruleId = const Uuid().v4();
        String? recurrence;

        if (_scheduleType == ScheduleRuleType.monthlyDayOfMonth) {
          recurrence = '$_monthlyDay';
        } else if (_scheduleType == ScheduleRuleType.intervalDays) {
          recurrence = '$_intervalDays';
        }

        final rule = ScheduleRule(
          id: ruleId,
          obligationId: obligationId,
          ruleType: _scheduleType,
          timezone: 'UTC', // Simple default for Phase 1F
          startAt: _dueDate ?? DateTime.now(),
          recurrenceExpression: recurrence,
          leadTimeSeconds: 86400 * 3, // 3 days lead time
          gracePeriodSeconds: 0,
          confirmedAt: DateTime.now(),
        );
        await widget.repository.createScheduleRule(rule);
      }

      await widget.repository.confirmObligation(obligationId);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Obligation'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              setState(() {
                _currentStep = 1;
              });
            }
          } else {
            _submit();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          } else {
            Navigator.of(context).pop();
          }
        },
        steps: [
          Step(
            title: const Text('Define Obligation'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
            content: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                    onSaved: (val) => _title = val!,
                  ),
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Factual Description'),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                    onSaved: (val) => _description = val!,
                  ),
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Responsible Party'),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                    onSaved: (val) => _responsibleParty = val!,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Category'),
                    initialValue: _category,
                    items: const [
                      DropdownMenuItem(
                        value: 'financial',
                        child: Text('Financial'),
                      ),
                      DropdownMenuItem(
                        value: 'maintenance',
                        child: Text('Maintenance'),
                      ),
                      DropdownMenuItem(
                        value: 'compliance',
                        child: Text('Compliance'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _category = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ScheduleRuleType>(
                    decoration: const InputDecoration(labelText: 'Schedule'),
                    initialValue: _scheduleType,
                    items: const [
                      DropdownMenuItem(
                        value: ScheduleRuleType.manualOnly,
                        child: Text('No automatic schedule'),
                      ),
                      DropdownMenuItem(
                        value: ScheduleRuleType.oneTime,
                        child: Text('One Time'),
                      ),
                      DropdownMenuItem(
                        value: ScheduleRuleType.monthlyDayOfMonth,
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: ScheduleRuleType.intervalDays,
                        child: Text('Every N Days'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _scheduleType = val!;
                      });
                    },
                  ),
                  if (_scheduleType == ScheduleRuleType.oneTime ||
                      _scheduleType == ScheduleRuleType.monthlyDayOfMonth)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: _scheduleType == ScheduleRuleType.oneTime
                            ? 'Due Date (YYYY-MM-DD)'
                            : 'Start Date (YYYY-MM-DD)',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (DateTime.tryParse(val) == null)
                          return 'Invalid date format';
                        return null;
                      },
                      onSaved: (val) => _dueDate = DateTime.parse(val!),
                    ),
                  if (_scheduleType == ScheduleRuleType.monthlyDayOfMonth)
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Day of Month (1-31)',
                      ),
                      initialValue: '1',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final v = int.tryParse(val ?? '');
                        if (v == null || v < 1 || v > 31)
                          return 'Must be between 1 and 31';
                        return null;
                      },
                      onSaved: (val) => _monthlyDay = int.parse(val!),
                    ),
                  if (_scheduleType == ScheduleRuleType.intervalDays)
                    TextFormField(
                      decoration:
                          const InputDecoration(labelText: 'Interval (Days)'),
                      initialValue: '7',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final v = int.tryParse(val ?? '');
                        if (v == null || v < 1) return 'Must be >= 1';
                        return null;
                      },
                      onSaved: (val) => _intervalDays = int.parse(val!),
                    ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Review & Confirm'),
            isActive: _currentStep >= 1,
            state: _currentStep == 1 ? StepState.editing : StepState.disabled,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tekmerion is recording your confirmed understanding of this clause. It is not issuing legal advice.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ReviewRow('Agreement', widget.agreement.title),
                _ReviewRow('Version', widget.version.versionLabel),
                _ReviewRow(
                  'Page Range',
                  '${widget.clause.pageStart} - ${widget.clause.pageEnd}',
                ),
                _ReviewRow('Source Type', 'Contractual'),
                _ReviewRow('Responsible Party', _responsibleParty),
                _ReviewRow('Schedule', _scheduleType.name),
                const SizedBox(height: 16),
                const Text(
                  'Exact Clause Text:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.clause.sourceText,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isSaving) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
