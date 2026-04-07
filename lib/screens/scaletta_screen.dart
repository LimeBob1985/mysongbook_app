import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_storage_service.dart';

import 'crea_spartito_screen.dart';
import 'lettura_spartito_screen.dart';
import 'eliminati_screen.dart';
import 'nuovo_spartito_screen.dart';
import 'bozze_screen.dart';

class ScalettaScreen extends StatefulWidget {
  const ScalettaScreen({super.key});

  @override
  State<ScalettaScreen> createState() => _ScalettaScreenState();
}

class _ScalettaScreenState extends State<ScalettaScreen> {
  List<Map<String, dynamic>> scaletta = [];
  List<Map<String, dynamic>> eliminati = [];

  List<Map<String, dynamic>> scalettaFiltrata = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> alfabeto = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
  String letteraAttiva = "";

  @override
  void initState() {
    super.initState();
    _caricaListe();
    _scrollController.addListener(_aggiornaLetteraSuScroll);
    _caricaFileDaCartella();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // CARICAMENTO FILE DALLA CARTELLA LOCALE
  // -------------------------------------------------------------
  Future<void> _caricaFileDaCartella() async {
    final files = await FileStorageService.loadAllSongs();
    bool modifiche = false;

    for (final song in files) {
      // 🔥 Se il brano è negli eliminati, NON aggiungerlo in scaletta
      bool isEliminato = eliminati.any(
        (e) => (e["titolo"] ?? "") == (song["titolo"] ?? "") && (e["artista"] ?? "") == (song["artista"] ?? ""),
      );
      if (isEliminato) continue;

      bool esiste = scaletta.any(
        (b) => (b["titolo"] ?? "") == (song["titolo"] ?? "") && (b["artista"] ?? "") == (song["artista"] ?? ""),
      );

      if (!esiste) {
        scaletta.add(song);
        modifiche = true;
      }
    }

    if (modifiche) {
      _ordinaEAggiorna();
      await _salvaListe();
    }
  }

  // -------------------------------------------------------------
  // CARICAMENTO LISTE DA SHAREDPREFERENCES
  // -------------------------------------------------------------
  Future<void> _caricaListe() async {
    final prefs = await SharedPreferences.getInstance();
    final listaScaletta = prefs.getStringList("scaletta") ?? [];
    final listaEliminati = prefs.getStringList("eliminati") ?? [];

    setState(() {
      scaletta = listaScaletta.map<Map<String, dynamic>>((e) {
        Map<String, dynamic> data = jsonDecode(e);
        // Protezione dati: ci assicuriamo che le chiavi esistano
        data["titolo"] ??= "Senza Titolo";
        data["artista"] ??= "";
        data["testo"] ??= "";
        data["trasposizione"] ??= 0;
        return data;
      }).toList();

      eliminati =
          listaEliminati.map<Map<String, dynamic>>((e) => jsonDecode(e)).toList();
      _ordinaEAggiorna();
    });
  }

  // -------------------------------------------------------------
  // SALVATAGGIO LISTE
  // -------------------------------------------------------------
  Future<void> _salvaListe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> stringListScaletta =
          scaletta.map((e) => jsonEncode(e)).toList();
      final List<String> stringListEliminati =
          eliminati.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList("scaletta", stringListScaletta);
      await prefs.setStringList("eliminati", stringListEliminati);
    } catch (e) {
      debugPrint("Errore salvataggio: $e");
    }
  }

  // -------------------------------------------------------------
  // ORDINAMENTO
  // -------------------------------------------------------------
  void _ordinaEAggiorna() {
    setState(() {
      scaletta.sort((a, b) {
        String titA = (a["titolo"] ?? "").toString().toLowerCase();
        String titB = (b["titolo"] ?? "").toString().toLowerCase();
        return titA.compareTo(titB);
      });
      scalettaFiltrata = List.from(scaletta);
    });
  }

  // -------------------------------------------------------------
  // RICERCA (Reset e Esecuzione)
  // -------------------------------------------------------------
  void _resetRicerca() {
    setState(() {
      _searchController.clear();
      scalettaFiltrata = List.from(scaletta);
      FocusScope.of(context).unfocus();
    });
  }

  void _eseguiRicerca(String query) {
    if (query.isEmpty) {
      setState(() => scalettaFiltrata = List.from(scaletta));
      return;
    }
    setState(() {
      scalettaFiltrata = scaletta.where((brano) {
        final titolo = (brano["titolo"] ?? "").toString().toLowerCase();
        final artista = (brano["artista"] ?? "").toString().toLowerCase();
        return titolo.contains(query.toLowerCase()) ||
            artista.contains(query.toLowerCase());
      }).toList();
    });
  }

  // -------------------------------------------------------------
  // ELIMINAZIONE (sposta in Eliminati)
  // -------------------------------------------------------------
  Future<void> _eliminaBrano(int indexFiltrato) async {
    final brano = scalettaFiltrata[indexFiltrato];

    setState(() {
      scaletta.remove(brano);
      scalettaFiltrata.removeAt(indexFiltrato);
      eliminati.add(brano);
    });

    // 🔥 Salva solo le liste, NON toccare i file fisici
    await _salvaListe();
  }

  // -------------------------------------------------------------
  // SCROLL LETTERE
  // -------------------------------------------------------------
  void _aggiornaLetteraSuScroll() {
    if (scalettaFiltrata.isEmpty) return;
    double offset = _scrollController.offset;
    int index = (offset / 72).floor();
    if (index >= 0 && index < scalettaFiltrata.length) {
      String tit = (scalettaFiltrata[index]["titolo"] ?? "").toString();
      if (tit.isNotEmpty) {
        String primaLettera = tit[0].toUpperCase();
        if (alfabeto.contains(primaLettera) && letteraAttiva != primaLettera) {
          setState(() => letteraAttiva = primaLettera);
        }
      }
    }
  }

  void _saltaALettera(String lettera) {
    int index = scalettaFiltrata.indexWhere(
        (b) => (b["titolo"] ?? "").toString().toUpperCase().startsWith(lettera));
    if (index != -1) {
      _scrollController.jumpTo(index * 72.0);
      setState(() => letteraAttiva = lettera);
    }
  }

  // -------------------------------------------------------------
  // RINOMINA (Corretta per preservare i dati e sincronizzare il device)
  // -------------------------------------------------------------
  void _mostraDialogRinomina(int indexFiltrato) {
    final brano = scalettaFiltrata[indexFiltrato];
    final tC = TextEditingController(text: brano["titolo"] ?? "");
    final aC = TextEditingController(text: brano["artista"] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title:
            const Text("Modifica brano", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: tC,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Titolo",
                    labelStyle: TextStyle(color: Colors.amber))),
            const SizedBox(height: 15),
            TextField(
                controller: aC,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Artista/Band",
                    labelStyle: TextStyle(color: Colors.amber))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ANNULLA",
                  style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () async {
              String vecchioTitolo = brano["titolo"] ?? "";
              String vecchioArtista = brano["artista"] ?? "";
              String nuovoTitolo = tC.text.trim();
              String nuovoArtista = aC.text.trim();

              setState(() {
                int idx = scaletta.indexOf(brano);
                if (idx != -1) {
                  // Aggiorniamo solo i nomi, preservando il resto della mappa (testo, righe, accordi)
                  scaletta[idx]["titolo"] = nuovoTitolo;
                  scaletta[idx]["artista"] = nuovoArtista;
                }
              });

              // 1. Rinomina il file fisico sul device
              await FileStorageService.renameSong(
                vecchioTitolo, 
                vecchioArtista, 
                nuovoTitolo, 
                nuovoArtista
              );

              // 2. Salva il file fisico con i nuovi dati completi
              int updatedIdx = scaletta.indexWhere((b) => b["titolo"] == nuovoTitolo && b["artista"] == nuovoArtista);
              if(updatedIdx != -1) {
                await FileStorageService.saveSong(scaletta[updatedIdx]);
              }

              // 3. Aggiorna le SharedPreferences
              _ordinaEAggiorna();
              await _salvaListe();
            
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("SALVA",
                style: TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),
      body: Column(
        children: [
          // HEADER NERO
          Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 70,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    // AREA DOPPIO TAP A SINISTRA
                    GestureDetector(
                      onDoubleTap: _resetRicerca,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 60,
                        height: double.infinity,
                        alignment: Alignment.center,
                        child: const SizedBox(),
                      ),
                    ),
                    const Spacer(),
                    const Text("SCALETTA",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const NuovoSpartitoScreen()))
                          .then((_) => _caricaListe()),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // SOTTOMENU CON ANIMAZIONI BIDIREZIONALI
          Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // CREA SPARTITO
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          const CreaSpartitoScreen(),
                      transitionDuration:
                          const Duration(milliseconds: 300),
                      transitionsBuilder:
                          (_, animation, __, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        );
                      },
                    ),
                  ),
                  child: Text(
                    "crea spartito",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                const Text(
                  "scaletta",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 24),

                // BOZZE
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          const BozzeScreen(),
                      transitionDuration:
                          const Duration(milliseconds: 300),
                      transitionsBuilder:
                          (_, animation, __, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        );
                      },
                    ),
                  ),
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

          // BARRA DI RICERCA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                  border:
                      Border.all(color: Colors.white54, width: 1.5),
                  borderRadius: BorderRadius.circular(4)),
              child: TextField(
                controller: _searchController,
                onChanged: _eseguiRicerca,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                    hintText: "Cerca una canzone o un artista....",
                    hintStyle:
                        TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12)),
              ),
            ),
          ),

          // LISTA BRANI
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: scalettaFiltrata.length,
                    itemBuilder: (context, index) {
                      final brano = scalettaFiltrata[index];
                      String tit = (brano["titolo"] ?? "").toString();

                      String letteraCorrente = tit.isNotEmpty ? tit[0].toUpperCase() : "?";
                      bool mostraLettera = false;
                      if (index == 0) {
                        mostraLettera = true;
                      } else {
                        String titPrec = (scalettaFiltrata[index - 1]["titolo"] ?? "").toString();
                        String letteraPrecedente = titPrec.isNotEmpty ? titPrec[0].toUpperCase() : "?";
                        if (letteraCorrente != letteraPrecedente) {
                          mostraLettera = true;
                        }
                      }

                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (mostraLettera)
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8),
                              decoration: const BoxDecoration(
                                  color: Color(0xFF1A1A1A),
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.white10,
                                          width: 0.5))),
                              child: Text(letteraCorrente,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 14)),
                            ),

                          Dismissible(
                            key: ObjectKey(brano),
                            direction:
                                DismissDirection.endToStart,
                            background: const SizedBox(),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(
                                      right: 20),
                              color: Colors.red,
                              child: const Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline,
                                      color: Colors.white,
                                      size: 28),
                                  SizedBox(height: 4),
                                  Text("Elimina",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            confirmDismiss:
                                (direction) async {
                              await _eliminaBrano(index);
                              return true;
                            },
                            child: ListTile(
                              leading: Container(
                                  width: 10,
                                  height: 10,
                                  decoration:
                                      const BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape
                                              .circle)),
                              title: Text(tit,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.bold)),
                              subtitle: Text(
                                  (brano["artista"] ?? "").toString(),
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13)),
                              onLongPress: () =>
                                  _mostraDialogRinomina(
                                      index),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            LetturaSpartitoScreen(
                                              titolo: brano["titolo"] ?? "",
                                              artista: brano["artista"] ?? "",
                                              testoCompleto: brano["testo"] ?? "",
                                              trasposizione: brano["trasposizione"] ?? 0,
                                            ))).then((_) =>
                                    _caricaListe());
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // --- SCROLLBAR ALFABETICA ---
                Container(
                  width: 32,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          final letterHeight =
                              constraints.maxHeight /
                                  alfabeto.length;
                          int index =
                              (details.localPosition.dy /
                                      letterHeight)
                                  .floor();
                          if (index >= 0 &&
                              index < alfabeto.length) {
                            _saltaALettera(
                                alfabeto[index]);
                          }
                        },
                        onTapDown: (details) {
                          final letterHeight =
                              constraints.maxHeight /
                                  alfabeto.length;
                          int index =
                              (details.localPosition.dy /
                                      letterHeight)
                                  .floor();
                          if (index >= 0 &&
                              index < alfabeto.length) {
                            _saltaALettera(
                                alfabeto[index]);
                          }
                        },
                        child: Column(
                          children: alfabeto.map((l) {
                            bool isActive =
                                letteraAttiva == l;
                            return Expanded(
                              child: Center(
                                child: Text(
                                  l,
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(
                                            0xFF42A5F5)
                                        : const Color(
                                                0xFF64B5F6)
                                            .withOpacity(
                                                0.7),
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: isActive
                                        ? 14
                                        : 10,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // FOOTER ELIMINATI
          GestureDetector(
            onTap: eliminati.isEmpty
                ? null
                : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const EliminatiScreen()))
                    .then((_) {
                      if (mounted) _caricaListe();
                    }),
            child: Container(
              width: double.infinity,
              color: eliminati.isEmpty
                  ? Colors.grey.withOpacity(0.1)
                  : Colors.grey.shade400,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text("ELIMINATI: ${eliminati.length}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}