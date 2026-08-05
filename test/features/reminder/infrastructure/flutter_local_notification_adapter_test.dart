import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tekmerion/src/features/reminder/application/local_notification_adapter.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_permission_state.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/infrastructure/flutter_local_notification_adapter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart'; // Ensure TZDateTime is available if needed

class FakeAndroidPlugin implements AndroidFlutterLocalNotificationsPlugin {
  bool? areNotificationsEnabledResult = true;
  bool? requestNotificationsPermissionResult = true;

  @override
  Future<bool?> areNotificationsEnabled() async => areNotificationsEnabledResult;

  @override
  Future<bool?> requestNotificationsPermission() async =>
      requestNotificationsPermissionResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFlutterLocalNotificationsPlugin
    implements FlutterLocalNotificationsPlugin {
  final androidPlugin = FakeAndroidPlugin();
  bool scheduleSuccess = true;
  bool cancelSuccess = true;
  List<PendingNotificationRequest> pending = [];
  List<int> cancelledIds = [];

  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() {
    if (T == AndroidFlutterLocalNotificationsPlugin) {
      return androidPlugin as T;
    }
    return null;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (!scheduleSuccess) throw Exception('Schedule failed');
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    if (!cancelSuccess) throw Exception('Cancel failed');
    cancelledIds.add(id);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return pending;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('FlutterLocalNotificationAdapter', () {
    late FakeFlutterLocalNotificationsPlugin plugin;
    late FlutterLocalNotificationAdapter adapter;

    setUp(() {
      plugin = FakeFlutterLocalNotificationsPlugin();
      adapter = FlutterLocalNotificationAdapter(plugin);
    });

    test('inspectPermissionState maps true to granted', () async {
      plugin.androidPlugin.areNotificationsEnabledResult = true;
      final state = await adapter.inspectPermissionState();
      expect(state, NotificationPermissionState.granted);
    });

    test('inspectPermissionState maps false to denied', () async {
      plugin.androidPlugin.areNotificationsEnabledResult = false;
      final state = await adapter.inspectPermissionState();
      expect(state, NotificationPermissionState.denied);
    });

    test('inspectPermissionState maps null to unavailable', () async {
      plugin.androidPlugin.areNotificationsEnabledResult = null;
      final state = await adapter.inspectPermissionState();
      expect(state, NotificationPermissionState.unavailable);
    });

    test('requestPermission maps true to granted', () async {
      plugin.androidPlugin.requestNotificationsPermissionResult = true;
      final state = await adapter.requestPermission();
      expect(state, NotificationPermissionState.granted);
    });

    test('scheduleNotification returns failed if scheduled in past', () async {
      final request = NotificationScheduleRequest(
        notificationId: 1,
        reminderId: 'r1',
        agreementId: 'a1',
        obligationId: 'o1',
        scheduledUtcInstant: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        timezoneIdentifier: 'UTC',
        title: 'Title',
        body: 'Body',
        payloadData: {},
      );

      final state = await adapter.scheduleNotification(request);
      expect(state, NotificationSchedulingState.failed);
    });

    test('scheduleNotification returns scheduled on success', () async {
      final request = NotificationScheduleRequest(
        notificationId: 1,
        reminderId: 'r1',
        agreementId: 'a1',
        obligationId: 'o1',
        scheduledUtcInstant: DateTime.now().toUtc().add(const Duration(hours: 1)),
        timezoneIdentifier: 'UTC',
        title: 'Title',
        body: 'Body',
        payloadData: {},
      );

      final state = await adapter.scheduleNotification(request);
      expect(state, NotificationSchedulingState.scheduled);
    });

    test('scheduleNotification returns failed on exception', () async {
      plugin.scheduleSuccess = false;
      final request = NotificationScheduleRequest(
        notificationId: 1,
        reminderId: 'r1',
        agreementId: 'a1',
        obligationId: 'o1',
        scheduledUtcInstant: DateTime.now().toUtc().add(const Duration(hours: 1)),
        timezoneIdentifier: 'UTC',
        title: 'Title',
        body: 'Body',
        payloadData: {},
      );

      final state = await adapter.scheduleNotification(request);
      expect(state, NotificationSchedulingState.failed);
    });

    test('cancelNotification swallows exceptions', () async {
      plugin.cancelSuccess = false;
      await expectLater(adapter.cancelNotification(1), completes);
    });

    test('cancelForObligation cancels matching requests', () async {
      plugin.pending = [
        const PendingNotificationRequest(1, 'A', 'B', '{"obligationId": "target"}'),
        const PendingNotificationRequest(2, 'A', 'B', '{"obligationId": "other"}'),
      ];

      await adapter.cancelForObligation('target');
      expect(plugin.cancelledIds, [1]);
    });
  });
}
