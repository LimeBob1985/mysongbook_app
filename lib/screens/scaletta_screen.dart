import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  bool _staCercando = false;

  bool modalitaSelezione = false;
  Set<int> selezionati = {};

  @override
  void initState() {
    super.initState();
    _caricaListe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _pulisciPerPdf(String testo) {
    return testo
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), ' ');
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

      _ordinaEAggiorna();
      _resetRicerca();
    });
  }

  void _ordinaEAggiorna() {
    setState(() {
      scaletta.sort((a, b) =>
          (a["titolo"] as String).toLowerCase().compareTo((b["titolo"] as String).toLowerCase()));
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
      scaletta.removeWhere((element) => element == brano);
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
            leading: const Icon(Icons.settings, color: Colors.amber),
            title: const Text("Formato MySongBook (.json)", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Perfetto per backup o altri utenti MySongBook", style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _condividiBraniJson(braniScelti);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            title: const Text("Formato PDF (Tutti i brani)", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Crea un unico documento con i brani scelti", style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _condividiBraniPdf(braniScelti);
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
      final file = File('${directory.path}/scaletta_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(dati);
      await Share.shareXFiles([XFile(file.path)], text: 'Ti invio la mia scaletta da MySongBook');
      _resetRicerca();
    } catch (e) {
      debugPrint("Errore esportazione JSON: $e");
    }
  }

  Future<void> _condividiBraniPdf(List<Map<String, dynamic>> brani) async {
    final pdf = pw.Document();
    final fontRegular = pw.Font.courier();
    final fontBold = pw.Font.courierBold();

    for (var brano in brani) {
      final String titolo = _pulisciPerPdf(brano["titolo"].toString().toUpperCase());
      final String artista = _pulisciPerPdf(brano["artista"].toString());
      
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [
            pw.Text(titolo, style: pw.TextStyle(fontSize: 20, font: fontBold, fontWeight: pw.FontWeight.bold)),
            pw.Text(artista, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700, font: fontRegular)),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 1.5, color: PdfColors.black),
            pw.SizedBox(height: 20),
          ];

          if (brano["righe"] != null && brano["righe"] is List) {
            List<dynamic> righeBrano = brano["righe"];
            for (var riga in righeBrano) {
              String acc = riga["accordi"] ?? "";
              String txt = riga["testo"] ?? "";

              if (acc.trim().isNotEmpty) {
                widgets.add(pw.Text(_pulisciPerPdf(acc),
                    style: pw.TextStyle(fontSize: 11, font: fontBold, color: PdfColors.blue800)));
              }
              if (txt.trim().isNotEmpty || (acc.isEmpty && txt.isEmpty)) {
                widgets.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(_pulisciPerPdf(txt), style: pw.TextStyle(fontSize: 10, font: fontRegular)),
                ));
              } else {
                widgets.add(pw.SizedBox(height: 2));
              }
            }
          } else {
            List<String> righeLegacy = brano["testo"].toString().split('\n');
            for (var riga in righeLegacy) {
              bool eAccordo = riga.contains('[AC]');
              String rigaPulita = _pulisciPerPdf(riga.replaceAll('[AC]', ''));
              if (rigaPulita.trim().isEmpty && !eAccordo) {
                widgets.add(pw.SizedBox(height: 12));
                continue;
              }
              widgets.add(pw.Padding(
                padding: pw.EdgeInsets.only(bottom: eAccordo ? 0 : 2),
                child: pw.Text(rigaPulita,
                    style: pw.TextStyle(
                      fontSize: eAccordo ? 11 : 10,
                      font: eAccordo ? fontBold : fontRegular,
                      color: eAccordo ? PdfColors.blue800 : PdfColors.black,
                    )),
              ));
            }
          }
          return widgets;
        },
      ));
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'spartito_mysongbook.pdf');
    _resetRicerca();
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
            hintText: "Incolla qui il contenuto del file JSON...",
            hintStyle: TextStyle(color: Colors.grey),
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
                      scaletta.add(Map<String, dynamic>.from(b));
                    }
                  } else {
                    scaletta.add(Map<String, dynamic>.from(decoded));
                  }
                });
                await _salvaListe();
                _ordinaEAggiorna();
                _resetRicerca();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Formato JSON non valido")),
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
          // APP BAR NERA
          Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 70,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4), // Ridotto padding laterale fascia
                child: Row(
                  children: [
                    // Tasto Importa (Icona corretta: Freccia verso il basso)
                    modalitaSelezione 
                      ? IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 26), onPressed: () => setState(() => _resetRicerca()))
                      : IconButton(icon: const Icon(Icons.file_download, color: Colors.white, size: 26), onPressed: _mostraDialogImporta),
                    
                    // Barra di ricerca (Più compatta)
                    Expanded(
                      child: Container(
                        height: 36, // Altezza ridotta
                        margin: const EdgeInsets.symmetric(horizontal: 4), // Margine ridotto
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _eseguiRicerca,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: "Cerca...",
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
                          ),
                        ),
                      ),
                    ),
                    
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

          // SOTTOMENU
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

          // LISTA
          Expanded(
            child: ListView.builder(
              itemCount: scalettaFiltrata.length,
              itemBuilder: (context, index) {
                final brano = scalettaFiltrata[index];
                final isSelezionato = selezionati.contains(index);

                return Dismissible(
                  key: UniqueKey(),
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

          // BARRA ELIMINATI
          GestureDetector(
            onTap: eliminati.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EliminatiScreen())).then((_) { if (mounted) _caricaListe(); }),
            child: Container(
              width: double.infinity,
              color: eliminati.isEmpty ? Colors.grey.withOpacity(0.1) : Colors.grey.shade400,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text("ELIMINATI: ${eliminati.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}