import 'package:flutter/material.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_reconciliation_service.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_view_service.dart';
import 'package:tekmerion/src/features/reminder/infrastructure/sqlite_reminder_repository.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_card_view_model.dart';
import 'package:tekmerion/src/features/reminder/presentation/widgets/notification_permission_banner.dart';
import 'package:tekmerion/src/features/reminder/presentation/widgets/reminder_card.dart';

class UpcomingRemindersScreen extends StatefulWidget {
  const UpcomingRemindersScreen({
    super.key,
    required this.viewService,
    required this.reconciliationService,
    required this.gracePeriod,
    this.daysHorizon = 30,
    this.nowUtc,
    this.onAcknowledge,
    this.onDismiss,
    this.onComplete,
  });

  final ReminderViewService viewService;
  final ReminderReconciliationService reconciliationService;
  final Duration gracePeriod;
  final int daysHorizon;
  final UtcNow? nowUtc;
  final void Function(ReminderCardViewModel)? onAcknowledge;
  final void Function(ReminderCardViewModel)? onDismiss;
  final void Function(ReminderCardViewModel)? onComplete;

  @override
  State<UpcomingRemindersScreen> createState() =>
      _UpcomingRemindersScreenState();
}

class _UpcomingRemindersScreenState extends State<UpcomingRemindersScreen> {
  late Future<List<ReminderCardViewModel>> _viewModelsFuture;
  late UtcNow _nowUtc;

  @override
  void initState() {
    super.initState();
    _nowUtc = widget.nowUtc ?? (() => DateTime.now().toUtc());
    _viewModelsFuture = _reconcileAndLoad();
  }

  Future<List<ReminderCardViewModel>> _reconcileAndLoad() async {
    try {
      await widget.reconciliationService.triggerReconciliation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Failed to sync latest reminders. Showing local data.')),
        );
      }
    }
    return widget.viewService.getUpcomingViewModels(
      _nowUtc(),
      widget.gracePeriod,
      daysHorizon: widget.daysHorizon,
    );
  }

  void _loadData() {
    setState(() {
      _viewModelsFuture = widget.viewService.getUpcomingViewModels(
        _nowUtc(),
        widget.gracePeriod,
        daysHorizon: widget.daysHorizon,
      );
    });
  }

  Future<void> _handleAcknowledge(ReminderCardViewModel vm) async {
    if (widget.onAcknowledge != null) {
      widget.onAcknowledge!(vm);
      return;
    }
    await widget.viewService.acknowledgeReminder(vm.reminderId);
    _loadData(); // Refresh views
  }

  Future<void> _handleDismiss(ReminderCardViewModel vm) async {
    if (widget.onDismiss != null) {
      widget.onDismiss!(vm);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss Reminder'),
        content: const Text(
          'This will dismiss the reminder for this occurrence. '
          'The underlying obligation and schedule remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.viewService.dismissReminder(vm.reminderId);
      _loadData();
    }
  }

  void _handleComplete(ReminderCardViewModel vm) {
    if (widget.onComplete != null) {
      widget.onComplete!(vm);
      return;
    }
    // Expected to be handled by AgreementHomeScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<List<ReminderCardViewModel>>(
        future: _viewModelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No upcoming reminders.'));
          }

          final viewModels = snapshot.data!;
          return Column(
            children: [
              NotificationPermissionBanner(
                reconciliationService: widget.reconciliationService,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: viewModels.length,
                  itemBuilder: (context, index) {
                    final vm = viewModels[index];
                    return ReminderCard(
                      viewModel: vm,
                      onAcknowledge: vm.canAcknowledge
                          ? () => _handleAcknowledge(vm)
                          : null,
                      onDismiss:
                          vm.canDismiss ? () => _handleDismiss(vm) : null,
                      onComplete: vm.canComplete
                          ? () {
                              _handleComplete(vm);
                            }
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
