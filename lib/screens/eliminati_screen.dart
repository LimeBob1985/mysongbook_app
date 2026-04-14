import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_storage_service.dart';

// SCHERMATE PRINCIPALI
import 'crea_spartito_screen.dart';
import 'scaletta_screen.dart';
import 'bozze_screen.dart';
import 'live/live_screen.dart';


class EliminatiScreen extends StatefulWidget {
  const EliminatiScreen({super.key});

  @override
  State<EliminatiScreen> createState() => _EliminatiScreenState();
}

class _EliminatiScreenState extends State<EliminatiScreen> {
  List<Map<String, dynamic>> eliminati = [];

  @override
  void initState() {
    super.initState();
    _caricaEliminati();
  }

  // Funzione di navigazione rapida (Fade) specifica per iOS/iPadOS
  void _nav(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: const Duration(milliseconds: 200), // Molto rapida
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _caricaEliminati() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList("eliminati") ?? [];

    setState(() {
      eliminati = lista
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();

      eliminati.sort((a, b) =>
          (a["titolo"] ?? "").toString().compareTo((b["titolo"] ?? "").toString()));
    });
  }

  // RIPRISTINO (torna in scaletta)
  Future<void> _ripristinaBrano(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brano = eliminati[index];

      setState(() {
        eliminati.removeAt(index);
      });

      await prefs.setStringList(
        "eliminati",
        eliminati.map((e) => jsonEncode(e)).toList(),
      );

      final listaScaletta = prefs.getStringList("scaletta") ?? [];
      List<Map<String, dynamic>> scaletta =
          listaScaletta.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

      scaletta.add(brano);
      scaletta.sort((a, b) =>
          (a["titolo"] ?? "").toString().compareTo((b["titolo"] ?? "").toString()));

      await prefs.setStringList(
        "scaletta",
        scaletta.map((e) => jsonEncode(e)).toList(),
      );

      debugPrint("Brano ripristinato correttamente.");
    } catch (e) {
      debugPrint("Errore ripristino: $e");
    }
  }

  // ELIMINAZIONE DEFINITIVA
  Future<void> _eliminaDefinitivamente(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brano = eliminati[index];

      await FileStorageService.deleteSong(brano);

      setState(() {
        eliminati.removeAt(index);
      });

      final listaScaletta = prefs.getStringList("scaletta") ?? [];
      List<Map<String, dynamic>> scaletta =
          listaScaletta.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

      scaletta.removeWhere((s) =>
          s["titolo"] == brano["titolo"] && s["artista"] == brano["artista"]);

      await prefs.setStringList(
        "scaletta",
        scaletta.map((e) => jsonEncode(e)).toList(),
      );

      final listaBozze = prefs.getStringList("bozze") ?? [];
      List<Map<String, dynamic>> bozze =
          listaBozze.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

      bozze.removeWhere((s) =>
          s["titolo"] == brano["titolo"] && s["artista"] == brano["artista"]);

      await prefs.setStringList(
        "bozze",
        bozze.map((e) => jsonEncode(e)).toList(),
      );

      await prefs.setStringList(
        "eliminati",
        eliminati.map((e) => jsonEncode(e)).toList(),
      );

      debugPrint("Brano eliminato definitivamente.");
    } catch (e) {
      debugPrint("Errore eliminazione definitiva: $e");
    }
  }

  Future<void> _confermaEliminazione(int index) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF212121),
          title: const Text("Eliminare definitivamente?",
              style: TextStyle(color: Colors.white)),
          content: const Text("Questa operazione non può essere annullata.",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annulla",
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Elimina",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (conferma == true) {
      await _eliminaDefinitivamente(index);
    }
  }

  Future<void> _svuotaCestino() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF212121),
          title: const Text("Svuotare il cestino?",
              style: TextStyle(color: Colors.white)),
          content: const Text(
              "Tutti i brani eliminati saranno rimossi definitivamente.",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annulla",
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "SVUOTA",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (conferma == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final brano in eliminati) {
          await FileStorageService.deleteSong(brano);
        }
        await prefs.setStringList("eliminati", []);
        setState(() {
          eliminati.clear();
        });
      } catch (e) {
        debugPrint("Errore svuotamento cestino: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),
      body: Column(
        children: [
          Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 70,
                alignment: Alignment.center,
                child: const Text(
                  "ELIMINATI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

          // TAB BAR con navigazione Fade rapida
          Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _nav(const CreaSpartitoScreen()),
                  child: Text(
                    "crea spartito",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                GestureDetector(
                  onTap: () => _nav(const ScalettaScreen()),
                  child: Text(
                    "scaletta",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                GestureDetector(
                  onTap: () => _nav(const BozzeScreen()),
                  child: Text(
                    "bozze",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                GestureDetector(
                  onTap: () => _nav(const LiveScreen()),
                  child: Text(
                    "live",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: eliminati.isEmpty
                ? const Center(
                    child: Text("Cestino vuoto",
                        style: TextStyle(color: Colors.white38, fontSize: 16)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: eliminati.length,
                    itemBuilder: (context, index) {
                      final brano = eliminati[index];

                      return Dismissible(
                        key: UniqueKey(),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          color: Colors.green,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restore,
                                  color: Colors.white, size: 28),
                              SizedBox(height: 4),
                              Text("Ripristina",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_forever,
                                  color: Colors.white, size: 28),
                              SizedBox(height: 4),
                              Text("Elimina",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            await _ripristinaBrano(index);
                            return true;
                          } else {
                            await _confermaEliminazione(index);
                            return false;
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(brano["titolo"] ?? "Senza Titolo",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(brano["artista"] ?? "Artista sconosciuto",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

// FOOTER
          Container(
            width: double.infinity,
            color: Colors.grey.shade400,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SizedBox(
                  height: 28, // Altezza fissa per bloccare il posizionamento
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ELIMINATI: ${eliminati.length}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (eliminati.isNotEmpty)
                        GestureDetector(
                          onTap: _svuotaCestino,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "SVUOTA CESTINO",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
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