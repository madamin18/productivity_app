import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../../../services/notification_service.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});
  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final _habits = <Habit>[];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------- Persistence ----------
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('habits') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    setState(() {
      _habits
        ..clear()
        ..addAll(list.map(Habit.fromMap));
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_habits.map((h) => h.toMap()).toList());
    await prefs.setString('habits', raw);
  }

  // ---------- Time & Notifications ----------
  Future<TimeOfDay?> _pickTime() async {
    final now = TimeOfDay.now();
    return showTimePicker(context: context, initialTime: now);
  }

  Future<void> _scheduleIfNeeded(Habit h) async {
    if (h.reminderHour == null || h.reminderMinute == null) return;

    final tod = TimeOfDay(hour: h.reminderHour!, minute: h.reminderMinute!);

    final secs = NotificationService.instance.secondsUntilToday(tod);
    if (secs > 0 && secs <= 15 * 60) {
      await NotificationService.instance.scheduleSmartSeconds(
        id: NotificationService.instance.boosterId(h.id), // <-- booster id
        seconds: secs,
        title: 'Habit reminder',
        body: h.title,
      );
    }

    await NotificationService.instance.scheduleDailyInexact(
      id: h.id,
      time: tod,
      title: 'Habit reminder',
      body: h.title,
    );
  }

  Future<void> _cancelReminder(Habit h) async {
    await NotificationService.instance.cancel(h.id);
    await NotificationService.instance.cancel(
      NotificationService.instance.boosterId(h.id),
    );
  }

  // ---------- Actions ----------
  void _addHabit() async {
    final t = _controller.text.trim();
    if (t.isEmpty) return;

    final picked = await _pickTime(); // optional reminder time
    final newHabit = Habit(
      id: DateTime.now().millisecondsSinceEpoch,
      title: t,
      streak: 0,
      lastCheckedDate: null,
      reminderHour: picked?.hour,
      reminderMinute: picked?.minute,
    );

    setState(() {
      _habits.add(newHabit);
      _controller.clear();
    });

    await _save();
    if (!mounted) return;
    await NotificationService.instance.ensurePermissionsWithSettingsPrompt(
      context,
    );
    await _scheduleIfNeeded(newHabit);
  }

  void _deleteHabit(int i) async {
    final h = _habits[i];
    setState(() => _habits.removeAt(i));
    await _save();
    await _cancelReminder(h);
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isYesterday(DateTime a, DateTime b) {
    final ay = DateTime(a.year, a.month, a.day);
    final by = DateTime(b.year, b.month, b.day);
    return ay.add(const Duration(days: 1)) == by;
  }

  void _checkInToday(int i) async {
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    final h = _habits[i];

    if (h.lastCheckedDate != null && _isSameDate(h.lastCheckedDate!, todayD)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already checked in today')));
      return;
    }

    if (h.lastCheckedDate == null) {
      h.streak = 1;
    } else if (_isYesterday(h.lastCheckedDate!, todayD)) {
      h.streak += 1;
    } else {
      h.streak = 1;
    }
    h.lastCheckedDate = todayD;

    setState(() {});
    await _save();
  }

  // Optional: long-press to set/change/clear reminder
  Future<void> _editReminder(int index) async {
    final picked = await _pickTime();
    final h = _habits[index];

    if (picked == null) {
      // Clear reminder
      h.reminderHour = null;
      h.reminderMinute = null;
      await NotificationService.instance.cancel(h.id); // remove any pending
    } else {
      // Update reminder time
      h.reminderHour = picked.hour;
      h.reminderMinute = picked.minute;

      await NotificationService.instance.requestPermission();

      // Cancel any previous schedule for this habit id to avoid duplicates
      await NotificationService.instance.cancel(h.id);

      // Booster: if today's chosen time is within next 15 minutes, fire once today
      final secs = NotificationService.instance.secondsUntilToday(picked);
      if (secs > 0 && secs <= 15 * 60) {
        await NotificationService.instance.scheduleSmartSeconds(
          id: h.id,
          seconds: secs,
          title: 'Habit reminder',
          body: h.title,
        );
      }

      // Always (re)schedule the daily repeating reminder
      await NotificationService.instance.scheduleDailyInexact(
        id: h.id,
        time: picked,
        title: 'Habit reminder',
        body: h.title,
      );
    }

    setState(() {});
    await _save();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Add a habit (e.g., Read 20 mins)',
                    ),
                    onSubmitted: (_) => _addHabit(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addHabit, child: const Text('Add')),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: _habits.isEmpty
                ? const Center(child: Text('No habits yet'))
                : ListView.separated(
                    itemCount: _habits.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final h = _habits[i];
                      final last = h.lastCheckedDate != null
                          ? '${h.lastCheckedDate!.year}-${h.lastCheckedDate!.month.toString().padLeft(2, '0')}-${h.lastCheckedDate!.day.toString().padLeft(2, '0')}'
                          : '—';
                      final hasReminder =
                          h.reminderHour != null && h.reminderMinute != null;
                      final reminderLabel = hasReminder
                          ? ' ⏰ ${h.reminderHour!.toString().padLeft(2, '0')}:${h.reminderMinute!.toString().padLeft(2, '0')}'
                          : '';

                      return Dismissible(
                        key: ValueKey('${h.id}-$i'),
                        onDismissed: (_) => _deleteHabit(i),
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 16),
                          child: const Icon(Icons.delete),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete),
                        ),
                        child: ListTile(
                          onLongPress: () => _editReminder(i),
                          title: Text('${h.title}$reminderLabel'),
                          subtitle: Text(
                            'Streak: ${h.streak}   •   Last: $last',
                          ),
                          trailing: FilledButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Today'),
                            onPressed: () => _checkInToday(i),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
