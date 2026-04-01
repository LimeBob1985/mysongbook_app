import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Aggiunto per le traduzioni
import 'screens/splash_screen.dart';
import 'tools/fix_reset_scaletta.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ Reset totale della scaletta rimosso per permettere il salvataggio dei brani
  // await ScalettaReset.reset();

  runApp(const MySongBookApp());
}

class MySongBookApp extends StatelessWidget {
  const MySongBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MySongBook",
      debugShowCheckedModeBanner: false,
      
      // --- CONFIGURAZIONE LINGUA ITALIANA ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
      ],
      locale: const Locale('it', 'IT'),
      // ---------------------------------------

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: "Roboto",
        useMaterial3: false,
      ),
      home: const SplashScreen(),
    );
  }
}