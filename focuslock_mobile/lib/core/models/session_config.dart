class PomodoroSessionConfig {
  final int focusMinutes;
  final int breakMinutes;
  final int breakCount;
  final int? focusSeconds;
  final int? breakSeconds;

  const PomodoroSessionConfig({
    required this.focusMinutes,
    required this.breakMinutes,
    this.breakCount = 1,
    this.focusSeconds,
    this.breakSeconds,
  });

  int get focusTotalSeconds => focusSeconds ?? (focusMinutes * 60);
  int get breakTotalSeconds => breakSeconds ?? (breakMinutes * 60);

  Map<String, dynamic> toJson() => {
        'focus_minutes': focusMinutes,
        'break_minutes': breakMinutes,
        'break_count': breakCount,
        if (focusSeconds != null) 'focus_seconds': focusSeconds,
        if (breakSeconds != null) 'break_seconds': breakSeconds,
      };

  factory PomodoroSessionConfig.fromJson(Map<String, dynamic> json) {
    return PomodoroSessionConfig(
      focusMinutes: json['focus_minutes'] as int? ?? 25,
      breakMinutes: json['break_minutes'] as int? ?? 5,
      breakCount: json['break_count'] as int? ?? 1,
      focusSeconds: json['focus_seconds'] as int?,
      breakSeconds: json['break_seconds'] as int?,
    );
  }
}
