import 'package:flutter/material.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_reconciliation_service.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_permission_state.dart';

class NotificationPermissionBanner extends StatefulWidget {
  const NotificationPermissionBanner({
    super.key,
    required this.reconciliationService,
  });

  final ReminderReconciliationService reconciliationService;

  @override
  State<NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends State<NotificationPermissionBanner> {
  NotificationPermissionState? _state;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await widget.reconciliationService.inspectPermissionState();
    if (mounted) {
      setState(() {
        _state = state;
      });
    }
  }

  Future<void> _requestPermission() async {
    final state = await widget.reconciliationService.requestPermission();
    if (mounted) {
      setState(() {
        _state = state;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null) {
      return const SizedBox.shrink();
    }

    Widget content;
    bool showAction = false;

    switch (_state!) {
      case NotificationPermissionState.notDetermined:
        content = const Text(
          'Reminders remain available in Tekmerion. Enable device notifications for additional alerts.',
        );
        showAction = true;
        break;
      case NotificationPermissionState.denied:
      case NotificationPermissionState.permanentlyDenied:
        content = const Text(
          'Device notifications are off. Your reminders remain available here.',
        );
        showAction = true;
        break;
      case NotificationPermissionState.granted:
        content = const Text('Device notifications enabled.');
        showAction = false;
        break;
      case NotificationPermissionState.unavailable:
        content = const Text(
          'Device notifications are unavailable on this device. Your reminders remain available in Tekmerion.',
        );
        showAction = false;
        break;
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.notifications_outlined),
            const SizedBox(width: 12),
            Expanded(child: content),
            if (showAction)
              TextButton(
                onPressed: _requestPermission,
                child: const Text('Enable device notifications',
                    textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}
