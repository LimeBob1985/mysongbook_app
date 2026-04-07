import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/chord_utils.dart';
import '../services/chord_transposer.dart';
import '../services/file_storage_service.dart'; // Importato per il salvataggio fisico

class BoldTextEditingController extends TextEditingController {
  static const String boldTag = '\u200D';

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<TextSpan> children = [];
    final regex = RegExp(r'(\u200D.*?\u200D|[^\u200D]+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith(boldTag) && part.endsWith(boldTag)) {
        children.add(TextSpan(
          text: part.replaceAll(boldTag, ''),
          style: style?.copyWith(fontWeight: FontWeight.w900, color: Colors.black),
        ));
      } else {
        children.add(TextSpan(text: part, style: style));
      }
    }
    return TextSpan(style: style, children: children);
  }
}

class LetturaSpartitoScreen extends StatefulWidget {
  final String titolo;
  final String artista;
  final String testoCompleto;
  final int trasposizione;

  const LetturaSpartitoScreen({
    super.key,
    required this.titolo,
    required this.artista,
    required this.testoCompleto,
    this.trasposizione = 0,
  });

  @override
  State<LetturaSpartitoScreen> createState() => _LetturaSpartitoScreenState();
}

class _LetturaSpartitoScreenState extends State<LetturaSpartitoScreen> with WidgetsBindingObserver {
  late int _trasposizione;
  late PageController _pageController;
  List<dynamic> _strutturaCompleta = [];
  List<List<dynamic>> _pagine = [];
  bool _isEditing = false;
  bool _initialized = false;
  late bool _preferFlats;

  final List<String> _undoHistory = [];
  static const String boldTag = '\u200D';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _caricaDati();
  }

  void _saveSnapshot() {
    final snapshot = jsonEncode(_strutturaCompleta.map((r) => {
      'tipo': r['tipo'],
      'testo': r['tipo'] == 'testo' && r['controller'] != null ? r['controller'].text : r['testo'],
      'accordi': r['accordi'],
    }).toList());
    
    if (_undoHistory.isEmpty || _undoHistory.last != snapshot) {
      _undoHistory.add(snapshot);
      if (_undoHistory.length > 30) _undoHistory.removeAt(0);
    }
  }

  void _undo() {
    if (_undoHistory.isEmpty) return;
    
    final lastState = jsonDecode(_undoHistory.removeLast());
    setState(() {
      _strutturaCompleta = lastState.map<Map<String, dynamic>>((r) {
        return {
          'tipo': r['tipo'],
          'testo': r['testo'] ?? "",
          'accordi': r['accordi'] ?? [],
          'controller': r['tipo'] == 'testo' 
              ? (BoldTextEditingController()..text = r['testo'] ?? "") 
              : null,
        };
      }).toList();
      _impaginaTesto();
    });
  }

  Future<void> _caricaDati() async {
    final prefs = await SharedPreferences.getInstance();
    final scalettaStr = prefs.getStringList("scaletta") ?? [];

    Map<String, dynamic>? brano;
    try {
      final listaDecodificata = scalettaStr.map((e) => jsonDecode(e) as Map<String, dynamic>);
      brano = listaDecodificata.firstWhere(
        (b) => b["titolo"] == widget.titolo && b["artista"] == widget.artista,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      brano = {};
    }

    setState(() {
      _trasposizione = brano?["trasposizione"] ?? widget.trasposizione;

      if (brano != null && brano["struttura_completa"] != null && (brano["struttura_completa"] as List).isNotEmpty) {
        _strutturaCompleta = brano["struttura_completa"].map((r) {
          return {
            'tipo': r['tipo'],
            'testo': r['testo'] ?? "",
            'accordi': r['accordi'] ?? [],
            'controller': r['tipo'] == 'testo' 
                ? (BoldTextEditingController()..text = r['testo'] ?? "") 
                : null,
          };
        }).toList();
        _assicuraOriginalChord();
      } else {
        _generaStrutturaDaTesto(brano?["testo"] ?? widget.testoCompleto);
      }

      _preferFlats = _calcolaPreferenzaBemolli();
      _impaginaTesto();
      _initialized = true;
    });
  }

  void _assicuraOriginalChord() {
    for (var riga in _strutturaCompleta) {
      if (riga['tipo'] == 'accordi') {
        for (var acc in riga['accordi']) {
          if (acc['originalChord'] == null) {
            acc['originalChord'] = acc['text'];
          }
          if (acc['fontSize'] == null) acc['fontSize'] = 16.0;
        }
      }
    }
  }

  bool _calcolaPreferenzaBemolli() {
    int flats = 0;
    int sharps = 0;
    for (var riga in _strutturaCompleta) {
      if (riga['tipo'] == 'accordi') {
        for (var acc in riga['accordi']) {
          String t = acc['originalChord'] ?? acc['text'];
          if (RegExp(r'[A-G]b|SIb|LAb|SOLb|MIb|REb').hasMatch(t)) flats++;
          if (t.contains('#')) sharps++;
        }
      }
    }
    return flats > sharps;
  }

  void _generaStrutturaDaTesto(String testo) {
    final linee = testo.split('\n');
    _strutturaCompleta = linee.map((l) {
      bool hasMarker = l.startsWith("[AC]");
      bool isAccordi = !l.contains(boldTag) && (hasMarker || ChordUtils.isPureChordLine(l));
      String rigaPulita = hasMarker ? l.substring(4) : l;

      List<Map<String, dynamic>> accordiList = [];
      if (isAccordi) {
        final matches = ChordUtils.chordRegex.allMatches(rigaPulita);
        for (var m in matches) {
          String chord = m.group(0)!;
          accordiList.add({
            'originalChord': chord,
            'text': chord,
            'x': m.start * 10.6,
            'fontSize': 16.0,
          });
        }
      }

      return {
        'tipo': isAccordi ? 'accordi' : (l.trim().isEmpty ? 'vuota' : 'testo'),
        'testo': isAccordi ? "" : rigaPulita,
        'accordi': accordiList,
        'controller': isAccordi || l.trim().isEmpty 
            ? null 
            : (BoldTextEditingController()..text = rigaPulita),
      };
    }).toList();
  }

  void _impaginaTesto() {
    const int maxRighePerPagina = 24; 
    _pagine = [];
    List<dynamic> paginaCorrente = [];

    for (int i = 0; i < _strutturaCompleta.length; i++) {
      var riga = _strutturaCompleta[i];
      paginaCorrente.add(riga);

      if (paginaCorrente.length >= maxRighePerPagina) {
        if (riga['tipo'] == 'accordi' && i < _strutturaCompleta.length - 1) {
          paginaCorrente.removeLast();
          _pagine.add(List.from(paginaCorrente));
          paginaCorrente = [riga];
        } else {
          _pagine.add(List.from(paginaCorrente));
          paginaCorrente = [];
        }
      }
    }
    if (paginaCorrente.isNotEmpty) _pagine.add(paginaCorrente);
  }

  void _applicaGrassetto(TextEditingController controller) {
    _saveSnapshot();
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final text = controller.text;
    final selectedText = selection.textInside(text);
    const tag = BoldTextEditingController.boldTag;
    String newText;
    if (selectedText.startsWith(tag) && selectedText.endsWith(tag)) {
      newText = text.replaceRange(selection.start, selection.end, selectedText.replaceAll(tag, ''));
    } else {
      newText = text.replaceRange(selection.start, selection.end, '$tag$selectedText$tag');
    }
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }

  void _cancellaSelezione(TextEditingController controller) {
    _saveSnapshot();
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final newText = controller.text.replaceRange(selection.start, selection.end, '');
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }

  void _inserisciRiga(int index, String tipo) {
    _saveSnapshot();
    setState(() {
      Map<String, dynamic> nuovaRiga = {
        'tipo': tipo,
        'testo': '',
        'accordi': [],
        'controller': tipo == 'testo' ? BoldTextEditingController() : null,
      };
      _strutturaCompleta.insert(index < 0 ? 0 : index, nuovaRiga);
      _impaginaTesto();
    });
  }

  void _mostraMenuSpaziatura(int indexInStruttura) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF212121),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("COSA E DOVE INSERIRE?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
              ),
              const Divider(color: Colors.white12),
              const Text("INSERISCI SOPRA", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _tileOpzioneMini("Testo", Icons.text_fields, Colors.orange, () => _inserisciRiga(indexInStruttura, 'testo')),
                  _tileOpzioneMini("Accordi", Icons.music_note, Colors.blue, () => _inserisciRiga(indexInStruttura, 'accordi')),
                  _tileOpzioneMini("Vuota", Icons.space_bar, Colors.grey, () => _inserisciRiga(indexInStruttura, 'vuota')),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(color: Colors.white12),
              const Text("INSERISCI SOTTO", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _tileOpzioneMini("Testo", Icons.text_fields, Colors.orange, () => _inserisciRiga(indexInStruttura + 1, 'testo')),
                  _tileOpzioneMini("Accordi", Icons.music_note, Colors.blue, () => _inserisciRiga(indexInStruttura + 1, 'accordi')),
                  _tileOpzioneMini("Vuota", Icons.space_bar, Colors.grey, () => _inserisciRiga(indexInStruttura + 1, 'vuota')),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileOpzioneMini(String label, IconData icon, Color color, VoidCallback action) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        action();
      },
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _eliminaRiga(int indexInStruttura) {
    if (_strutturaCompleta.length <= 1) return;
    _saveSnapshot();
    setState(() {
      _strutturaCompleta.removeAt(indexInStruttura);
      _impaginaTesto();
    });
  }

  Future<void> _salvaModifiche() async {
    final prefs = await SharedPreferences.getInstance();
    final scalettaStr = prefs.getStringList("scaletta") ?? [];

    for (var riga in _strutturaCompleta) {
      if (riga['tipo'] == 'testo' && riga['controller'] != null) {
        riga['testo'] = riga['controller'].text;
      }
    }

    final branoAggiornato = {
      'titolo': widget.titolo,
      'artista': widget.artista,
      'trasposizione': _trasposizione,
      'struttura_completa': _strutturaCompleta.map((r) => {
        'tipo': r['tipo'],
        'testo': r['testo'],
        'accordi': r['accordi'],
      }).toList(),
      'is_local': true,
    };

    List<String> nuovaScaletta = scalettaStr.where((s) {
      try {
        final b = jsonDecode(s);
        return !(b["titolo"] == widget.titolo && b["artista"] == widget.artista);
      } catch (e) { return true; }
    }).toList();

    nuovaScaletta.add(jsonEncode(branoAggiornato));
    await prefs.setStringList("scaletta", nuovaScaletta);

    // APPLICAZIONE DELLA REGOLA SACRA: Salvataggio fisico e sovrascrittura file esterna
    await FileStorageService.saveSong(branoAggiornato);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Modifiche salvate e file aggiornato!"), duration: Duration(seconds: 1))
      );
    }
  }

  void _trasponi(int semitoni) {
    _saveSnapshot();
    setState(() {
      _trasposizione += semitoni;
      for (var riga in _strutturaCompleta) {
        if (riga['tipo'] == 'accordi') {
          for (var accordo in riga['accordi']) {
            accordo['text'] = ChordTransposer.transposeChord(
                accordo['originalChord'],
                _trasposizione,
                _preferFlats
            );
          }
        }
      }
    });
  }

  Future<void> _avviaEsportazionePdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generazione PDF in corso...")),
    );

    try {
      final doc = await _generaDocumentoPdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: '${widget.titolo}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante l'esportazione: $e")),
        );
      }
    }
  }

  Future<pw.Document> _generaDocumentoPdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoMonoRegular();
    final fontBold = await PdfGoogleFonts.robotoMonoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(widget.titolo.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 18)),
                  pw.Text(widget.artista, style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                  pw.SizedBox(height: 20),
                ],
              ),
            ),
            ..._strutturaCompleta.map((riga) {
              if (riga['tipo'] == 'accordi') {
                return pw.Container(
                  height: 20,
                  child: pw.Stack(
                    children: (riga['accordi'] as List).map((acc) {
                      return pw.Positioned(
                        left: (acc['x'] as num).toDouble() * 0.85, 
                        child: pw.Text(
                          acc['text'],
                          style: pw.TextStyle(font: fontBold, fontSize: (acc['fontSize'] ?? 16.0) - 2, color: PdfColors.blue900),
                        ),
                      );
                    }).toList(),
                  ),
                );
              } else if (riga['tipo'] == 'testo') {
                final String testo = riga['controller'] != null ? riga['controller'].text : riga['testo'];
                final List<pw.TextSpan> spans = [];
                final regex = RegExp(r'(\u200D.*?\u200D|[^\u200D]+)');
                final matches = regex.allMatches(testo);

                for (final match in matches) {
                  final part = match.group(0)!;
                  if (part.startsWith(boldTag) && part.endsWith(boldTag)) {
                    spans.add(pw.TextSpan(
                      text: part.replaceAll(boldTag, ''),
                      style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold),
                    ));
                  } else {
                    spans.add(pw.TextSpan(text: part));
                  }
                }

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.black),
                      children: spans,
                    ),
                  ),
                );
              } else {
                return pw.SizedBox(height: 15);
              }
            }).toList(),
          ];
        },
      ),
    );
    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: _isEditing ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
              itemCount: _pagine.length,
              itemBuilder: (context, pIdx) => _buildPagina(pIdx),
            ),
          ),
          if (_isEditing) _buildToolbarEditing(),
          _buildPageFooter(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isEditing ? const Color(0xFF1A237E) : Colors.black,
      elevation: 0,
      title: GestureDetector(
        onLongPress: () {
          if (!_isEditing) {
            setState(() => _isEditing = true);
          }
        },
        child: Column(
          children: [
            Text(widget.titolo.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(widget.artista, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
      centerTitle: true,
      leadingWidth: _isEditing ? 90 : null,
      leading: _isEditing 
        ? Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.orangeAccent), 
                onPressed: _undoHistory.isNotEmpty ? _undo : null,
              ),
            ],
          )
        : IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      actions: [
        if (!_isEditing)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _avviaEsportazionePdf,
          ),
        if (_isEditing) ...[
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 30),
            onPressed: () {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
            onPressed: () {
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent, size: 28),
            onPressed: () {
              _salvaModifiche();
              setState(() {
                _isEditing = false;
                _undoHistory.clear();
              });
            },
          ),
        ]
      ],
    );
  }

  Widget _buildPagina(int pIdx) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _pagine[pIdx].length,
      itemBuilder: (context, lIdx) {
        final riga = _pagine[pIdx][lIdx];
        
        int globalIdx = 0;
        for(int i=0; i<pIdx; i++) globalIdx += _pagine[i].length;
        globalIdx += lIdx;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_isEditing) 
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _mostraMenuSpaziatura(globalIdx),
                      child: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () => _eliminaRiga(globalIdx),
                      child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: riga['tipo'] == 'accordi' 
                ? ChordRow(
                    accordi: riga['accordi'],
                    isEditing: _isEditing,
                    onChanged: () {
                      _saveSnapshot();
                      setState(() {});
                    },
                    currentTranspose: _trasposizione,
                    preferFlats: _preferFlats,
                  )
                : _buildContenutoTesto(riga),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContenutoTesto(dynamic riga) {
    if (riga['tipo'] == 'vuota' || (riga['testo'].isEmpty && !_isEditing)) return const SizedBox(height: 20);

    if (!_isEditing) {
      final List<TextSpan> children = [];
      final regex = RegExp(r'(\u200D.*?\u200D|[^\u200D]+)');
      final matches = regex.allMatches(riga['testo']);

      for (final match in matches) {
        final part = match.group(0)!;
        if (part.startsWith(boldTag) && part.endsWith(boldTag)) {
          children.add(TextSpan(
            text: part.replaceAll(boldTag, ''),
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
          ));
        } else {
          children.add(TextSpan(text: part, style: const TextStyle(color: Colors.black)));
        }
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 17, fontFamily: 'monospace', height: 1.2, color: Colors.black),
            children: children,
          ),
        ),
      );
    } else {
      return TextField(
        controller: riga['controller'],
        style: const TextStyle(fontFamily: "monospace", fontSize: 17, color: Colors.black),
        maxLines: null,
        decoration: InputDecoration(
          hintText: riga['tipo'] == 'testo' ? "Inserisci testo..." : "",
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          border: InputBorder.none, 
          isDense: true, 
          contentPadding: const EdgeInsets.symmetric(vertical: 8)
        ),
        contextMenuBuilder: (context, editableTextState) {
          return TextSelectionToolbar(
            anchorAbove: editableTextState.contextMenuAnchors.primaryAnchor,
            anchorBelow: editableTextState.contextMenuAnchors.secondaryAnchor ?? editableTextState.contextMenuAnchors.primaryAnchor,
            children: [
              Container(
                decoration: BoxDecoration(color: const Color(0xFF212121), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolbarButton('Copia', () => editableTextState.copySelection(SelectionChangedCause.toolbar)),
                    _vDivider(),
                    _toolbarButton('Incolla', () => editableTextState.pasteText(SelectionChangedCause.toolbar)),
                    _vDivider(),
                    _toolbarButton('Cancella', () {
                      _cancellaSelezione(riga['controller']);
                      editableTextState.hideToolbar();
                    }),
                    _vDivider(),
                    _toolbarButton('GRASSETTO', () {
                      _applicaGrassetto(riga['controller']);
                      editableTextState.hideToolbar();
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _toolbarButton(String label, VoidCallback onPressed, {bool isBold = false}) {
    return TextButton(
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      onPressed: onPressed,
      child: Text(label, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: isBold ? FontWeight.w900 : FontWeight.normal, fontFamily: 'sans-serif')),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 18, color: Colors.white24);

  Widget _buildToolbarEditing() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _circleButton("-", () => _trasponi(-1), Colors.grey.shade700, "Abbassa"),
          const SizedBox(width: 12),
          Container(
            width: 50, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black26)
            ),
            child: Text(
              _trasposizione > 0 ? "+$_trasposizione" : _trasposizione.toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
          ),
          const SizedBox(width: 12),
          _circleButton("+", () => _trasponi(1), Colors.green.shade600, "Alza"),
        ],
      ),
    );
  }

  Widget _circleButton(String symbol, VoidCallback onTap, Color color, String label) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(symbol, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildPageFooter() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedBuilder(
          animation: _pageController,
          builder: (context, _) {
            int current = (_pageController.hasClients ? _pageController.page?.round() ?? 0 : 0) + 1;
            return Text("Pagina $current di ${_pagine.length}", style: TextStyle(color: Colors.grey[400], fontSize: 10));
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var riga in _strutturaCompleta) {
      if (riga['controller'] != null) riga['controller'].dispose();
    }
    super.dispose();
  }
}

class ChordRow extends StatelessWidget {
  final List<dynamic> accordi;
  final bool isEditing;
  final VoidCallback onChanged;
  final int currentTranspose;
  final bool preferFlats;

  const ChordRow({
    super.key, 
    required this.accordi, 
    required this.isEditing, 
    required this.onChanged,
    required this.currentTranspose,
    required this.preferFlats,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: isEditing ? (d) => _gestisciNuovoAccordo(context, d.localPosition.dx) : null,
      child: Container(
        height: 32,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isEditing ? Colors.blue.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isEditing ? Border.all(color: Colors.blue.withValues(alpha: 0.1), width: 0.5) : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: accordi.asMap().entries.map((entry) {
            final idx = entry.key;
            final a = entry.value;
            return Positioned(
              left: (a['x'] as num).toDouble(),
              bottom: 0, 
              child: GestureDetector(
                onHorizontalDragUpdate: isEditing ? (d) => _sposta(idx, d.delta.dx) : null,
                onTap: isEditing ? () => _modificaAccordo(context, idx) : null,
                onLongPress: isEditing ? () => _mostraOpzioniAccordo(context, idx) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: isEditing ? BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    border: Border.all(color: Colors.blue, width: 0.5),
                    borderRadius: BorderRadius.circular(4)
                  ) : null,
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    a['text'],
                    style: TextStyle(
                      fontSize: (a['fontSize'] ?? 16.0).toDouble(),
                      fontWeight: FontWeight.bold,
                      color: isEditing ? Colors.blue[900] : Colors.blue[700],
                      fontFamily: 'monospace',
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _mostraOpzioniAccordo(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text("Modifica Testo"),
            onTap: () {
              Navigator.pop(ctx);
              _modificaAccordo(context, index);
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_size, color: Colors.orange),
            title: const Text("Ridimensiona"),
            onTap: () {
              Navigator.pop(ctx);
              _mostraDialogRidimensiona(context, index);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Elimina Accordo"),
            onTap: () {
              Navigator.pop(ctx);
              _elimina(index);
            },
          ),
        ],
      ),
    );
  }

  void _mostraDialogRidimensiona(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text("Dimensioni Accordo", style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 30),
                    onPressed: () {
                      setLocalState(() {
                        accordi[index]['fontSize'] = (accordi[index]['fontSize'] ?? 16.0) - 1;
                      });
                      onChanged(); 
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      (accordi[index]['fontSize'] ?? 16.0).toInt().toString(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 30),
                    onPressed: () {
                      setLocalState(() {
                        accordi[index]['fontSize'] = (accordi[index]['fontSize'] ?? 16.0) + 1;
                      });
                      onChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text("Anteprima in diretta attiva", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CHIUDI", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _sposta(int index, double dx) {
    accordi[index]['x'] = (accordi[index]['x'] as num).toDouble() + dx;
    onChanged();
  }

  void _elimina(int index) {
    accordi.removeAt(index);
    onChanged();
  }

  Future<void> _modificaAccordo(BuildContext context, int index) async {
    final controller = TextEditingController(text: accordi[index]['text']);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifica Accordo"),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: "es. Do#m7")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULLA")),
          TextButton(onPressed: () {
            accordi[index]['text'] = controller.text;
            accordi[index]['originalChord'] = ChordTransposer.transposeChord(
              controller.text, 
              -currentTranspose, 
              preferFlats
            );
            onChanged();
            Navigator.pop(ctx);
          }, child: const Text("OK")),
        ],
      ),
    );
  }

  void _gestisciNuovoAccordo(BuildContext context, double x) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nuovo Accordo"),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: "es. Re7")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULLA")),
          TextButton(onPressed: () {
            if (controller.text.isNotEmpty) {
              accordi.add({
                'text': controller.text,
                'originalChord': ChordTransposer.transposeChord(controller.text, -currentTranspose, preferFlats),
                'x': x,
                'fontSize': 16.0,
              });
              onChanged();
            }
            Navigator.pop(ctx);
          }, child: const Text("AGGIUNGI")),
        ],
      ),
    );
  }
}