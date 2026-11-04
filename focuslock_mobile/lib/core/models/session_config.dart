class PomodoroSessionConfig {
  final int focusMinutes;
  final int breakMinutes;

  const PomodoroSessionConfig({
    required this.focusMinutes,
    required this.breakMinutes,
  });

  int get focusTotalSeconds => focusMinutes * 60;
  int get breakTotalSeconds => breakMinutes * 60;

  Map<String, dynamic> toJson() => {
    'focus_minutes': focusMinutes,
    'break_minutes': breakMinutes,
  };

  factory PomodoroSessionConfig.fromJson(Map<String, dynamic> json) {
    return PomodoroSessionConfig(
      focusMinutes: json['focus_minutes'] as int? ?? 25,
      breakMinutes: json['break_minutes'] as int? ?? 5,
    );
  }
}

