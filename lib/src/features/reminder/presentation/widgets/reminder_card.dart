import 'package:flutter/material.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_card_view_model.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_temporal_status.dart';

class ReminderCard extends StatefulWidget {
  const ReminderCard({
    super.key,
    required this.viewModel,
    this.onAcknowledge,
    this.onDismiss,
    this.onComplete,
  });

  final ReminderCardViewModel viewModel;
  final Future<void> Function()? onAcknowledge;
  final Future<void> Function()? onDismiss;
  final void Function()? onComplete;

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> {
  bool _isProcessing = false;

  Future<void> _handleAction(Future<void> Function()? action) async {
    if (action == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Color _getStatusColor(BuildContext context, ReminderTemporalStatus status) {
    switch (status) {
      case ReminderTemporalStatus.overdue:
        return Colors.red.shade700;
      case ReminderTemporalStatus.dueToday:
        return Colors.orange.shade700;
      case ReminderTemporalStatus.upcoming:
        return Colors.blue.shade700;
      case ReminderTemporalStatus.acknowledged:
        return Colors.green.shade700;
      case ReminderTemporalStatus.terminal:
        return Colors.grey;
    }
  }

  String _getStatusLabel(ReminderTemporalStatus status) {
    switch (status) {
      case ReminderTemporalStatus.overdue:
        return 'Overdue';
      case ReminderTemporalStatus.dueToday:
        return 'Due Today';
      case ReminderTemporalStatus.upcoming:
        return 'Upcoming';
      case ReminderTemporalStatus.acknowledged:
        return 'Acknowledged';
      case ReminderTemporalStatus.terminal:
        return 'Completed/Terminal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        _getStatusColor(context, widget.viewModel.temporalStatus);

    return Semantics(
      label: 'Reminder for ${widget.viewModel.obligationTitle}',
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.viewModel.obligationTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    label:
                        'Status: ${_getStatusLabel(widget.viewModel.temporalStatus)}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getStatusLabel(widget.viewModel.temporalStatus),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Agreement: ${widget.viewModel.agreementTitle}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (widget.viewModel.clauseReference != null &&
                  widget.viewModel.clauseReference!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Clause: ${widget.viewModel.clauseReference}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${widget.viewModel.dueAtDisplay}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
              if (widget.viewModel.canAcknowledge ||
                  widget.viewModel.canDismiss ||
                  widget.viewModel.canComplete) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.viewModel.canDismiss && widget.onDismiss != null)
                      Semantics(
                        button: true,
                        label: 'Dismiss reminder',
                        child: TextButton(
                          onPressed: _isProcessing
                              ? null
                              : () => _handleAction(widget.onDismiss),
                          child: const Text('Dismiss'),
                        ),
                      ),
                    if (widget.viewModel.canAcknowledge &&
                        widget.onAcknowledge != null)
                      Semantics(
                        button: true,
                        label: 'Acknowledge reminder',
                        child: TextButton(
                          onPressed: _isProcessing
                              ? null
                              : () => _handleAction(widget.onAcknowledge),
                          child: const Text('Acknowledge'),
                        ),
                      ),
                    if (widget.viewModel.canComplete &&
                        widget.onComplete != null)
                      Semantics(
                        button: true,
                        label: 'Complete obligation',
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : widget.onComplete,
                          child: const Text('Complete'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
