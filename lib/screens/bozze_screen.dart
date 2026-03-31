import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crea_spartito_screen.dart';
import 'scaletta_screen.dart';
import 'componi_spartito_screen.dart';

class BozzeScreen extends StatefulWidget {
  const BozzeScreen({super.key});

  @override
  State<BozzeScreen> createState() => _BozzeScreenState();
}

class _BozzeScreenState extends State<BozzeScreen> {
  List<Map<String, dynamic>> bozze = [];
  List<Map<String, dynamic>> bozzeFiltrate = [];

  @override
  void initState() {
    super.initState();
    _caricaBozze();
  }

  Future<void> _caricaBozze() async {
    final prefs = await SharedPreferences.getInstance();
    final listaBozze = prefs.getStringList("bozze") ?? [];

    setState(() {
      bozze = listaBozze.map<Map<String, dynamic>>((e) => jsonDecode(e)).toList();
      
      // Ordina per titolo in modo alfabetico (case-insensitive)
      bozze.sort((a, b) {
        String titoloA = (a["titolo"] ?? "Senza Titolo").toString().toLowerCase();
        String titoloB = (b["titolo"] ?? "Senza Titolo").toString().toLowerCase();
        return titoloA.compareTo(titoloB);
      });
      
      bozzeFiltrate = List.from(bozze);
    });
  }

  // --- LOGICA DI ELIMINAZIONE AGGIORNATA PER PERSISTENZA IPHONE ---
  Future<void> _eliminaBozza(int indexFiltrato) async {
    try {
      final bozza = bozzeFiltrate[indexFiltrato];
      final prefs = await SharedPreferences.getInstance();
      
      // Carica eliminati esistenti per non sovrascriverli
      final listaEliminati = prefs.getStringList("eliminati") ?? [];
      List<Map<String, dynamic>> eliminati = listaEliminati.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

      setState(() {
        bozze.removeWhere((element) => element == bozza);
        bozzeFiltrate.removeAt(indexFiltrato);
        eliminati.add(bozza);
      });

      // Operazioni di salvataggio con await obbligatorio per iOS
      await prefs.setStringList("bozze", bozze.map((e) => jsonEncode(e)).toList());
      await prefs.setStringList("eliminati", eliminati.map((e) => jsonEncode(e)).toList());
      
      debugPrint("Bozze ed Eliminati aggiornati correttamente su disco.");
    } catch (e) {
      debugPrint("Errore durante l'eliminazione della bozza: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),
      body: Column(
        children: [
          // HEADER CON SCRITTA FISSA (Incluso in SafeArea per iOS)
          Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 70,
                width: double.infinity,
                alignment: Alignment.center,
                child: const Text(
                  "BOZZE",
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

          // MENU DI NAVIGAZIONE
          Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => const CreaSpartitoScreen())
                  ),
                  child: Text(
                    "crea spartito", 
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => const ScalettaScreen())
                  ),
                  child: Text(
                    "scaletta", 
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)
                  ),
                ),
                const SizedBox(width: 24),
                const Text(
                  "bozze", 
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),

          // LISTA BOZZE
          Expanded(
            child: bozzeFiltrate.isEmpty
                ? const Center(
                    child: Text(
                      "Nessuna bozza trovata",
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    itemCount: bozzeFiltrate.length,
                    itemBuilder: (context, index) {
                      final b = bozzeFiltrate[index];
                      return Dismissible(
                        key: UniqueKey(),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Text("ELIMINA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        onDismissed: (_) => _eliminaBozza(index),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Icon(Icons.edit_note, color: Colors.white),
                          ),
                          title: Text(b["titolo"] ?? "Senza Titolo", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(b["artista"] ?? "Artista sconosciuto", style: const TextStyle(color: Colors.white70)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ComponiSpartitoScreen(
                                  titolo: b["titolo"],
                                  artista: b["artista"],
                                  testoIniziale: b["testo_originale"] ?? b["testo"] ?? "",
                                  righeSalvate: b["righe"],
                                ),
                              ),
                            ).then((_) {
                              if (mounted) _caricaBozze();
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}