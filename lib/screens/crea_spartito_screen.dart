import 'package:flutter/material.dart';
import '../services/parser_service.dart';
import 'anteprima_spartito_screen.dart';
import 'scaletta_screen.dart';
import 'nuovo_spartito_screen.dart';
import 'bozze_screen.dart'; // Import aggiunto

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
          // TESTATA NERA (70px)
          Container(
            height: 70,
            width: double.infinity,
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  "assets/images/logo_horizontal.png",
                  height: 36,
                ),
                Positioned(
                  right: 8,
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

          // SOTTOMENU (50px)
          Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "crea spartito",
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScalettaScreen(),
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
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BozzeScreen(),
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
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: avviaAttivo ? _avviaElaborazione : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: avviaAttivo 
                      ? Colors.black 
                      : Colors.black.withOpacity(0.3),
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
          ),

          const SizedBox(height: 20),

          // TITOLO + ARTISTA
          if (titolo.isNotEmpty)
            Text(
              titolo,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          if (artista.isNotEmpty)
            Text(
              artista,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),

          const Spacer(),

          // PULSANTE GENERA SPARTITO
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
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
                      : const Color(0xFFFFC107).withOpacity(0.3),
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
          ),
        ],
      ),
    );
  }
}