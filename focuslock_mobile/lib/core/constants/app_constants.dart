class AppConstants {
  static const String appName = 'FocusLock';
  static const String appVersion = '1.0.0';

  // Network defaults (IP directa de tu Raspberry Pi 4)
  static const String defaultMdnsHost = '192.168.43.59';
  static const int defaultPort = 8000;
  static const String prefHostKey = 'focuslock_saved_host';

  // Pomodoro Defaults (in minutes)
  static const int defaultFocusMinutes = 25;
  static const int defaultBreakMinutes = 5;
  static const int gracePeriodSeconds = 5;
  static const int insertionTimeoutSeconds = 30;
}

