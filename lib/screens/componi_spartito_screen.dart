import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BoldTextEditingController extends TextEditingController {
  static const String boldTag = '\u200D';

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final regex = RegExp(r'(\u200D.*?\u200D|[^\u200D]+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith(boldTag) && part.endsWith(boldTag)) {
        children.add(
          TextSpan(
            text: part.replaceAll(boldTag, ''),
            style: style?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        );
      } else {
        children.add(TextSpan(text: part, style: style));
      }
    }
    return TextSpan(style: style, children: children);
  }
}

enum TipoRiga { testo, accordi, vuota }

class ChordInstance {
  String text;
  double x;
  ChordInstance({required this.text, required this.x});
}

class RigaOggetto {
  TipoRiga tipo;
  TextEditingController controller;
  List<ChordInstance> accordi;

  RigaOggetto({
    required this.tipo,
    TextEditingController? controller,
    List<ChordInstance>? accordi,
  })  : controller = controller ?? BoldTextEditingController(),
        accordi = accordi ?? [];
}

class ComponiSpartitoScreen extends StatefulWidget {
  final String titolo;
  final String artista;
  final String testoIniziale;
  final List<dynamic>? righeSalvate;

  const ComponiSpartitoScreen({
    super.key,
    required this.titolo,
    required this.artista,
    required this.testoIniziale,
    this.righeSalvate,
  });

  @override
  State<ComponiSpartitoScreen> createState() => _ComponiSpartitoScreenState();
}

class _ComponiSpartitoScreenState extends State<ComponiSpartitoScreen>
    with WidgetsBindingObserver {
  final List<RigaOggetto> _struttura = [];
  ChordInstance? _selectedChord;
  int? _selectedLineIndex;
  int? _selectedChordIndex;

  final TextStyle _stileAccordi = const TextStyle(
    fontFamily: "RobotoMono",
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: Colors.blue,
  );

  final TextStyle _stileTesto = const TextStyle(
    fontFamily: "RobotoMono",
    fontSize: 17,
    color: Colors.black,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inizializzaStruttura();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var riga in _struttura) {
      riga.controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _salvaProcesso(isBozza: true, isAutomatico: true);
    }
  }

  void _inizializzaStruttura() {
    try {
      // Priorità al caricamento strutturato (JSON)
      if (widget.righeSalvate != null && widget.righeSalvate!.isNotEmpty) {
        for (var r in widget.righeSalvate!) {
          String tipoString = r['tipo'] ?? 'testo';
          TipoRiga tipo = TipoRiga.values.firstWhere(
            (e) => e.name == tipoString,
            orElse: () => TipoRiga.testo,
          );

          List<ChordInstance> accordiCaricati = [];
          if (r['accordi'] != null && r['accordi'] is List) {
            for (var a in r['accordi']) {
              accordiCaricati.add(
                ChordInstance(
                  text: a['text'] ?? "",
                  x: (a['x'] as num? ?? 0.0).toDouble(),
                ),
              );
            }
          }

          _struttura.add(
            RigaOggetto(
              tipo: tipo,
              controller: BoldTextEditingController()..text = r['testo'] ?? "",
              accordi: accordiCaricati,
            ),
          );
        }
      }
      // Caricamento da testo piano (es. prima importazione o stringa salvata)
      else {
        final linee = widget.testoIniziale.split('\n');
        for (String linea in linee) {
          final trimLine = linea.trim();

          if (trimLine.isEmpty) {
            _struttura.add(RigaOggetto(tipo: TipoRiga.vuota));
          }
          // RIGA ACCORDI SOLO SE È ESATTAMENTE "[AC]"
          else if (trimLine == "[AC]") {
            _struttura.add(
              RigaOggetto(
                tipo: TipoRiga.accordi,
                controller: BoldTextEditingController()..text = "",
                accordi: [],
              ),
            );
          }
          // Tutto il resto è SEMPRE testo
          else {
            _struttura.add(
              RigaOggetto(
                tipo: TipoRiga.testo,
                controller: BoldTextEditingController()..text = linea,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Errore nel caricamento struttura: $e");
    }

    if (_struttura.isEmpty) {
      _struttura.add(RigaOggetto(tipo: TipoRiga.testo));
    }
  }

  void _applicaGrassetto(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final text = controller.text;
    final selectedText = selection.textInside(text);
    const tag = BoldTextEditingController.boldTag;
    String newText;
    if (selectedText.startsWith(tag) && selectedText.endsWith(tag)) {
      newText = text.replaceRange(
        selection.start,
        selection.end,
        selectedText.replaceAll(tag, ''),
      );
    } else {
      newText = text.replaceRange(
        selection.start,
        selection.end,
        '$tag$selectedText$tag',
      );
    }
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }

  void _cancellaSelezione(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final newText =
        controller.text.replaceRange(selection.start, selection.end, '');
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }

  void _mostraMenuAggiungi(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                "INSERISCI RIGA",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ),
            _optionTile(index, "Testo sopra", TipoRiga.testo, true),
            _optionTile(index, "Testo sotto", TipoRiga.testo, false),
            const Divider(),
            _optionTile(index, "Accordi sopra", TipoRiga.accordi, true),
            _optionTile(index, "Accordi sotto", TipoRiga.accordi, false),
            const Divider(),
            _optionTile(index, "Vuota sopra", TipoRiga.vuota, true),
            _optionTile(index, "Vuota sotto", TipoRiga.vuota, false),
          ],
        ),
      ),
    );
  }

  ListTile _optionTile(int index, String label, TipoRiga tipo, bool sopra) {
    return ListTile(
      leading: Icon(
        tipo == TipoRiga.testo
            ? Icons.text_fields
            : tipo == TipoRiga.accordi
                ? Icons.music_note
                : Icons.space_bar,
        color: Colors.blue,
      ),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          int pos = sopra ? index : index + 1;
          _struttura.insert(
            pos,
            RigaOggetto(
              tipo: tipo,
              controller:
                  tipo == TipoRiga.testo ? BoldTextEditingController() : null,
            ),
          );
        });
      },
    );
  }

  void _eliminaRiga(int index) {
    if (_struttura.length <= 1) return;
    setState(() {
      _struttura[index].controller.dispose();
      _struttura.removeAt(index);
    });
  }

  void _aggiungiAccordoPrompt(int index, double x) async {
    String? risultato = await _mostraDialogInputAccordo("");
    if (risultato != null && risultato.isNotEmpty) {
      setState(() {
        _struttura[index].accordi.add(
              ChordInstance(text: risultato, x: x),
            );
      });
    }
  }

  void _mostraMenuAccordo(
      ChordInstance chord, int lineIndex, int chordIndex) {
    setState(() {
      _selectedChord = chord;
      _selectedLineIndex = lineIndex;
      _selectedChordIndex = chordIndex;
    });
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifica accordo'),
              onTap: () {
                Navigator.pop(context);
                _modificaAccordoPrompt();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Elimina accordo',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _eliminaAccordo();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _modificaAccordoPrompt() async {
    if (_selectedChord == null) return;
    String? nuovo = await _mostraDialogInputAccordo(_selectedChord!.text);
    if (nuovo != null && nuovo.isNotEmpty) {
      setState(() {
        _selectedChord!.text = nuovo;
      });
    }
    _clearSelection();
  }

  void _eliminaAccordo() {
    if (_selectedLineIndex == null || _selectedChordIndex == null) return;
    setState(() {
      _struttura[_selectedLineIndex!].accordi.removeAt(_selectedChordIndex!);
    });
    _clearSelection();
  }

  void _clearSelection() {
    _selectedChord = null;
    _selectedLineIndex = null;
    _selectedChordIndex = null;
  }

  Future<String?> _mostraDialogInputAccordo(String testoIniziale) {
    TextEditingController controller = TextEditingController(text: testoIniziale);
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
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontFamily: "RobotoMono",
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
                  onPressed: () => controller.clear(),
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
            onPressed: () => Navigator.pop(ctx, controller.text.trim()), 
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          "COMPONI SPARTITO",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Center(
              child: GestureDetector(
                onTap: () => _salvaProcesso(isBozza: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    "BOZZA",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: GestureDetector(
                onTap: () => _salvaProcesso(isBozza: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    "SALVA IN SCALETTA",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _struttura.length,
        itemBuilder: (context, index) => _buildRigaUniversale(index),
      ),
    );
  }

  Widget _buildRigaUniversale(int index) {
    final riga = _struttura[index];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 24),
                  onPressed: () => _mostraMenuAggiungi(index),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 24),
                  onPressed: () => _eliminaRiga(index),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent(riga, index)),
        ],
      ),
    );
  }

  Widget _buildContent(RigaOggetto riga, int index) {
    if (riga.tipo == TipoRiga.accordi) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: (d) => _aggiungiAccordoPrompt(index, d.localPosition.dx),
        child: Container(
          height: 35,
          width: double.infinity,
          color: Colors.transparent,
          child: Stack(
            children: riga.accordi.asMap().entries.map((e) => Positioned(
              left: e.value.x,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => setState(() => e.value.x += d.delta.dx),
                onLongPress: () => _mostraMenuAccordo(e.value, index, e.key),
                child: Text(e.value.text, style: _stileAccordi),
              ),
            )).toList(),
          ),
        ),
      );
    } else if (riga.tipo == TipoRiga.testo) {
      return TextField(
        controller: riga.controller,
        style: _stileTesto,
        maxLines: null,
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
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
                      _cancellaSelezione(riga.controller);
                      editableTextState.hideToolbar();
                    }),
                    _vDivider(),
                    _toolbarButton('GRASSETTO', () {
                      _applicaGrassetto(riga.controller);
                      editableTextState.hideToolbar();
                    }, isBold: true),
                  ],
                ),
              ),
            ],
          );
        },
      );
    } else {
      return const SizedBox(
        height: 35, 
        child: Padding(
          padding: EdgeInsets.only(left: 8, top: 10), 
          child: Text("--- Spazio Vuoto ---", style: TextStyle(color: Colors.grey, fontSize: 12))
        )
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

  void _salvaProcesso({required bool isBozza, bool isAutomatico = false}) async {
    final prefs = await SharedPreferences.getInstance();
    StringBuffer testoPiano = StringBuffer();
    Map<String, dynamic> offsetsMap = {}; 
    const double charWidth = 10.6; 

    for (int i = 0; i < _struttura.length; i++) {
      final riga = _struttura[i];

      if (riga.tipo == TipoRiga.accordi) {
        if (riga.accordi.isEmpty) {
          testoPiano.writeln("[AC]");
          continue;
        }
        riga.accordi.sort((a, b) => a.x.compareTo(b.x)); 
        
        String rigaCostruita = "[AC]"; 
        double currentX = 0;

        for (int c = 0; c < riga.accordi.length; c++) {
          final chord = riga.accordi[c];
          int spaces = ((chord.x - currentX) / charWidth).floor();
          if (spaces < 0) spaces = 1;
          
          rigaCostruita += (" " * spaces) + chord.text;
          currentX = chord.x + (chord.text.length * charWidth);
          offsetsMap['0-$i-$c'] = chord.x;
        }
        testoPiano.writeln(rigaCostruita);
      } 
      else if (riga.tipo == TipoRiga.testo) {
        testoPiano.writeln(riga.controller.text);
      } 
      else {
        testoPiano.writeln(""); 
      }
    }

    final brano = {
      'titolo': widget.titolo,
      'artista': widget.artista,
      'testo_originale': testoPiano.toString(),
      'testo': testoPiano.toString(),
      'trasposizione': 0,
      'offsets': offsetsMap,
      'is_local': true,
      'is_manual': true,
      'righe': _struttura.map((r) => {
        'tipo': r.tipo.name,
        'testo': r.tipo == TipoRiga.testo ? r.controller.text : "",
        'accordi': r.accordi.map((a) => {'text': a.text, 'x': a.x}).toList(),
      }).toList(),
    };

    String key = isBozza ? "bozze" : "scaletta";
    List<String> list = prefs.getStringList(key) ?? [];
    
    list.removeWhere((e) {
      try {
        final m = jsonDecode(e);
        return m['titolo'] == widget.titolo && m['artista'] == widget.artista;
      } catch (e) { return false; }
    });
    
    list.add(jsonEncode(brano));
    await prefs.setStringList(key, list);

    if (!isBozza) {
      List<String> bozzeList = prefs.getStringList("bozze") ?? [];
      bozzeList.removeWhere((e) {
        try {
          final m = jsonDecode(e);
          return m['titolo'] == widget.titolo && m['artista'] == widget.artista;
        } catch (e) { return false; }
      });
      await prefs.setStringList("bozze", bozzeList);
    }

    if (!isAutomatico && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isBozza ? "Salvato nelle Bozze!" : "Spostato in Scaletta!"))
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}