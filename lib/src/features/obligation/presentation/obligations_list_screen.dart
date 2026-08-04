import 'package:flutter/material.dart';

import '../../agreement/domain/agreement.dart';
import '../../record/application/complete_obligation_service.dart';
import '../../record/presentation/complete_obligation_screen.dart';
import '../domain/obligation.dart';
import '../domain/obligation_repository.dart';

class ObligationsListScreen extends StatefulWidget {
  const ObligationsListScreen({
    super.key,
    required this.agreement,
    required this.agreementVersionId,
    required this.obligationRepository,
    required this.completeObligationService,
  });

  final Agreement agreement;
  final String agreementVersionId;
  final ObligationRepository obligationRepository;
  final CompleteObligationService completeObligationService;

  @override
  State<ObligationsListScreen> createState() => _ObligationsListScreenState();
}

class _ObligationsListScreenState extends State<ObligationsListScreen> {
  List<Obligation>? _obligations;

  @override
  void initState() {
    super.initState();
    _loadObligations();
  }

  Future<void> _loadObligations() async {
    final list = await widget.obligationRepository
        .getObligationsForAgreement(widget.agreement.id);

    // Sort so confirmed/active are first, then fulfilled
    list.sort((a, b) {
      if (a.status == ObligationStatus.fulfilled &&
          b.status != ObligationStatus.fulfilled) {
        return 1;
      }
      if (b.status == ObligationStatus.fulfilled &&
          a.status != ObligationStatus.fulfilled) {
        return -1;
      }
      return 0;
    });

    if (mounted) {
      setState(() {
        _obligations = list;
      });
    }
  }

  void _onComplete(Obligation obligation) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => CompleteObligationScreen(
          obligation: obligation,
          agreementVersionId: widget.agreementVersionId,
          service: widget.completeObligationService,
        ),
      ),
    );

    if (result == true) {
      // Reload obligations to reflect the new state
      _loadObligations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Obligations: ${widget.agreement.title}'),
      ),
      body: _obligations == null
          ? const Center(child: CircularProgressIndicator())
          : _obligations!.isEmpty
              ? const Center(
                  child: Text('No obligations found for this agreement.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _obligations!.length,
                  itemBuilder: (context, index) {
                    final obligation = _obligations![index];
                    final isFulfilled =
                        obligation.status == ObligationStatus.fulfilled;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isFulfilled
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                          : null,
                      child: ListTile(
                        title: Text(
                          obligation.title,
                          style: TextStyle(
                            decoration:
                                isFulfilled ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '${obligation.description}\nStatus: ${obligation.status.name}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: isFulfilled
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : FilledButton(
                                onPressed: () => _onComplete(obligation),
                                child: const Text('Complete'),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
