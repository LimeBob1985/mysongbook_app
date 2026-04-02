import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'screens/splash_screen.dart';

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
      // Questi delegati dicono a Flutter come tradurre i widget nativi (bottoni, menu, tasto incolla)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'), // Italiano
      ],
      // Forza l'app a usare l'italiano indipendentemente dalla lingua del telefono
      locale: const Locale('it', 'IT'), 
      // ---------------------------------------

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: "Roboto",
        useMaterial3: false, // Mantieni false se preferisci lo stile classico
      ),
      home: const SplashScreen(),
    );
  }
}