import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show PendingNotificationRequest;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  AndroidNotificationChannel? _channel;

  int boosterId(int baseId) => baseId + 1000000; // distinct id for booster

  // ------------------ LOG ------------------
  void _log(Object msg) {
    // ignore: avoid_print
    print('[NotificationService] $msg');
  }

  void _logSchedule(String tag, int id, DateTime when) {
    _log('$tag id=$id at ${when.toLocal()}');
  }

  // ------------------ HELPERS ------------------
  int secondsUntilToday(TimeOfDay time) {
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return at.difference(now).inSeconds;
  }

  Future<void> debugLogPending() async {
    final reqs = await _fln.pendingNotificationRequests();
    _log('Pending notifications: ${reqs.length}');
    for (final r in reqs) {
      _log(
        '• id=${r.id} title="${r.title}" body="${r.body}" payload=${r.payload}',
      );
    }
  }

  Future<List<PendingNotificationRequest>> pending() async {
    return _fln.pendingNotificationRequests();
  }

  // ------------------ INIT ------------------
  Future<void> init() async {
    try {
      // Timezone (best effort)
      try {
        tz.initializeTimeZones();
        // Fallback: rely on tz.local (no explicit setLocalLocation).
        _log('Timezone initialized (default tz.local)');
      } catch (e) {
        _log('Timezone init failed: $e');
      }

      // Init settings
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _fln.initialize(initSettings);
      _log('FLN initialized');

      // Android channel
      _channel = const AndroidNotificationChannel(
        'reminders_high',
        'Reminders (High)',
        description: 'Task & habit reminders',
        importance: Importance.high,
      );

      final androidImpl = _fln
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null && _channel != null) {
        await androidImpl.createNotificationChannel(_channel!);
        _log('Channel created: ${_channel!.id}');
      }
    } catch (e) {
      // Never crash the app because of notifications.
      _log('Notification init error: $e');
    }
  }

  // ------------------ PERMISSION ------------------
  Future<bool> requestPermission() async {
    // Request notification permission (Android 13+)
    final notif = await Permission.notification.request();

    // Best-effort request for exact alarms (Android 12+). Some OEMs require user action in settings.
    try {
      final exact = await Permission.scheduleExactAlarm.request();
      if (!exact.isGranted) {
        _log('Exact alarm not granted; using inexact schedule as fallback');
      }
    } catch (_) {
      // ignore on platforms where not applicable
    }

    return notif.isGranted;
  }

  Future ensurePermissionsWithSettingsPrompt(BuildContext context) async {
    final granted = await requestPermission();
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notifications are disabled'),
          action: SnackBarAction(
            label: 'Enable',
            onPressed: () async {
              await openAppSettings();
            },
          ),
        ),
      );
    }
  }

  // ------------------ SHOW NOW ------------------
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
          _channel?.id ?? 'reminders_high',
          _channel?.name ?? 'Reminders (High)',
          channelDescription: _channel?.description,
          priority: Priority.high,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  // ------------------ TIMER FALLBACK ------------------
  Future<void> timerInSeconds({
    required int id,
    required int seconds,
    required String title,
    required String body,
  }) async {
    if (seconds <= 0) {
      await showNow(title: title, body: body, id: id);
      return;
    }
    _log('Timer fallback set for $seconds seconds (id=$id)');
    Timer(Duration(seconds: seconds), () async {
      _log('Timer fired (id=$id)');
      await showNow(title: title, body: body, id: id);
    });
  }

  // ------------------ ONE-OFF SCHEDULING ------------------
  Future<void> scheduleInSeconds({
    required int id,
    required int seconds,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final when = now.add(Duration(seconds: seconds));
    _logSchedule('scheduleInSeconds', id, when);

    await _fln.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel?.id ?? 'reminders_high',
          _channel?.name ?? 'Reminders (High)',
          channelDescription: _channel?.description,
          priority: Priority.high,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Smart helper: for short delays (<60s) use Timer fallback; otherwise use scheduler.
  Future<void> scheduleSmartSeconds({
    required int id,
    required int seconds,
    required String title,
    required String body,
    bool forceExact = false,
  }) async {
    if (!forceExact && seconds < 60) {
      await timerInSeconds(id: id, seconds: seconds, title: title, body: body);
      return;
    }
    await scheduleInSeconds(id: id, seconds: seconds, title: title, body: body);
  }

  // ------------------ DAILY SCHEDULING ------------------
  Future<void> scheduleDailyInexact({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final nowTz = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      nowTz.year,
      nowTz.month,
      nowTz.day,
      time.hour,
      time.minute,
    );
    if (at.isBefore(nowTz)) {
      at = at.add(const Duration(days: 1));
    }

    _logSchedule('scheduleDailyInexact', id, at);

    await _fln.zonedSchedule(
      id,
      title,
      body,
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel?.id ?? 'reminders_high',
          _channel?.name ?? 'Reminders (High)',
          channelDescription: _channel?.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
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

    // Prefer exact alarms when allowed; otherwise fallback to inexact to ensure delivery
    final scheduleMode = await _preferredScheduleMode();
    await _fln.zonedSchedule(
      id,
      title,
      body,
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel?.id ?? 'reminders_high',
          _channel?.name ?? 'Reminders (High)',
          channelDescription: _channel?.description,
          priority: Priority.high,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  // ------------------ CANCEL ------------------
  Future<void> cancel(int id) => _fln.cancel(id);
  Future<void> cancelAll() => _fln.cancelAll();

  // ------------------ ANDROID EXACT ALARM HANDLING ------------------
  Future<AndroidScheduleMode> _preferredScheduleMode() async {
    try {
      // If exact alarm permission is granted on Android 12+, use exact+idle
      final exactStatus = await Permission.scheduleExactAlarm.status;
      if (exactStatus.isGranted) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // If checking permission fails (iOS/web), fall through to inexact
    }
    return AndroidScheduleMode.inexact;
  }

  // ------------------ RESCHEDULE ALL (Tasks + Habits) ------------------
  Future<void> rescheduleAllFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Tasks
      final tasksRaw = prefs.getString('tasks') ?? '[]';
      final tasks = (jsonDecode(tasksRaw) as List).cast<Map<String, dynamic>>();
      for (final t in tasks) {
        final id = (t['id'] ?? DateTime.now().millisecondsSinceEpoch) as int;
        final rh = t['reminderHour'] as int?;
        final rm = t['reminderMinute'] as int?;
        final title = (t['title'] ?? 'Task') as String;
        if (rh != null && rm != null) {
          await scheduleDaily(
            id: id,
            time: TimeOfDay(hour: rh, minute: rm),
            title: 'Task reminder',
            body: title,
          );
        }
      }

      // Habits
      final habitsRaw = prefs.getString('habits') ?? '[]';
      final habits = (jsonDecode(habitsRaw) as List)
          .cast<Map<String, dynamic>>();
      for (final h in habits) {
        final id = (h['id'] ?? DateTime.now().millisecondsSinceEpoch) as int;
        final rh = h['reminderHour'] as int?;
        final rm = h['reminderMinute'] as int?;
        final title = (h['title'] ?? 'Habit') as String;
        if (rh != null && rm != null) {
          await scheduleDaily(
            id: id,
            time: TimeOfDay(hour: rh, minute: rm),
            title: 'Habit reminder',
            body: title,
          );
        }
      }

      _log('Reschedule completed');
    } catch (e) {
      _log('Reschedule error: $e');
    }
  }
}
