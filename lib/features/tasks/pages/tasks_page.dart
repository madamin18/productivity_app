import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _tasks = <Task>[];
  final _controller = TextEditingController();

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('tasks') ?? '[]';
    final list = jsonDecode(data) as List;
    setState(() {
      _tasks.clear();
      _tasks.addAll(list.map((e) => Task(title: e['title'], done: e['done'])));
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(
      _tasks.map((t) => {'title': t.title, 'done': t.done}).toList(),
    );
    await prefs.setString('tasks', data);
  }

  void _addTask() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _tasks.add(Task(title: text));
      _controller.clear();
    });
    _saveTasks();
  }

  void _toggle(int index, bool? value) {
    setState(() {
      _tasks[index].done = value ?? false;
    });
    _saveTasks();
  }

  void _remove(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
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
                      hintText: 'Add a new task...',
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
                      return Dismissible(
                        key: ValueKey('${t.title}-$i'),
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
                        child: CheckboxListTile(
                          title: Text(
                            t.title,
                            style: t.done
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                          value: t.done,
                          onChanged: (v) => _toggle(i, v),
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
