import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔵 Nessun WebService, nessun Bonsoir, nessuna rete.
  // Il nuovo sistema usa solo la cartella locale.
  print("MySongBook avviato. Caricamento da cartella locale attivo.");

  runApp(const MySongBookApp());
}

class MySongBookApp extends StatelessWidget {
  const MySongBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MySongBook",
      debugShowCheckedModeBanner: false,

      // --- LOCALIZZAZIONE ITALIANA ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
      ],
      locale: const Locale('it', 'IT'),

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: "Roboto",
        useMaterial3: false,
      ),

      home: const SplashScreen(),
    );
  }
}
