import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_theme.dart';
import 'screens/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    MobileAds.instance.initialize(),
  ]);
  runApp(const UnderCloudsApp());
}

class UnderCloudsApp extends StatelessWidget {
  const UnderCloudsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      title: 'UnderClouds',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: kSheet,
        colorScheme: const ColorScheme.dark(
          primary: kGold,
          surface: kSheet,
          onSurface: kCream,
          error: kConfRed,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
          bodyColor: kCream,
          displayColor: kCream,
        ),
        cardTheme: const CardThemeData(color: kCardBg),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: kSheet,
          contentTextStyle: GoogleFonts.nunito(color: kCream),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kGold,
        ),
      ),
      home: const CameraScreen(),
    );
  }
}
