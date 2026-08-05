import 'package:tekmerion/src/features/reminder/domain/notification_permission_state.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';

class NotificationScheduleRequest {
  final int notificationId;
  final String reminderId;
  final String agreementId;
  final String obligationId;
  final DateTime scheduledUtcInstant;
  final String timezoneIdentifier;
  final String title;
  final String body;
  final Map<String, String> payloadData;

  const NotificationScheduleRequest({
    required this.notificationId,
    required this.reminderId,
    required this.agreementId,
    required this.obligationId,
    required this.scheduledUtcInstant,
    required this.timezoneIdentifier,
    required this.title,
    required this.body,
    required this.payloadData,
  });
}

abstract class LocalNotificationAdapter {
  Future<NotificationPermissionState> inspectPermissionState();
  Future<NotificationPermissionState> requestPermission();
  Future<NotificationSchedulingState> scheduleNotification(NotificationScheduleRequest request);
  Future<void> cancelNotification(int notificationId);
  Future<void> cancelForObligation(String obligationId);
}
