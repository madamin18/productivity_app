import 'package:flutter/material.dart';
import 'package:productivity_app/services/notification_service.dart';
import 'second_page.dart';
import '../../tasks/pages/tasks_page.dart';
import '../../habits/pages/habits_page.dart';

class HomePage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const HomePage({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Productivity App"),
        actions: [
          IconButton(
            tooltip: 'Test notification',
            onPressed: () async {
              await NotificationService.instance.requestPermission();
              await NotificationService.instance.showNow(
                title: 'Hello from Productivity App',
                body: 'This is your test notification!',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test notification sent')),
              );
            },
            icon: const Icon(Icons.notifications),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HomeCard(
                  icon: Icons.checklist,
                  title: 'Tasks',
                  subtitle: 'Capture and complete your todos',
                  buttonText: 'Open Tasks',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TasksPage()),
                    );
                  },
                ),
                _HomeCard(
                  icon: Icons.local_fire_department,
                  title: 'Habits',
                  subtitle: 'Daily check-ins with streaks',
                  buttonText: 'Open Habits',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HabitsPage()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _HomeCard(
                  icon: Icons.explore,
                  title: 'Second Page',
                  subtitle: 'Example navigation screen',
                  buttonText: 'Go',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SecondPage()),
                    );
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.bolt),
                  label: const Text('Quick Action'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('You tapped a quick action!'),
                        backgroundColor: cs.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: onPressed, child: Text(buttonText)),
            ],
          ),
        ),
      ),
    );
  }
}
