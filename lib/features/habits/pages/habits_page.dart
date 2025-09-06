import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

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

  // -------- Persistence ----------
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

  // -------- Helpers ----------
  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isYesterday(DateTime a, DateTime b) {
    // returns true if 'a' is exactly one day before 'b' (date-only)
    final ay = DateTime(a.year, a.month, a.day);
    final by = DateTime(b.year, b.month, b.day);
    return ay.add(const Duration(days: 1)) == by;
  }

  // -------- Actions ----------
  void _addHabit() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _habits.add(Habit(title: t));
      _controller.clear();
    });
    _save();
  }

  void _deleteHabit(int i) {
    setState(() => _habits.removeAt(i));
    _save();
  }

  void _checkInToday(int i) {
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    final h = _habits[i];

    // If already checked today, do nothing
    if (h.lastCheckedDate != null && _isSameDate(h.lastCheckedDate!, todayD)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already checked in today')));
      return;
    }

    // Streak rules
    if (h.lastCheckedDate == null) {
      h.streak = 1;
    } else if (_isYesterday(h.lastCheckedDate!, todayD)) {
      h.streak += 1; // continued streak
    } else if (_isSameDate(h.lastCheckedDate!, todayD)) {
      // already handled above
    } else {
      h.streak = 1; // missed a day -> reset to 1
    }

    h.lastCheckedDate = todayD;

    setState(() {});
    _save();
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

                      return Dismissible(
                        key: ValueKey('${h.title}-$i'),
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
                        onDismissed: (_) => _deleteHabit(i),
                        child: ListTile(
                          title: Text(h.title),
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
