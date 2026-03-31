import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/chord_utils.dart';
import '../services/chord_transposer.dart';

// --- CONTROLLER PER IL GRASSETTO (DAL FILE COMPONI) ---
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

class _LetturaSpartitoScreenState extends State<LetturaSpartitoScreen> {
  late int _trasposizione;
  late PageController _pageController;
  List<dynamic> _strutturaCompleta = [];
  List<List<dynamic>> _pagine = [];
  bool _isEditing = false;
  bool _initialized = false;
  late bool _preferFlats;

  static const String boldTag = '\u200D';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _caricaDati();
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
            'x': m.start * 10.6
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
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final newText = controller.text.replaceRange(selection.start, selection.end, '');
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }

  void _inserisciRiga(int index, String tipo) {
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
      final b = jsonDecode(s);
      return !(b["titolo"] == widget.titolo && b["artista"] == widget.artista);
    }).toList();

    nuovaScaletta.add(jsonEncode(branoAggiornato));
    await prefs.setStringList("scaletta", nuovaScaletta);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Modifiche salvate!"), duration: Duration(seconds: 1))
      );
    }
  }

  void _trasponi(int semitoni) {
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
      title: Column(
        children: [
          Text(widget.titolo.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(widget.artista, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
      centerTitle: true,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      actions: [
        IconButton(
          icon: Icon(
            _isEditing ? Icons.check : Icons.edit,
            color: _isEditing ? Colors.greenAccent : Colors.white,
            size: _isEditing ? 28 : 24,
          ),
          onPressed: () {
            if (_isEditing) _salvaModifiche();
            setState(() => _isEditing = !_isEditing);
          },
        ),
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
                    onChanged: () => setState(() {}),
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
                    }, isBold: true),
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
              child: GestureDetector(
                onHorizontalDragUpdate: isEditing ? (d) => _sposta(idx, d.delta.dx) : null,
                onTap: isEditing ? () => _modificaAccordo(context, idx) : null,
                onLongPress: isEditing ? () => _mostraOpzioniAccordo(context, idx) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: isEditing ? BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue, width: 1),
                    borderRadius: BorderRadius.circular(4)
                  ) : null,
                  child: Text(
                    a['text'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isEditing ? Colors.blue[900] : Colors.blue[700],
                      fontFamily: 'monospace',
                      letterSpacing: 0,
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
            title: const Text("Modifica Accordo"),
            onTap: () {
              Navigator.pop(ctx);
              _modificaAccordo(context, index);
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
    final nuovo = await _mostraDialog(context, controller);
    if (nuovo != null && nuovo.isNotEmpty) {
      String original = currentTranspose == 0 
          ? nuovo 
          : ChordTransposer.transposeChord(nuovo, -currentTranspose, preferFlats);
          
      accordi[index]['text'] = nuovo;
      accordi[index]['originalChord'] = original;
      onChanged();
    }
  }

  Future<void> _gestisciNuovoAccordo(BuildContext context, double dx) async {
    final controller = TextEditingController();
    final nuovo = await _mostraDialog(context, controller);
    if (nuovo != null && nuovo.isNotEmpty) {
      String original = currentTranspose == 0 
          ? nuovo 
          : ChordTransposer.transposeChord(nuovo, -currentTranspose, preferFlats);

      accordi.add({
        'text': nuovo,
        'originalChord': original,
        'x': dx
      });
      onChanged();
    }
  }

  // --- NUOVA FINESTRA DI DIALOGO ---
  Future<String?> _mostraDialog(BuildContext context, TextEditingController ctrl) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontFamily: "monospace",
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.blue,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'DO#m7',
                      hintStyle: TextStyle(color: Colors.black12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () => ctrl.clear(),
                ),
              ],
            ),
            const Divider(color: Colors.blue, thickness: 2),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("ANNULLA", style: TextStyle(color: Colors.black54, fontSize: 13))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), 
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}