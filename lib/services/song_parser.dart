import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

class SongParserResult {
  final String title;
  final String artist;
  final List<String> lines;

  SongParserResult({
    required this.title,
    required this.artist,
    required this.lines,
  });
}

class SongParser {
  static Future<SongParserResult> parseFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception("Impossibile caricare la pagina");
    }

    final document = html.parse(response.body);

    // TITOLO
    final titleElement = document.querySelector("h1");
    String title = titleElement?.text.trim() ?? "Titolo sconosciuto";

    // ARTISTA
    String artist = "Artista sconosciuto";
    final artist1 = document.querySelector(".artist a");
    if (artist1 != null) artist = artist1.text.trim();

    final artist2 = document.querySelector(".artist");
    if (artist == "Artista sconosciuto" && artist2 != null) {
      artist = artist2.text.trim();
    }

    if (artist == "Artista sconosciuto" && title.contains(" - ")) {
      artist = title.split(" - ").last.trim();
    }

    // TESTO + ACCORDI
    final preElement = document.querySelector("pre");
    if (preElement == null) {
      throw Exception("Struttura HTML non riconosciuta");
    }

    // --- CORREZIONE TRONCAMENTO ---
    // Invece di prendere solo .text, puliamo i caratteri speciali invisibili
    // che spesso i siti inseriscono tra le lettere (es. &nbsp; o tag vuoti)
    String rawText = preElement.innerHtml
        .replaceAll(RegExp(r'<[^>]*>'), '') // Rimuove eventuali tag HTML residui
        .replaceAll('&nbsp;', ' ')          // Converte spazi HTML in spazi normali
        .replaceAll('&amp;', '&');          // Converte caratteri speciali

    // Dividiamo in righe mantenendo l'integrità
    final lines = rawText.split("\n").map((l) => l.trimRight()).toList();

    return SongParserResult(
      title: title,
      artist: artist,
      lines: lines,
    );
  }
}