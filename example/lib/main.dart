import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:widget_capture_x_plus_example/recording_demo_page_platform.dart';
import 'package:widget_capture_x_plus_example/recording_demo_page_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WidgetCaptureX Recording Demo',
      theme: ThemeData(
        primarySwatch: Colors.indigo, // Changed theme color for variety
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigoAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: kIsWeb ? RecordingDemoPageWeb() : RecordingDemoPage(),
    );
  }
}
