import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/focus_lock_provider.dart';
import 'core/providers/schedule_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/screens/main_navigation_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FocusLockApp());
}

class FocusLockApp extends StatelessWidget {
  const FocusLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FocusLockProvider>(
          create: (_) => FocusLockProvider(),
          update: (_, auth, focus) => (focus ?? FocusLockProvider())..setAuthToken(auth.token),
        ),
        ChangeNotifierProvider(
          create: (_) => ScheduleProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'FocusLock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainNavigationShell(),
      ),
    );
  }
}
