class Task {
  final int id;
  String title;
  bool done;

  // (existing reminder fields can stay)
  int? reminderHour;
  int? reminderMinute;
  List<int>? weekdays;

  // ⬇️ NEW timer fields
  int totalSeconds; // accumulated worked seconds
  bool isRunning; // currently running?
  int? startedAtMs; // epoch ms when last started (null if not running)

  Task({
    required this.id,
    required this.title,
    this.done = false,
    this.reminderHour,
    this.reminderMinute,
    this.weekdays,
    this.totalSeconds = 0,
    this.isRunning = false,
    this.startedAtMs,
  });

  factory Task.fromMap(Map<String, dynamic> m) => Task(
    id: (m['id'] ?? DateTime.now().millisecondsSinceEpoch) as int,
    title: m['title'] as String,
    done: (m['done'] ?? false) as bool,
    reminderHour: m['reminderHour'] as int?,
    reminderMinute: m['reminderMinute'] as int?,
    weekdays: (m['weekdays'] as List?)?.cast<int>(),
    totalSeconds: (m['totalSeconds'] ?? 0) as int,
    isRunning: (m['isRunning'] ?? false) as bool,
    startedAtMs: m['startedAtMs'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'done': done,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'weekdays': weekdays,
    'totalSeconds': totalSeconds,
    'isRunning': isRunning,
    'startedAtMs': startedAtMs,
  };
}
