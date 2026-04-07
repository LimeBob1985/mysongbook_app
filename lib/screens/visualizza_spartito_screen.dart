import 'package:flutter/material.dart';

class VisualizzaSpartitoScreen extends StatelessWidget {
  final String titolo;
  final String artista;
  final String testo;

  const VisualizzaSpartitoScreen({
    super.key,
    required this.titolo,
    required this.artista,
    required this.testo,
  });

  @override
  Widget build(BuildContext context) {
    // Dividiamo il testo in righe
    final righe = testo.split("\n");

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header con Logo
          Container(
            height: 70,
            width: double.infinity,
            color: Colors.black,
            alignment: Alignment.center,
            child: Image.asset("assets/images/logo_horizontal.png", height: 36),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intestazione Brano
                  Text(
                    titolo, 
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)
                  ),
                  const SizedBox(height: 6),
                  Text(
                    artista.toUpperCase(), 
                    style: const TextStyle(fontSize: 18, color: Colors.black87)
                  ),
                  const SizedBox(height: 24),

                  // Ciclo di rendering delle righe
                  for (final rigaRaw in righe) ...[
                    _buildRigaParsing(rigaRaw),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRigaParsing(String rigaRaw) {
    // 1. Riconoscimento accordi: RIGOROSAMENTE solo se inizia con [AC]
    // Usiamo trimLeft() per ignorare eventuali spazi iniziali invisibili
    bool isChordLine = rigaRaw.trimLeft().startsWith("[AC]");
    
    // Puliamo la riga dal tag tecnico per la visualizzazione finale
    String rigaPulita = isChordLine ? rigaRaw.replaceFirst("[AC]", "") : rigaRaw;

    // SE È UNA RIGA ACCORDI -> Tutto Blu e Bold
    if (isChordLine) {
      return Text(
        rigaPulita,
        style: const TextStyle(
          fontFamily: "RobotoMono",
          fontSize: 16,
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // 2. SE È UNA RIGA DI TESTO -> Tutto Nero (gestendo il grassetto manuale)
    const String boldTag = '\u200D';
    final List<TextSpan> spans = [];
    
    // Regex per separare le parti avvolte dal tag del grassetto dal resto del testo
    final regex = RegExp(r'(\u200D.*?\u200D|[^\u200D]+)');
    final matches = regex.allMatches(rigaPulita);

    for (final match in matches) {
      final part = match.group(0)!;
      
      if (part.startsWith(boldTag) && part.endsWith(boldTag)) {
        // Parte in grassetto manuale
        spans.add(TextSpan(
          text: part.replaceAll(boldTag, ''),
          style: const TextStyle(
            fontWeight: FontWeight.w900, 
            color: Colors.black, // Obbligatorio nero
          ),
        ));
      } else {
        // Testo normale
        spans.add(TextSpan(
          text: part, 
          style: const TextStyle(
            color: Colors.black, // Obbligatorio nero
            fontWeight: FontWeight.normal,
          ),
        ));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: "RobotoMono", 
          fontSize: 16, 
          height: 1.3,
        ),
        children: spans,
      ),
    );
  }
}