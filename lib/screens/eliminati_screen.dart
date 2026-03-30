import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crea_spartito_screen.dart';
import 'scaletta_screen.dart';
import 'bozze_screen.dart';

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

  Future<void> _caricaEliminati() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList("eliminati") ?? [];

    setState(() {
      eliminati =
          lista.map<Map<String, dynamic>>((e) => jsonDecode(e)).toList();

      eliminati.sort((a, b) =>
          (a["titolo"] ?? "").toString().compareTo((b["titolo"] ?? "").toString()));
    });
  }

  Future<void> _ripristinaBrano(int index) async {
    final prefs = await SharedPreferences.getInstance();

    final brano = eliminati[index];

    eliminati.removeAt(index);

    List<Map<String, dynamic>> scaletta = [];
    final listaScaletta = prefs.getStringList("scaletta") ?? [];

    scaletta =
        listaScaletta.map<Map<String, dynamic>>((e) => jsonDecode(e)).toList();

    scaletta.add(brano);

    scaletta.sort((a, b) =>
        (a["titolo"] ?? "").toString().compareTo((b["titolo"] ?? "").toString()));

    await prefs.setStringList(
      "scaletta",
      scaletta.map((e) => jsonEncode(e)).toList(),
    );

    await prefs.setStringList(
      "eliminati",
      eliminati.map((e) => jsonEncode(e)).toList(),
    );

    setState(() {});
  }

  Future<void> _eliminaDefinitivamente(int index) async {
    final prefs = await SharedPreferences.getInstance();

    eliminati.removeAt(index);

    await prefs.setStringList(
      "eliminati",
      eliminati.map((e) => jsonEncode(e)).toList(),
    );

    setState(() {});
  }

  Future<void> _confermaEliminazione(int index) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Eliminare definitivamente?"),
          content: const Text("Questa operazione non può essere annullata."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annulla"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Elimina",
                style: TextStyle(color: Colors.red),
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
          title: const Text("Svuotare il cestino?"),
          content: const Text("Tutti i brani eliminati saranno rimossi definitivamente."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annulla"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "SVUOTA",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (conferma == true) {
      final prefs = await SharedPreferences.getInstance();
      eliminati.clear();
      await prefs.setStringList("eliminati", []);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      body: Column(
        children: [
          // HEADER CON SCRITTA FISSA (Stile coordinato)
          Container(
            height: 70,
            width: double.infinity,
            color: Colors.black,
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

          // TAB BAR (AGGIORNATA CON BOZZE)
          Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const CreaSpartitoScreen()),
                    );
                  },
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
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ScalettaScreen()),
                    );
                  },
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
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const BozzeScreen()),
                    );
                  },
                  child: Text(
                    "bozze",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // LISTA ELIMINATI
          Expanded(
            child: eliminati.isEmpty
                ? const Center(
                    child: Text(
                      "Cestino vuoto",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: eliminati.length,
                    itemBuilder: (context, index) {
                      final brano = eliminati[index];

                      return Dismissible(
                        key: Key(brano["titolo"] + index.toString()),
                        direction: DismissDirection.horizontal,

                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          color: Colors.green,
                          child: const Text(
                            "RECUPERA BRANO",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Text(
                            "ELIMINA DEFINITIVAMENTE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brano["titolo"] ?? "Senza Titolo",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                brano["artista"] ?? "Artista sconosciuto",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // BARRA IN BASSO
          Container(
            height: 60,
            width: double.infinity,
            color: Colors.grey.shade400,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ELIMINATI: ${eliminati.length}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),

                if (eliminati.isNotEmpty)
                  GestureDetector(
                    onTap: _svuotaCestino,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "SVUOTA CESTINO",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}