import 'package:flutter/material.dart';
import 'screens/exam_list_screen.dart';
import 'services/app_settings.dart';
import 'services/entitlement_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await EntitlementService.instance.init();
  runApp(const OmrApp());
}

class OmrApp extends StatelessWidget {
  const OmrApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([settings, EntitlementService.instance]),
      builder: (context, _) {
        return MaterialApp(
          title: 'OMR Scanner',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
          ),
          home: const ExamListScreen(),
        );
      },
    );
  }
}
