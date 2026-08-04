import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../domain/clause.dart';
import '../domain/clause_repository.dart';

enum ClauseUiState {
  idle,
  editingDraft,
  reviewing,
  saving,
  completed,
  failed,
}

class ManualClauseScreen extends StatefulWidget {
  const ManualClauseScreen({
    super.key,
    required this.agreementVersionId,
    required this.pageStart,
    required this.pageEnd,
    required this.repository,
  });

  final String agreementVersionId;
  final int pageStart;
  final int pageEnd;
  final ClauseRepository repository;

  @override
  State<ManualClauseScreen> createState() => _ManualClauseScreenState();
}

class _ManualClauseScreenState extends State<ManualClauseScreen> {
  final _formKey = GlobalKey<FormState>();
  ClauseUiState _state = ClauseUiState.editingDraft;

  late final TextEditingController _sourceTextController;
  late final TextEditingController _clauseNumberController;
  late final TextEditingController _headingController;
  late final TextEditingController _pageStartController;
  late final TextEditingController _pageEndController;

  String? _errorMessage;
  Clause? _draftClause;

  @override
  void initState() {
    super.initState();
    _sourceTextController = TextEditingController();
    _clauseNumberController = TextEditingController();
    _headingController = TextEditingController();
    _pageStartController =
        TextEditingController(text: widget.pageStart.toString());
    _pageEndController = TextEditingController(text: widget.pageEnd.toString());
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    _clauseNumberController.dispose();
    _headingController.dispose();
    _pageStartController.dispose();
    _pageEndController.dispose();
    super.dispose();
  }

  void _onReview() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _state = ClauseUiState.reviewing;
        _errorMessage = null;
      });
    }
  }

  void _onEdit() {
    setState(() {
      _state = ClauseUiState.editingDraft;
      _errorMessage = null;
    });
  }

  Future<void> _onSave() async {
    if (_state == ClauseUiState.saving) return;

    setState(() {
      _state = ClauseUiState.saving;
      _errorMessage = null;
    });

    try {
      final pStart = int.parse(_pageStartController.text);
      final pEnd = int.parse(_pageEndController.text);

      final clause = Clause(
        id: const Uuid().v4(),
        agreementVersionId: widget.agreementVersionId,
        sourceText: _sourceTextController.text,
        heading:
            _headingController.text.isNotEmpty ? _headingController.text : null,
        clauseNumber: _clauseNumberController.text.isNotEmpty
            ? _clauseNumberController.text
            : null,
        pageStart: pStart,
        pageEnd: pEnd,
        reviewState: ClauseReviewState.draft,
        createdAt: DateTime.now().toUtc(),
      );

      await widget.repository.createDraftClause(clause);
      await widget.repository.confirmClause(clause.id);

      if (mounted) {
        setState(() {
          _state = ClauseUiState.completed;
        });

        // Wait a brief moment to show success state, then pop back
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pop(); // pop back to viewer
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = ClauseUiState.failed;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Clause'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_state == ClauseUiState.completed) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Clause successfully confirmed.'),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_state == ClauseUiState.failed && _errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sourceTextController,
            decoration: const InputDecoration(
              labelText: 'Exact source text',
              hintText: 'Paste the exact text of the clause from the PDF',
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Source text is required.';
              }
              return null;
            },
            readOnly: _state == ClauseUiState.reviewing ||
                _state == ClauseUiState.saving,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _clauseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Clause Number (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: _state == ClauseUiState.reviewing ||
                      _state == ClauseUiState.saving,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _headingController,
                  decoration: const InputDecoration(
                    labelText: 'Heading (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: _state == ClauseUiState.reviewing ||
                      _state == ClauseUiState.saving,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pageStartController,
                  decoration: const InputDecoration(
                    labelText: 'Page Start',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final val = int.tryParse(value ?? '');
                    if (val == null || val < 1) return 'Invalid page';
                    return null;
                  },
                  readOnly: _state == ClauseUiState.reviewing ||
                      _state == ClauseUiState.saving,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _pageEndController,
                  decoration: const InputDecoration(
                    labelText: 'Page End',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final val = int.tryParse(value ?? '');
                    if (val == null || val < 1) return 'Invalid page';
                    final start = int.tryParse(_pageStartController.text);
                    if (start != null && val < start) return 'Must be >= start';
                    return null;
                  },
                  readOnly: _state == ClauseUiState.reviewing ||
                      _state == ClauseUiState.saving,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_state == ClauseUiState.editingDraft ||
              _state == ClauseUiState.failed)
            FilledButton(
              onPressed: _onReview,
              child: const Text('Review Clause'),
            ),
          if (_state == ClauseUiState.reviewing) ...[
            const Divider(),
            const Text(
              'Please review the clause carefully. Manual clauses must match the document precisely.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _onEdit,
                  child: const Text('Edit'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _onSave,
                  child: const Text('Confirm & Save'),
                ),
              ],
            ),
          ],
          if (_state == ClauseUiState.saving)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
