import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task.dart';
import '../../../services/notification_service.dart';
import 'dart:async';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _tasks = <Task>[];
  final _controller = TextEditingController();

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // If any task is running, refresh the UI time readout
      if (mounted && _tasks.any((t) => t.isRunning)) {
        setState(() {});
      }
    });
  }

  int _elapsedFor(Task t) {
    final base = t.totalSeconds;
    if (t.isRunning && t.startedAtMs != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final add = ((nowMs - t.startedAtMs!) ~/ 1000);
      return base + (add > 0 ? add : 0);
    }
    return base;
  }

  String _fmt(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tasks') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    setState(() {
      _tasks
        ..clear()
        ..addAll(list.map(Task.fromMap));
    });
  }

  Future<void> _startTimer(int index) async {
    final t = _tasks[index];
    if (t.isRunning) return;
    t.isRunning = true;
    t.startedAtMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {});
    await _saveTasks();
  }

  Future<void> _stopTimer(int index) async {
    final t = _tasks[index];
    if (!t.isRunning) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final add = ((nowMs - (t.startedAtMs ?? nowMs)) ~/ 1000);
    if (add > 0) t.totalSeconds += add;
    t.isRunning = false;
    t.startedAtMs = null;
    setState(() {});
    await _saveTasks();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_tasks.map((t) => t.toMap()).toList());
    await prefs.setString('tasks', raw);
  }

  Future<TimeOfDay?> _pickTime() async {
    final now = TimeOfDay.now();
    return showTimePicker(context: context, initialTime: now);
  }

  Future<void> _scheduleIfNeeded(Task t) async {
    if (t.reminderHour == null || t.reminderMinute == null) return;

    final tod = TimeOfDay(hour: t.reminderHour!, minute: t.reminderMinute!);

    // Booster for TODAY (if within next 15 minutes)
    final secs = NotificationService.instance.secondsUntilToday(tod);
    if (secs > 0 && secs <= 15 * 60) {
      await NotificationService.instance.scheduleSmartSeconds(
        id: NotificationService.instance.boosterId(t.id), // <-- use booster id
        seconds: secs,
        title: 'Task reminder',
        body: t.title,
      );
    }

    // Daily repeating schedule (keeps original id)
    await NotificationService.instance.scheduleDailyInexact(
      id: t.id,
      time: tod,
      title: 'Task reminder',
      body: t.title,
    );
  }

  Future<void> _cancelReminder(Task t) async {
    await NotificationService.instance.cancel(t.id);
    await NotificationService.instance.cancel(
      NotificationService.instance.boosterId(t.id),
    ); // <-- also booster
  }

  Future<void> _addTask() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Ask for optional reminder time
    final picked = await _pickTime();

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch,
      title: text,
      done: false,
      reminderHour: picked?.hour,
      reminderMinute: picked?.minute,
    );

    setState(() {
      _tasks.add(newTask);
      _controller.clear();
    });

    await _saveTasks();
    await NotificationService.instance.requestPermission();
    await _scheduleIfNeeded(newTask);
  }

  void _toggle(int index, bool? value) async {
    setState(() => _tasks[index].done = value ?? false);
    await _saveTasks();
    // (Design choice) we keep reminders even if task is done; or cancel:
    // if (_tasks[index].done) await _cancelReminder(_tasks[index]);
  }

  Future<void> _remove(int index) async {
    final t = _tasks[index];
    setState(() => _tasks.removeAt(index));
    await _saveTasks();
    await _cancelReminder(t);
  }

  // Optional: long-press to (re)assign a reminder time or clear it
  Future<void> _editReminder(int index) async {
    final picked = await _pickTime();
    final t = _tasks[index];

    if (picked == null) {
      // Clear reminder
      t.reminderHour = null;
      t.reminderMinute = null;
      await NotificationService.instance.cancel(t.id); // remove any pending
    } else {
      // Update reminder time
      t.reminderHour = picked.hour;
      t.reminderMinute = picked.minute;

      await NotificationService.instance.requestPermission();

      // Cancel any previous schedule for this task id to avoid duplicates
      await NotificationService.instance.cancel(t.id);

      // Booster: if today's chosen time is within next 15 minutes, fire once today
      final secs = NotificationService.instance.secondsUntilToday(picked);
      if (secs > 0 && secs <= 15 * 60) {
        await NotificationService.instance.scheduleSmartSeconds(
          id: t.id,
          seconds: secs,
          title: 'Task reminder',
          body: t.title,
        );
      }

      // Always (re)schedule the daily repeating reminder
      await NotificationService.instance.scheduleDailyInexact(
        id: t.id,
        time: picked,
        title: 'Task reminder',
        body: t.title,
      );
    }

    setState(() {});
    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
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
                      hintText: 'Add a new task… (time optional)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addTask, child: const Text('Add')),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(child: Text('No tasks yet'))
                : ListView.separated(
                    itemCount: _tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final t = _tasks[i];
                      final hasReminder =
                          t.reminderHour != null && t.reminderMinute != null;
                      final reminderLabel = hasReminder
                          ? ' ⏰ ${t.reminderHour!.toString().padLeft(2, '0')}:${t.reminderMinute!.toString().padLeft(2, '0')}'
                          : '';

                      return Dismissible(
                        key: ValueKey('${t.id}-$i'),
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
                        onDismissed: (_) => _remove(i),
                        child: ListTile(
                          // Tap the row to start/stop the timer
                          onTap: () =>
                              t.isRunning ? _stopTimer(i) : _startTimer(i),

                          title: Text(
                            t.title,
                            style: t.done
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),

                          // Live-updating elapsed time (uses _fmt + _elapsedFor helpers)
                          subtitle: Text(
                            'Worked: ${_fmt(_elapsedFor(t))}${t.isRunning ? ' • running…' : ''}',
                          ),

                          // Controls: play/stop + done checkbox
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: t.isRunning
                                    ? 'Stop timer'
                                    : 'Start timer',
                                icon: Icon(
                                  t.isRunning ? Icons.stop : Icons.play_arrow,
                                ),
                                onPressed: () => t.isRunning
                                    ? _stopTimer(i)
                                    : _startTimer(i),
                              ),
                              Checkbox(
                                value: t.done,
                                onChanged: (v) => _toggle(i, v),
                              ),
                            ],
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
