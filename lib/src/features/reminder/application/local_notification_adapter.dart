import 'package:tekmerion/src/features/reminder/domain/notification_permission_state.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';

class NotificationScheduleRequest {
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
  final int notificationId;
  final String reminderId;
  final String agreementId;
  final String obligationId;
  final DateTime scheduledUtcInstant;
  final String timezoneIdentifier;
  final String title;
  final String body;
  final Map<String, String> payloadData;
}

abstract class LocalNotificationAdapter {
  Future<NotificationPermissionState> inspectPermissionState();
  Future<NotificationPermissionState> requestPermission();
  Future<NotificationSchedulingState> scheduleNotification(
      NotificationScheduleRequest request);
  Future<void> cancelNotification(int notificationId);
  Future<void> cancelForObligation(String obligationId);
}

class DummyLocalNotificationAdapter implements LocalNotificationAdapter {
  @override
  Future<NotificationPermissionState> inspectPermissionState() async =>
      NotificationPermissionState.granted;

  @override
  Future<NotificationPermissionState> requestPermission() async =>
      NotificationPermissionState.granted;

  @override
  Future<NotificationSchedulingState> scheduleNotification(
          NotificationScheduleRequest request) async =>
      NotificationSchedulingState.scheduled;

  @override
  Future<void> cancelNotification(int notificationId) async {}

  @override
  Future<void> cancelForObligation(String obligationId) async {}
}
