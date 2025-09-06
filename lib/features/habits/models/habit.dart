class Habit {
  String title;
  int streak; // consecutive days
  DateTime? lastCheckedDate; // last day user checked in (date only)

  Habit({required this.title, this.streak = 0, this.lastCheckedDate});

  factory Habit.fromMap(Map<String, dynamic> m) => Habit(
    title: m['title'] as String,
    streak: m['streak'] as int,
    lastCheckedDate: m['lastCheckedDate'] != null
        ? DateTime.parse(m['lastCheckedDate'])
        : null,
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'streak': streak,
    'lastCheckedDate': lastCheckedDate?.toIso8601String(),
  };
}
