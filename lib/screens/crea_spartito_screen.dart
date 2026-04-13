import 'package:flutter/material.dart';
import '../services/parser_service.dart';

import 'anteprima_spartito_screen.dart';
import 'scaletta_screen.dart';
import 'nuovo_spartito_screen.dart';
import 'bozze_screen.dart';
import 'live/live_screen.dart';

class CreaSpartitoScreen extends StatefulWidget {
  const CreaSpartitoScreen({super.key});

  @override
  State<CreaSpartitoScreen> createState() => _CreaSpartitoScreenState();
}

class _CreaSpartitoScreenState extends State<CreaSpartitoScreen> {
  final TextEditingController _controller = TextEditingController();

  String titolo = "";
  String artista = "";
  String testoOriginale = "";

  bool avviaAttivo = false;
  bool generaAttivo = false;

  Future<void> _avviaElaborazione() async {
    final link = _controller.text.trim();
    if (link.isEmpty) return;

    final dati = await ParserService.estraiDaLink(link);

    setState(() {
      titolo = dati["titolo"] ?? "";
      artista = dati["artista"] ?? "";
      testoOriginale = dati["testo"] ?? "";
      generaAttivo = testoOriginale.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),
      body: Column(
        children: [
          // HEADER NERO CON LOGO + TASTO +
          Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 70,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      "assets/images/logo_horizontal.png",
                      height: 28,
                    ),
                    Positioned(
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NuovoSpartitoScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ⭐ SOTTOMENU COMPLETO (crea spartito | scaletta | bozze | live)
          Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // CREA SPARTITO (attivo)
                const Text(
                  "crea spartito",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 24),

                // SCALETTA
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const ScalettaScreen(),
                        transitionDuration: const Duration(milliseconds: 300),
                        transitionsBuilder: (_, animation, __, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: Text(
                    "scaletta",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // BOZZE
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const BozzeScreen(),
                        transitionDuration: const Duration(milliseconds: 300),
                        transitionsBuilder: (_, animation, __, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: Text(
                    "bozze",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // LIVE
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const LiveScreen(),
                        transitionDuration: const Duration(milliseconds: 300),
                        transitionsBuilder: (_, animation, __, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: Text(
                    "live",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // BOX LINK
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text("Incolla qui il Link", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  onChanged: (value) {
                    setState(() {
                      avviaAttivo = value.trim().isNotEmpty;
                    });
                  },
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    hintText: "https://...",
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // PULSANTE AVVIA
          GestureDetector(
            onTap: avviaAttivo ? _avviaElaborazione : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: avviaAttivo
                    ? Colors.black
                    : Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "AVVIA",
                style: TextStyle(
                  color: avviaAttivo ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // TITOLO + ARTISTA
          if (titolo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                titolo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (artista.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                artista,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),

          const Spacer(),

          // PULSANTE GENERA SPARTITO
          GestureDetector(
            onTap: generaAttivo
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnteprimaSpartitoScreen(
                          titolo: titolo,
                          artista: artista,
                          testoOriginale: testoOriginale,
                          trasposizioneIniziale: 0,
                        ),
                      ),
                    );
                  }
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: generaAttivo
                    ? const Color(0xFFFFC107)
                    : const Color(0xFFFFC107).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "GENERA SPARTITO",
                style: TextStyle(
                  color: generaAttivo ? Colors.black : Colors.black38,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
