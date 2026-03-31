import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'tools/fix_reset_scaletta.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ Reset totale della scaletta (UNA SOLA VOLTA)
  await ScalettaReset.reset();

  runApp(const MySongBookApp());
}

class MySongBookApp extends StatelessWidget {
  const MySongBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MySongBook",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: "Roboto",
        useMaterial3: false,
      ),
      home: const SplashScreen(),
    );
  }
}