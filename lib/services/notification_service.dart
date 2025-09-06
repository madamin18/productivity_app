import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  AndroidNotificationChannel? _channel;

  Future<void> init() async {
    try {
      // ---- Timezone (best effort) ----
      try {
        tz.initializeTimeZones();
        // If you later add flutter_timezone, set local zone explicitly.
        // For now tz.local is fine.
        _log('Timezone initialized');
      } catch (e) {
        _log('Timezone init failed: $e');
      }

      // ---- Init settings ----
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _fln.initialize(initSettings);
      _log('FLN initialized');

      // ---- Android channel ----
      _channel = const AndroidNotificationChannel(
        'reminders',
        'Reminders',
        description: 'Task & habit reminders',
        importance: Importance.high,
      );

      final androidImpl = _fln
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null && _channel != null) {
        await androidImpl.createNotificationChannel(_channel!);
        _log('Channel created');
      } else {
        _log('Android impl or channel is null; skipping channel creation');
      }
    } catch (e) {
      // Never crash the app because of notifications.
      _log('Notification init error: $e');
    }
  }

  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> showNow({
    required String title,
    required String body,
    int id = 1000,
  }) async {
    await _fln.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel?.id ?? 'reminders',
          _channel?.name ?? 'Reminders',
          channelDescription: _channel?.description,
          priority: Priority.high,
          importance: Importance.high,
        ),
      ),
    );
  }

  Future<void> scheduleDaily({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (at.isBefore(now)) at = at.add(const Duration(days: 1));

    await _fln.zonedSchedule(
      id,
      title,
      body,
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel?.id ?? 'reminders',
          _channel?.name ?? 'Reminders',
          channelDescription: _channel?.description,
          priority: Priority.high,
          importance: Importance.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) => _fln.cancel(id);
  Future<void> cancelAll() => _fln.cancelAll();

  void _log(Object msg) {
    // Simple in-app log hook for debugging; keeps release safe.
    // ignore: avoid_print
    print('[NotificationService] $msg');
  }
}
