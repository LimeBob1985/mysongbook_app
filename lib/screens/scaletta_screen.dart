import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

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
  
  bool _staCercando = false;
  bool modalitaSelezione = false;
  Set<int> selezionati = {};

  final List<String> alfabeto = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
  String letteraAttiva = "";

  @override
  void initState() {
    super.initState();
    _caricaListe();
    _scrollController.addListener(_aggiornaLetteraSuScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
      _scrollController.animateTo(
        index * 72.0, 
        duration: const Duration(milliseconds: 300),
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

        String testoRecuperato = data["testo"] ??
            data["testo_originale"] ??
            data["content"] ??
            "" ;

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

      scaletta.sort((a, b) =>
          (a["titolo"] as String).toLowerCase().compareTo((b["titolo"] as String).toLowerCase()));
      
      scalettaFiltrata = List.from(scaletta);
      _searchController.clear();
      _staCercando = false;
    });
  }

  void _ordinaEAggiorna() {
    setState(() {
      scaletta.sort((a, b) =>
          (a["titolo"] as String).toLowerCase().compareTo((b["titolo"] as String).toLowerCase()));
      scalettaFiltrata = List.from(scaletta);
    });
  }

  void _resetRicerca() {
    setState(() {
      _searchController.clear();
      _staCercando = false;
      scalettaFiltrata = List.from(scaletta);
      modalitaSelezione = false;
      selezionati.clear();
    });
  }

  void _eseguiRicerca(String query) {
    if (query.isEmpty) {
      setState(() {
        _staCercando = false;
        scalettaFiltrata = List.from(scaletta);
      });
      return;
    }
    setState(() {
      _staCercando = true;
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
      debugPrint("Errore durante il salvataggio dei dati: $e");
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seleziona almeno un brano per esportare")),
      );
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
            subtitle: const Text("Invia i brani selezionati in formato compatibile", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
      // Usiamo l'estensione personalizzata .mysongbook
      final String fileName = "export_${DateTime.now().millisecondsSinceEpoch}.mysongbook";
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(dati, flush: true);
      
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/json')], 
          text: 'Ti invio la mia scaletta da MySongBook'
        );
      }
      _resetRicerca();
    } catch (e) {
      debugPrint("Errore esportazione MySongBook: $e");
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ANNULLA", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              try {
                final decoded = jsonDecode(importController.text.trim());
                setState(() {
                  if (decoded is List) {
                    for (var b in decoded) {
                      // Applichiamo la stessa pulizia dati del caricamento
                      final Map<String, dynamic> branoPulito = {
                        "titolo": b["titolo"] ?? b["title"] ?? "Senza Titolo",
                        "artista": b["artista"] ?? b["artist"] ?? "Artista Sconosciuto",
                        "testo": b["testo"] ?? b["testo_originale"] ?? b["content"] ?? "",
                        "righe": b["righe"],
                        "struttura_completa": b["struttura_completa"],
                        "trasposizione": b["trasposizione"] ?? 0,
                      };
                      scaletta.add(branoPulito);
                    }
                  } else {
                    final Map<String, dynamic> branoPulito = {
                      "titolo": decoded["titolo"] ?? decoded["title"] ?? "Senza Titolo",
                      "artista": decoded["artista"] ?? decoded["artist"] ?? "Artista Sconosciuto",
                      "testo": decoded["testo"] ?? decoded["testo_originale"] ?? decoded["content"] ?? "",
                      "righe": decoded["righe"],
                      "struttura_completa": decoded["struttura_completa"],
                      "trasposizione": decoded["trasposizione"] ?? 0,
                    };
                    scaletta.add(branoPulito);
                  }
                });
                await _salvaListe();
                _ordinaEAggiorna();
                _resetRicerca();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Formato non valido o corrotto")),
                );
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
    final TextEditingController titoloController = TextEditingController(text: brano["titolo"]);
    final TextEditingController artistaController = TextEditingController(text: brano["artista"]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title: const Text("Modifica brano", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titoloController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Titolo",
                labelStyle: TextStyle(color: Colors.amber),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: artistaController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Artista/Band",
                labelStyle: TextStyle(color: Colors.amber),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA", style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () async {
              setState(() {
                int indexOriginale = scaletta.indexOf(brano);
                if (indexOriginale != -1) {
                  scaletta[indexOriginale]["titolo"] = titoloController.text.trim();
                  scaletta[indexOriginale]["artista"] = artistaController.text.trim();
                }
              });
              _ordinaEAggiorna();
              if (_searchController.text.isNotEmpty) {
                _eseguiRicerca(_searchController.text);
              } else {
                _resetRicerca();
              }
              await _salvaListe();
              if (mounted) Navigator.pop(context);
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
                      : IconButton(icon: const Icon(Icons.file_download, color: Colors.white, size: 26), onPressed: _mostraDialogImporta),
                    
                    const Spacer(),
                    const Text("SCALETTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    
                    if (modalitaSelezione)
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.amber, size: 28), 
                        onPressed: _avviaEsportazioneMultipla
                      ),
                    
                    if (!modalitaSelezione)
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 28),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NuovoSpartitoScreen())).then((_) => _caricaListe()),
                      ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreaSpartitoScreen())),
                  child: Text(
                    "crea spartito", 
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)
                  ),
                ),
                const SizedBox(width: 24),
                const Text(
                  "scaletta", 
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BozzeScreen())),
                  child: Text(
                    "bozze", 
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _eseguiRicerca,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Cerca una canzone o un artista....",
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                ),
              ),
            ),
          ),

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

                      return Dismissible(
                        key: ObjectKey(brano), 
                        direction: modalitaSelezione ? DismissDirection.none : DismissDirection.horizontal,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          color: Colors.amber.shade700,
                          child: const Row(children: [Icon(Icons.check_circle_outline, color: Colors.black), SizedBox(width: 8), Text("SELEZIONA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))]),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Text("ELIMINA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            setState(() { modalitaSelezione = true; selezionati.add(index); });
                            return false;
                          } else {
                            await _eliminaBrano(index);
                            return true;
                          }
                        },
                        child: ListTile(
                          selected: isSelezionato,
                          leading: modalitaSelezione 
                            ? Checkbox(value: isSelezionato, activeColor: Colors.amber, checkColor: Colors.black, onChanged: (v) => setState(() => v! ? selezionati.add(index) : selezionati.remove(index)))
                            : CircleAvatar(
                                backgroundColor: Colors.amber,
                                child: Text((scaletta.indexOf(brano) + 1).toString().padLeft(2, "0"), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
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
                      );
                    },
                  ),
                ),

                Container(
                  width: 32,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      children: alfabeto.map((l) {
                        bool isAttiva = letteraAttiva == l;
                        return GestureDetector(
                          onTap: () => _saltaALettera(l),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Text(
                              l,
                              style: TextStyle(
                                color: isAttiva ? Colors.amber : Colors.white,
                                fontWeight: isAttiva ? FontWeight.bold : FontWeight.normal,
                                fontSize: isAttiva ? 16 : 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

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