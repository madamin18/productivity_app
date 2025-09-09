class Habit {
  final int id; // unique, used for notifications
  String title;
  int streak; // consecutive days
  DateTime? lastCheckedDate; // date-only
  int? reminderHour; // 0–23
  int? reminderMinute; // 0–59

  Habit({
    required this.id,
    required this.title,
    this.streak = 0,
    this.lastCheckedDate,
    this.reminderHour,
    this.reminderMinute,
  });

  factory Habit.fromMap(Map<String, dynamic> m) => Habit(
    id: (m['id'] ?? DateTime.now().millisecondsSinceEpoch) as int,
    title: m['title'] as String,
    streak: (m['streak'] ?? 0) as int,
    lastCheckedDate: m['lastCheckedDate'] != null
        ? DateTime.parse(m['lastCheckedDate'])
        : null,
    reminderHour: m['reminderHour'] as int?,
    reminderMinute: m['reminderMinute'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'streak': streak,
    'lastCheckedDate': lastCheckedDate?.toIso8601String(),
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
  };
}
