import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/chord_utils.dart';
import 'scaletta_screen.dart';

class AnteprimaSpartitoScreen extends StatefulWidget {
  final String titolo;
  final String artista;
  final String testoCompleto;

  const AnteprimaSpartitoScreen({
    super.key,
    required this.titolo,
    required this.artista,
    required this.testoCompleto,
  });

  @override
  State<AnteprimaSpartitoScreen> createState() => _AnteprimaSpartitoScreenState();
}

class _AnteprimaSpartitoScreenState extends State<AnteprimaSpartitoScreen> {
  int trasposizione = 0;
  late String testoTrasposto;

  @override
  void initState() {
    super.initState();
    testoTrasposto = widget.testoCompleto;
  }

  void _trasponi(int delta) {
    setState(() {
      trasposizione += delta;
      testoTrasposto = ChordUtils.transposeSong(widget.testoCompleto, trasposizione);
    });
  }

  Future<void> _salvaInScaletta() async {
    final prefs = await SharedPreferences.getInstance();

    final lista = prefs.getStringList("scaletta") ?? [];

    final nuovo = "${widget.titolo}|||${widget.artista}|||$testoTrasposto";

    if (!lista.contains(nuovo)) {
      lista.add(nuovo);
    }

    lista.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    await prefs.setStringList("scaletta", lista);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ScalettaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final righe = testoTrasposto.split("\n");

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // HEADER NERO
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

          // BARRA GRIGIA CON TONO + SALVA
          Container(
            width: double.infinity,
            color: const Color(0xFFE6E6E6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // TONO
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _trasponi(-1),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade700,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "-",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Abbassa di 1/2 tono",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    GestureDetector(
                      onTap: () => _trasponi(1),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "+",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Alza di 1/2 tono",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // SALVA IN SCALETTA
                GestureDetector(
                  onTap: _salvaInScaletta,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "SALVA IN SCALETTA",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // CONTENUTO SCROLLABILE
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITOLO
                  Text(
                    widget.titolo,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ARTISTA
                  Text(
                    widget.artista.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // TESTO + ACCORDI
                  for (final riga in righe) ...[
                    if (ChordUtils.chordRegex.hasMatch(riga)) ...[
                      Builder(
                        builder: (_) {
                          final parts = ChordUtils.splitLine(riga);
                          final accordi = parts["accordi"] ?? "";
                          final testo = parts["testo"] ?? "";

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (accordi.trim().isNotEmpty)
                                Text(
                                  accordi,
                                  style: const TextStyle(
                                    fontFamily: "RobotoMono",
                                    fontSize: 16,
                                    height: 1.3,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              if (testo.trim().isNotEmpty)
                                Text(
                                  testo,
                                  style: const TextStyle(
                                    fontFamily: "RobotoMono",
                                    fontSize: 16,
                                    height: 1.3,
                                    color: Colors.black,
                                  ),
                                ),
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      Text(
                        riga,
                        style: const TextStyle(
                          fontFamily: "RobotoMono",
                          fontSize: 16,
                          height: 1.3,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
