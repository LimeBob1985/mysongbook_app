import 'package:flutter/material.dart';
import '../utils/chord_utils.dart'; // Importato per usare la logica di controllo

class VisualizzaSpartitoScreen extends StatelessWidget {
  final String titolo;
  final String artista;
  final String testo;

  const VisualizzaSpartitoScreen({
    super.key,
    required this.titolo,
    required this.artista,
    required this.testo,
  });

  @override
  Widget build(BuildContext context) {
    final righe = testo.split("\n");

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 70,
            width: double.infinity,
            color: Colors.black,
            alignment: Alignment.center,
            child: Image.asset(
              "assets/images/logo_horizontal.png",
              height: 36,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    artista.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  for (final riga in righe) ...[
                    Text(
                      riga,
                      style: TextStyle(
                        fontFamily: "RobotoMono",
                        fontSize: 16,
                        height: 1.3,
                        color: Colors.black,
                        // ⭐ LOGICA DINAMICA RAFFORZATA:
                        // Se la riga è vuota o troppo lunga (testo), niente grassetto.
                        fontWeight: (riga.trim().isNotEmpty && 
                                     riga.length < 50 && 
                                     ChordUtils.isPureChordLine(riga)) 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}