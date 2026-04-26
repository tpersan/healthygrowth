import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';

/// Global notifier so any widget can change the app theme.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Restore saved preference before the first frame.
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('themeMode');
  if (saved == 'dark') {
    themeModeNotifier.value = ThemeMode.dark;
  } else if (saved == 'light') {
    themeModeNotifier.value = ThemeMode.light;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Health Growth',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: home ?? const AppShell(),
      ),
    );
  }
}
