import 'package:flutter/material.dart';
import '../../features/navigation/presentation/screens/main_navigation_shell.dart';
import '../../features/pomodoro/presentation/screens/home_pomodoro_screen.dart';
import '../../features/connection/presentation/screens/connection_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../../features/metrics/presentation/screens/metrics_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String focus = '/focus';
  static const String schedule = '/schedule';
  static const String metrics = '/metrics';
  static const String profile = '/profile';
  static const String connection = '/connection';
  static const String history = '/history';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const MainNavigationShell(),
        focus: (_) => const HomePomodoroScreen(),
        schedule: (_) => const ScheduleScreen(),
        metrics: (_) => const MetricsScreen(),
        profile: (_) => const ProfileScreen(),
        connection: (_) => const ConnectionScreen(),
        history: (_) => const HistoryScreen(),
        settings: (_) => const SettingsScreen(),
      };
}
