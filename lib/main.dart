import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/attendance_provider.dart';
import 'ui/screens/auth/auth_wrapper.dart';
import 'utils/app_theme.dart';

void main() {
  // It's good practice to ensure Flutter bindings are initialized
  // especially before running any async code before runApp
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Using MultiProvider to make providers available to the entire widget tree
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: MaterialApp(
        title: 'Face Attendance App',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}
