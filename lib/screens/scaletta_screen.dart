import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bonsoir/bonsoir.dart';

import 'crea_spartito_screen.dart';
import 'lettura_spartito_screen.dart';
import 'eliminati_screen.dart';
import 'nuovo_spartito_screen.dart';
import 'bozze_screen.dart';
import '../web_service.dart';

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
  
  bool modalitaSelezione = false;
  Set<int> selezionati = {};

  final List<String> alfabeto = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
  String letteraAttiva = "";

  // --- VARIABILI WI-FI ---
  BonsoirDiscovery? _discovery;
  List<ResolvedBonsoirService> dispositiviTrovati = [];

  @override
  void initState() {
    super.initState();
    _caricaListe();
    _scrollController.addListener(_aggiornaLetteraSuScroll);
    _configuraRicezione();
    _avviaRicercaDispositivi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _discovery?.stop();
    super.dispose();
  }

  // --- METODI WI-FI ---

  void _configuraRicezione() {
    WebService().onSongReceived = (songData) async {
      setState(() {
        bool esiste = scaletta.any((b) => b["titolo"] == songData["titolo"] && b["artista"] == songData["artista"]);
        if (!esiste) {
          scaletta.add(songData);
          _ordinaEAggiorna();
        }
      });
      await _salvaListe();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green, 
          content: Text("Ricevuto: ${songData['titolo']}")
        ),
      );
    };
  }

  Future<void> _avviaRicercaDispositivi() async {
    _discovery = BonsoirDiscovery(type: '_mysongbook._tcp');
    await _discovery!.ready;
    _discovery!.eventStream!.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        if (event.service != null) {
          setState(() {
            final service = event.service as ResolvedBonsoirService;
            if (!dispositiviTrovati.any((d) => d.name == service.name)) {
              dispositiviTrovati.add(service);
            }
          });
        }
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        setState(() {
          dispositiviTrovati.removeWhere((d) => d.name == event.service?.name);
        });
      }
    });
    await _discovery!.start();
  }

  void _mostraDialogInvio(Map<String, dynamic> brano) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF212121),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("INVIA TRAMITE WI-FI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (dispositiviTrovati.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text("Nessun musicista trovato", style: TextStyle(color: Colors.white54)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: dispositiviTrovati.length,
                itemBuilder: (context, i) {
                  final device = dispositiviTrovati[i];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.person, color: Colors.black)),
                    title: Text(device.name, style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      String? host;
                      try {
                        host = (device as dynamic).host;
                      } catch (e) {
                      }

                      if (host == null || host.isEmpty) return;

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      bool successo = await WebService().sendSong(host, device.port, brano);
                      
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(successo ? "Inviato a ${device.name}!" : "Errore invio"),
                        backgroundColor: successo ? Colors.blue : Colors.red,
                      ));
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- LOGICA GESTIONE DATI ---

  void _aggiornaLetteraSuScroll() {
    if (scalettaFiltrata.isEmpty) return;
    double offset = _scrollController.offset;
    int index = (offset / 72).floor(); 
    if (index >= 0 && index < scalettaFiltrata.length) {
      String primaLettera = scalettaFiltrata[index]["titolo"][0].toUpperCase();
      if (alfabeto.contains(primaLettera) && letteraAttiva != primaLettera) {
        setState(() {
          letteraAttiva = primaLettera;
        });
      }
    }
  }

  void _saltaALettera(String lettera) {
    int index = scalettaFiltrata.indexWhere((b) => b["titolo"].toString().toUpperCase().startsWith(lettera));
    if (index != -1) {
      // Calcolo approssimativo per lo scroll considerando le intestazioni delle lettere
      _scrollController.animateTo(
        index * 72.0, 
        duration: const Duration(milliseconds: 300),
        // ignore: deprecated_member_use
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _caricaListe() async {
    final prefs = await SharedPreferences.getInstance();
    final listaScaletta = prefs.getStringList("scaletta") ?? [];
    final listaEliminati = prefs.getStringList("eliminati") ?? [];

    setState(() {
      scaletta = listaScaletta.map<Map<String, dynamic>>((e) {
        final Map<String, dynamic> data = jsonDecode(e);
        String testoRecuperato = data["testo"] ?? data["testo_originale"] ?? data["content"] ?? "" ;
        return {
          "titolo": data["titolo"] ?? data["title"] ?? "Senza Titolo",
          "artista": data["artista"] ?? data["artist"] ?? "Artista Sconosciuto",
          "testo": testoRecuperato,
          "righe": data["righe"],
          "struttura_completa": data["struttura_completa"],
          "trasposizione": data["trasposizione"] ?? 0,
        };
      }).toList();

      eliminati = listaEliminati.map<Map<String, dynamic>>((e) => jsonDecode(e)).toList();
      _ordinaEAggiorna();
    });
  }

  void _ordinaEAggiorna() {
    setState(() {
      scaletta.sort((a, b) => (a["titolo"] as String).toLowerCase().compareTo((b["titolo"] as String).toLowerCase()));
      scalettaFiltrata = List.from(scaletta);
    });
  }

  void _resetRicerca() {
    setState(() {
      _searchController.clear();
      scalettaFiltrata = List.from(scaletta);
      modalitaSelezione = false;
      selezionati.clear();
      FocusScope.of(context).unfocus(); // Chiude anche la tastiera
    });
  }

  void _eseguiRicerca(String query) {
    if (query.isEmpty) {
      setState(() {
        scalettaFiltrata = List.from(scaletta);
      });
      return;
    }
    setState(() {
      scalettaFiltrata = scaletta.where((brano) {
        final titolo = brano["titolo"].toString().toLowerCase();
        final artista = brano["artista"].toString().toLowerCase();
        return titolo.contains(query.toLowerCase()) || artista.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _salvaListe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> stringListScaletta = scaletta.map((e) => jsonEncode(e)).toList();
      final List<String> stringListEliminati = eliminati.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList("scaletta", stringListScaletta);
      await prefs.setStringList("eliminati", stringListEliminati);
    } catch (e) {
      debugPrint("Errore salvataggio: $e");
    }
  }

  Future<void> _eliminaBrano(int indexFiltrato) async {
    final brano = scalettaFiltrata[indexFiltrato];
    setState(() {
      scaletta.remove(brano); 
      scalettaFiltrata.removeAt(indexFiltrato);
      eliminati.add(brano);
    });
    await _salvaListe();
  }

  Future<void> _avviaEsportazioneMultipla() async {
    if (selezionati.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seleziona almeno un brano per esportare")));
      return;
    }

    List<Map<String, dynamic>> braniScelti = selezionati.map((i) => scalettaFiltrata[i]).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF212121),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("ESPORTA SELEZIONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.amber),
            title: const Text("Formato MySongBook (.mysongbook)", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _condividiBraniJson(braniScelti);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _condividiBraniJson(List<Map<String, dynamic>> brani) async {
    try {
      final String dati = jsonEncode(brani);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/export_${DateTime.now().millisecondsSinceEpoch}.mysongbook');
      await file.writeAsString(dati, flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'Ti invio la mia scaletta');
      _resetRicerca();
    } catch (e) {
      debugPrint("Errore esportazione: $e");
    }
  }

  void _mostraDialogImporta() {
    final TextEditingController importController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title: const Text("Importa Brano", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: importController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(
            hintText: "Incolla qui il codice MySongBook...",
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA", style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () async {
              try {
                final decoded = jsonDecode(importController.text.trim());
                setState(() {
                  if (decoded is List) {
                    for (var b in decoded) {
                      scaletta.add({
                        "titolo": b["titolo"] ?? b["title"] ?? "Senza Titolo",
                        "artista": b["artista"] ?? b["artist"] ?? "Artista Sconosciuto",
                        "testo": b["testo"] ?? b["testo_originale"] ?? b["content"] ?? "",
                        "righe": b["righe"],
                        "struttura_completa": b["struttura_completa"],
                        "trasposizione": b["trasposizione"] ?? 0,
                      });
                    }
                  } else {
                    scaletta.add({
                      "titolo": decoded["titolo"] ?? decoded["title"] ?? "Senza Titolo",
                      "artista": decoded["artista"] ?? decoded["artist"] ?? "Artista Sconosciuto",
                      "testo": decoded["testo"] ?? decoded["testo_originale"] ?? decoded["content"] ?? "",
                      "righe": decoded["righe"],
                      "struttura_completa": decoded["struttura_completa"],
                      "trasposizione": decoded["trasposizione"] ?? 0,
                    });
                  }
                });
                await _salvaListe();
                _ordinaEAggiorna();
                _resetRicerca();
                
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Formato non valido")));
              }
            },
            child: const Text("IMPORTA", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostraDialogRinomina(int indexFiltrato) {
    final brano = scalettaFiltrata[indexFiltrato];
    final tC = TextEditingController(text: brano["titolo"]);
    final aC = TextEditingController(text: brano["artista"]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title: const Text("Modifica brano", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titolo", labelStyle: TextStyle(color: Colors.amber))),
            const SizedBox(height: 15),
            TextField(controller: aC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Artista/Band", labelStyle: TextStyle(color: Colors.amber))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA", style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () async {
              setState(() {
                int idx = scaletta.indexOf(brano);
                if (idx != -1) {
                  scaletta[idx]["titolo"] = tC.text.trim();
                  scaletta[idx]["artista"] = aC.text.trim();
                }
              });
              _ordinaEAggiorna();
              await _salvaListe();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("SALVA", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),
      body: Column(
        children: [
          // HEADER
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
                    modalitaSelezione 
                      ? IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 26), onPressed: () => setState(() => _resetRicerca()))
                      : GestureDetector(
                          onDoubleTap: _resetRicerca,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 60, // Spazio a sinistra della scritta SCALETTA
                            height: double.infinity,
                            alignment: Alignment.center,
                            child: const SizedBox(), 
                          ),
                        ),
                    const Spacer(),
                    const Text("SCALETTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    if (modalitaSelezione)
                      IconButton(icon: const Icon(Icons.share, color: Colors.amber, size: 28), onPressed: _avviaEsportazioneMultipla)
                    else
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 28),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NuovoSpartitoScreen())).then((_) => _caricaListe()),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // SOTTOMENU
          Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const CreaSpartitoScreen(),
                      transitionDuration: const Duration(milliseconds: 300),
                      transitionsBuilder: (_, animation, __, child) => SlideTransition(position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(animation), child: child),
                    ));
                  },
                  child: Text("crea spartito", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
                ),
                const SizedBox(width: 24),
                const Text("scaletta", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const BozzeScreen(),
                      transitionDuration: const Duration(milliseconds: 300),
                      transitionsBuilder: (_, animation, __, child) => SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation), child: child),
                    ));
                  },
                  child: Text("bozze", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
                ),
              ],
            ),
          ),

          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(border: Border.all(color: Colors.white54, width: 1.5), borderRadius: BorderRadius.circular(4)),
              child: TextField(
                controller: _searchController,
                onChanged: _eseguiRicerca,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(hintText: "Cerca una canzone o un artista....", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12)),
              ),
            ),
          ),

          // LISTA PRINCIPALE
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: scalettaFiltrata.length,
                    itemBuilder: (context, index) {
                      final brano = scalettaFiltrata[index];
                      final isSelezionato = selezionati.contains(index);
                      
                      // LOGICA PER MOSTRARE LA LETTERA SEZIONE
                      String letteraCorrente = brano["titolo"][0].toUpperCase();
                      bool mostraLettera = false;
                      if (index == 0) {
                        mostraLettera = true;
                      } else {
                        String letteraPrecedente = scalettaFiltrata[index - 1]["titolo"][0].toUpperCase();
                        if (letteraCorrente != letteraPrecedente) {
                          mostraLettera = true;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mostraLettera)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A1A1A), // Sfondo riga lettera leggermente più scuro
                                border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))
                              ),
                              child: Text(
                                letteraCorrente,
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          Dismissible(
                            key: ObjectKey(brano), 
                            direction: modalitaSelezione ? DismissDirection.none : DismissDirection.horizontal,
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              color: Colors.blue.shade700,
                              child: const Row(children: [Icon(Icons.wifi, color: Colors.white), SizedBox(width: 8), Text("INVIA WI-FI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.white, size: 28),
                                  SizedBox(height: 4),
                                  Text("Elimina", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                _mostraDialogInvio(brano);
                                return false;
                              } else {
                                await _eliminaBrano(index);
                                return true;
                              }
                            },
                            child: ListTile(
                              selected: isSelezionato,
                              leading: modalitaSelezione 
                                ? Checkbox(value: isSelezionato, activeColor: Colors.amber, onChanged: (v) => setState(() => v! ? selezionati.add(index) : selezionati.remove(index)))
                                : Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                              title: Text(brano["titolo"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(brano["artista"], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              onLongPress: () => _mostraDialogRinomina(index),
                              onTap: () {
                                if (modalitaSelezione) {
                                  setState(() => isSelezionato ? selezionati.remove(index) : selezionati.add(index));
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => LetturaSpartitoScreen(
                                    titolo: brano["titolo"], artista: brano["artista"],
                                    testoCompleto: brano["testo"], trasposizione: brano["trasposizione"],
                                  ))).then((_) => _caricaListe());
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // SCROLL BAR ALFABETICA
                Container(
                  width: 32,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      children: alfabeto.map((l) => GestureDetector(
                        onTap: () => _saltaALettera(l),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Text(l, style: TextStyle(
                            color: letteraAttiva == l ? const Color(0xFF42A5F5) : const Color(0xFF64B5F6).withOpacity(0.7), 
                            fontWeight: letteraAttiva == l ? FontWeight.bold : FontWeight.normal, 
                            fontSize: letteraAttiva == l ? 16 : 13
                          )),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FOOTER ELIMINATI
          GestureDetector(
            onTap: eliminati.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EliminatiScreen())).then((_) { if (mounted) _caricaListe(); }),
            child: Container(
              width: double.infinity,
              color: eliminati.isEmpty ? Colors.grey.withOpacity(0.1) : Colors.grey.shade400,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text("ELIMINATI: ${eliminati.length}", style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}