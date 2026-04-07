import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/chord_utils.dart';
import '../services/chord_transposer.dart'; 
import 'scaletta_screen.dart';

class AnteprimaSpartitoScreen extends StatefulWidget {
  final String titolo;
  final String artista;
  final String testoOriginale;
  final int trasposizioneIniziale;

  const AnteprimaSpartitoScreen({
    super.key,
    required this.titolo,
    required this.artista,
    required this.testoOriginale,
    required this.trasposizioneIniziale,
  });

  @override
  State<AnteprimaSpartitoScreen> createState() => _AnteprimaSpartitoScreenState();
}

class _AnteprimaSpartitoScreenState extends State<AnteprimaSpartitoScreen> with WidgetsBindingObserver {
  late String testoOriginale;
  late int trasposizione;
  late List<String> righeOriginali;
  late List<bool> rigaEAccordo;
  late bool preferFlats; 
  
  Map<int, List<Map<String, dynamic>>> accordiPosizionati = {};

  final TextStyle _monoStyle = const TextStyle(
    fontFamily: 'monospace',
    fontSize: 17,
    height: 1.2,
    letterSpacing: 0,
    color: Colors.black,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    testoOriginale = widget.testoOriginale;
    trasposizione = widget.trasposizioneIniziale;
    righeOriginali = testoOriginale.split('\n');
    rigaEAccordo = List<bool>.filled(righeOriginali.length, false);
    
    preferFlats = _calcolaPreferenzaBemolli(testoOriginale);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _salvaInScaletta(automatico: true);
    }
  }

  bool _calcolaPreferenzaBemolli(String t) {
    int flatCount = RegExp(r'[A-G]b|SIb|LAb|SOLb|MIb|REb').allMatches(t).length;
    int sharpCount = '#'.allMatches(t).length;
    return flatCount > sharpCount;
  }

  double _getPreciseX(String riga, int charIndex) {
    if (charIndex == 0) return 0.0;
    final textBefore = riga.substring(0, charIndex);
    final textPainter = TextPainter(
      text: TextSpan(text: textBefore, style: _monoStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  void _convertiInOggetti(int index) {
    if (accordiPosizionati.containsKey(index)) return;
    
    String rigaRaw = righeOriginali[index];
    final matches = ChordUtils.chordRegex.allMatches(rigaRaw);
    List<Map<String, dynamic>> lista = [];
    
    for (var m in matches) {
      String chordText = m.group(0)!;
      String displayedChord = trasposizione == 0 
          ? chordText 
          : ChordTransposer.transposeChord(chordText, trasposizione, preferFlats);

      lista.add({
        'originalChord': chordText,
        'text': displayedChord,
        'x': _getPreciseX(rigaRaw, m.start), 
      });
    }
    setState(() {
      accordiPosizionati[index] = lista;
    });
  }

  void _trasponi(int semitoni) {
    setState(() {
      trasposizione += semitoni;
      accordiPosizionati.forEach((rigaIdx, lista) {
        for (var acc in lista) {
          acc['text'] = ChordTransposer.transposeChord(acc['originalChord'], trasposizione, preferFlats);
        }
      });
    });
  }

  Future<void> _salvaInScaletta({bool automatico = false}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = prefs.getStringList("scaletta") ?? [];

    List<Map<String, dynamic>> strutturaCompleta = [];
    for (int i = 0; i < righeOriginali.length; i++) {
      String rigaCorrente = righeOriginali[i];
      
      if (rigaEAccordo[i]) {
        // Se è riga d'accordi, salviamo gli oggetti accordo ma NON perdiamo il riferimento al testo originale
        strutturaCompleta.add({
          'tipo': 'accordi',
          'testo': rigaCorrente, // Mantengo il testo originale per coerenza
          'accordi': accordiPosizionati[i] ?? [],
        });
      } else {
        // Se è riga di testo, salviamo il testo normale
        strutturaCompleta.add({
          'tipo': rigaCorrente.trim().isEmpty ? 'vuota' : 'testo',
          'testo': rigaCorrente,
          'accordi': [],
        });
      }
    }

    final Map<String, dynamic> brano = {
      "titolo": widget.titolo,
      "artista": widget.artista,
      "testo": testoOriginale, // Campo standard per ScalettaScreen
      "testo_originale": testoOriginale,
      "trasposizione": trasposizione,
      "struttura_completa": strutturaCompleta,
      "is_local": true,
    };

    lista.removeWhere((item) {
      try {
        final m = jsonDecode(item);
        return m["titolo"] == widget.titolo && m["artista"] == widget.artista;
      } catch (e) { return false; }
    });

    lista.add(jsonEncode(brano));
    await prefs.setStringList("scaletta", lista);
    
    if (!automatico) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ScalettaScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 80,
            color: Colors.black,
            alignment: Alignment.center,
            child: SafeArea(child: Image.asset("assets/images/logo_horizontal.png", height: 36)),
          ),
          _buildToolbar(),
          Expanded(
            child: Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.titolo.toUpperCase(), 
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                          if (widget.artista.isNotEmpty)
                            Text(widget.artista, 
                              style: const TextStyle(fontSize: 16, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (int i = 0; i < righeOriginali.length; i++)
                      _buildLineRow(i),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineRow(int i) {
    bool isEmpty = righeOriginali[i].trim().isEmpty;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            child: !isEmpty ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTypeButton(Icons.music_note, rigaEAccordo[i], () {
                  setState(() {
                    rigaEAccordo[i] = true;
                    _convertiInOggetti(i);
                  });
                }),
                const SizedBox(width: 4),
                _buildTypeButton(Icons.title, !rigaEAccordo[i], () {
                  setState(() => rigaEAccordo[i] = false);
                }),
              ],
            ) : const SizedBox(),
          ),
          
          Expanded(
            child: Stack(
              children: [
                Opacity(
                  opacity: 0,
                  child: Text(righeOriginali[i], style: _monoStyle),
                ),
                Positioned.fill(
                  child: rigaEAccordo[i] 
                    ? ChordRowPreview(
                        accordi: accordiPosizionati[i] ?? [],
                        onChanged: () => setState(() {}),
                        textStyle: _monoStyle,
                      )
                    : Text(
                        righeOriginali[i].isEmpty ? " " : righeOriginali[i],
                        style: _monoStyle,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isActive ? Colors.blue : Colors.grey.shade400),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey.shade600),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
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
              trasposizione > 0 ? "+$trasposizione" : trasposizione.toString(), 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
          ),
          const SizedBox(width: 12),
          _circleButton("+", () => _trasponi(1), Colors.green.shade600, "Alza"),
          const Spacer(),
          ElevatedButton(
            onPressed: () => _salvaInScaletta(automatico: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("SALVA IN SCALETTA", 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
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
}

class ChordRowPreview extends StatelessWidget {
  final List<Map<String, dynamic>> accordi;
  final VoidCallback onChanged;
  final TextStyle textStyle;

  const ChordRowPreview({
    super.key, 
    required this.accordi, 
    required this.onChanged,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue.withValues(alpha: 0.05),
      child: Stack(
        clipBehavior: Clip.none,
        children: accordi.map((a) {
          return Positioned(
            left: (a['x'] as num).toDouble(),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                a['x'] = (a['x'] as num).toDouble() + details.delta.dx;
                onChanged();
              },
              child: Container(
                padding: EdgeInsets.zero,
                child: Text(
                  a['text'],
                  style: textStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    backgroundColor: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}