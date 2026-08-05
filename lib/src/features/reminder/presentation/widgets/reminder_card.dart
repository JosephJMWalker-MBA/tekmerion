import 'package:flutter/material.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_card_view_model.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_temporal_status.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.viewModel,
    this.onAcknowledge,
    this.onDismiss,
    this.onComplete,
  });

  final ReminderCardViewModel viewModel;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onDismiss;
  final VoidCallback? onComplete;

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
    final statusColor = _getStatusColor(context, viewModel.temporalStatus);

    return Card(
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
                    viewModel.obligationTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusLabel(viewModel.temporalStatus),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Agreement: ${viewModel.agreementTitle}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (viewModel.clauseReference != null && viewModel.clauseReference!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Clause: ${viewModel.clauseReference}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Due: ${viewModel.dueAtDisplay}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
            if (viewModel.canAcknowledge || viewModel.canDismiss || viewModel.canComplete) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (viewModel.canDismiss && onDismiss != null)
                    TextButton(
                      onPressed: onDismiss,
                      child: const Text('Dismiss'),
                    ),
                  if (viewModel.canAcknowledge && onAcknowledge != null)
                    TextButton(
                      onPressed: onAcknowledge,
                      child: const Text('Acknowledge'),
                    ),
                  if (viewModel.canComplete && onComplete != null)
                    ElevatedButton(
                      onPressed: onComplete,
                      child: const Text('Complete'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
