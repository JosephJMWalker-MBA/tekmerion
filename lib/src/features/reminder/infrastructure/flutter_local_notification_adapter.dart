import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tekmerion/src/features/reminder/application/local_notification_adapter.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_permission_state.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';

class FlutterLocalNotificationAdapter implements LocalNotificationAdapter {
  FlutterLocalNotificationAdapter(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tekmerion_reminders_v1',
    'Agreement reminders',
    description: 'Reminders created from user-confirmed agreement obligations',
    importance: Importance.high,
  );

  @override
  Future<NotificationPermissionState> inspectPermissionState() async {
    final status = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();

    if (status == null) {
      return NotificationPermissionState.unavailable;
    } else if (status) {
      return NotificationPermissionState.granted;
    } else {
      return NotificationPermissionState.denied;
    }
  }

  @override
  Future<NotificationPermissionState> requestPermission() async {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    if (result == null) {
      return NotificationPermissionState.unavailable;
    } else if (result) {
      return NotificationPermissionState.granted;
    } else {
      return NotificationPermissionState.denied;
    }
  }

  @override
  Future<NotificationSchedulingState> scheduleNotification(
      NotificationScheduleRequest request) async {
    try {
      final nowUtc = DateTime.now().toUtc();
      if (request.scheduledUtcInstant.isBefore(nowUtc)) {
        return NotificationSchedulingState.failed;
      }

      final location = tz.getLocation(request.timezoneIdentifier);
      final scheduledDate =
          tz.TZDateTime.from(request.scheduledUtcInstant, location);

      final payloadStr = jsonEncode(request.payloadData);

      await _plugin.zonedSchedule(
        id: request.notificationId,
        title: request.title,
        body: request.body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: _channel.importance,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payloadStr,
      );

      return NotificationSchedulingState.scheduled;
    } catch (e) {
      return NotificationSchedulingState.failed;
    }
  }

  @override
  Future<void> cancelNotification(int notificationId) async {
    try {
      await _plugin.cancel(id: notificationId);
    } catch (e) {
      // Ignore cancellation failures
    }
  }

  @override
  Future<void> cancelForObligation(String obligationId) async {
    try {
      final pendingList = await _plugin.pendingNotificationRequests();
      for (final req in pendingList) {
        if (req.payload != null) {
          try {
            final data = jsonDecode(req.payload!) as Map<String, dynamic>;
            if (data['obligationId'] == obligationId) {
              await _plugin.cancel(id: req.id);
            }
          } catch (_) {
            // ignore malformed payloads
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }
}
