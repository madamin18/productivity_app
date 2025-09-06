import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'features/home/pages/home_page.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init(); // now safe (won’t crash)
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  ThemeMode _mode = ThemeMode.system;
  void _toggleTheme() {
    setState(() {
      _mode = (_mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Productivity App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      home: HomePage(onToggleTheme: _toggleTheme, themeMode: _mode),
    );
  }
}
