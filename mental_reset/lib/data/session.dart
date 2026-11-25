/// Сущность темы: сессия осознанности, созданная пользователем.
class MindfulSession {
  final String id;
  final String title;
  final String practiceType; // breathe | meditation | timer | canvas
  final int durationMin;
  final String notes;
  final bool soundEnabled;
  final DateTime createdAt;

  const MindfulSession({
    required this.id,
    required this.title,
    required this.practiceType,
    required this.durationMin,
    required this.notes,
    required this.soundEnabled,
    required this.createdAt,
  });

  factory MindfulSession.fromJson(Map<String, dynamic> j) => MindfulSession(
        id: '${j['id']}',
        title: j['title'] as String,
        practiceType: j['practiceType'] as String,
        durationMin: j['durationMin'] as int,
        notes: (j['notes'] as String?) ?? '',
        soundEnabled: (j['soundEnabled'] as bool?) ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );

  /// Тело запроса POST/PUT: id и createdAt назначает сервер.
  Map<String, dynamic> toJson() => {
        'title': title,
        'practiceType': practiceType,
        'durationMin': durationMin,
        'notes': notes,
        'soundEnabled': soundEnabled,
      };

  MindfulSession copyWith({
    String? title,
    String? practiceType,
    int? durationMin,
    String? notes,
    bool? soundEnabled,
  }) =>
      MindfulSession(
        id: id,
        title: title ?? this.title,
        practiceType: practiceType ?? this.practiceType,
        durationMin: durationMin ?? this.durationMin,
        notes: notes ?? this.notes,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        createdAt: createdAt,
      );
}

const practiceTypeLabels = {
  'breathe': 'Дыхание (Breathe 4-7-8)',
  'meditation': 'Медитация спокойствия',
  'timer': 'Таймер фокуса (Pomodoro)',
  'canvas': 'Арт-терапия (Calm Canvas)',
};
