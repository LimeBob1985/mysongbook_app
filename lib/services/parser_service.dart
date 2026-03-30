import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

class ParserService {
  static Future<Map<String, String>> estraiDaLink(String url) async {
    try {
      print("DEBUG: URL ricevuto = '$url'");

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print("DEBUG: response.statusCode = ${response.statusCode}");
        return {
          "titolo": "Titolo sconosciuto",
          "artista": "Artista sconosciuto",
          "testo": "",
        };
      }

      final document = html.parse(response.body);

      String titolo = "";
      String artista = "Artista sconosciuto";

      // ----------------------------------------------------
      // FUNZIONE: normalizzazione apostrofi (Invariata)
      // ----------------------------------------------------
      String normalizzaApostrofi(String input) {
        final mappa = {
          "dont": "don't",
          "wont": "won't",
          "cant": "can't",
          "couldnt": "couldn't",
          "shouldnt": "shouldn't",
          "wouldnt": "wouldn't",
          "isnt": "isn't",
          "arent": "aren't",
          "wasnt": "wasn't",
          "werent": "weren't",
          "im": "i'm",
          "ill": "i'll",
          "ive": "i've",
          "id": "i'd",
          "youre": "you're",
          "youve": "you've",
          "youll": "you'll",
          "theyre": "they're",
          "theyve": "they've",
          "theyll": "they'll",
          "weve": "we've",
          "we're": "we're",
          "we'll": "we'll",
        };

        final parole = input.split(" ");

        final corrette = parole.map((p) {
          final lower = p.toLowerCase();
          if (mappa.containsKey(lower)) {
            final corretto = mappa[lower]!;
            return corretto[0].toUpperCase() + corretto.substring(1);
          }
          return p;
        }).toList();

        return corrette.join(" ");
      }

      // ----------------------------------------------------
      // FUNZIONE: pulizia intelligente del titolo (Potenziata)
      // ----------------------------------------------------
      String pulisciTitolo(String slug) {
        final blacklist = [
          "chords",
          "accordi",
          "lyrics",
          "testo",
          "spartito",
          "tabs",
          "tab",
          "chitarra"
        ];

        // Rimuove eventuali numeri di versione finali come "-2"
        String tempSlug = slug.replaceAll(RegExp(r'-\d+$'), "");
        
        final parole = tempSlug.split("-");

        final filtrate = parole.where(
          (p) => !blacklist.contains(p.toLowerCase()),
        );

        final titoloPulito = filtrate.join(" ").trim();

        final capitalizzato = titoloPulito.split(" ").map((w) {
          if (w.isEmpty) return "";
          return w[0].toUpperCase() + w.substring(1);
        }).join(" ");

        return normalizzaApostrofi(capitalizzato);
      }

      // ----------------------------------------------------
      // ACCORDI & SPARTITI: estrazione da URL
      // ----------------------------------------------------
      final normalizedUrl = url.toLowerCase().replaceAll("www.", "").trim();
      print("DEBUG: normalizedUrl = '$normalizedUrl'");

      if (normalizedUrl.contains("accordiespartiti.it/accordi/")) {
        print("DEBUG: ENTRATO nel blocco Accordi&Spartiti");

        final uri = Uri.parse(url); // Uso url originale per non perdere case-sensitivity utile
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        print("DEBUG: segments = $segments");

        if (segments.length >= 3) {
          // Solitamente: /accordi/genere/artista/titolo
          // Ma se i segmenti sono molti, l'artista è il penultimo e il titolo l'ultimo
          final artistaSlug = segments[segments.length - 2];
          final titoloSlug = segments[segments.length - 1];

          print("DEBUG: artistaSlug = $artistaSlug");
          print("DEBUG: titoloSlug  = $titoloSlug");

          // ARTISTA
          artista = artistaSlug
              .replaceAll("-", " ")
              .trim()
              .split(" ")
              .map((w) => w.isEmpty ? "" : w[0].toUpperCase() + w.substring(1))
              .join(" ");

          // TITOLO (ripulito + apostrofi)
          titolo = pulisciTitolo(titoloSlug);

          // ----------------------------------------------------
          // RIMOZIONE AVANZATA DELL’ARTISTA NEL TITOLO
          // ----------------------------------------------------
          // Alcuni URL hanno "le-vibrazioni-vieni-da-me..."
          // Puliamo se il titolo inizia con il nome dell'artista
          String titoloLower = titolo.toLowerCase();
          String artistaLower = artista.toLowerCase();

          if (titoloLower.startsWith(artistaLower)) {
            titolo = titolo.substring(artista.length).trim();
          }
          
          // Rimuove eventuali trattini o spazi rimasti in testa dopo la pulizia
          titolo = titolo.replaceFirst(RegExp(r"^[-–—\s]+"), "").trim();

          print("DEBUG: artista finale = $artista");
          print("DEBUG: titolo finale  = $titolo");
        } else {
          print("DEBUG: segments troppo pochi, length = ${segments.length}");
        }
      } else {
        print("DEBUG: NON entrato nel blocco Accordi&Spartiti");
      }

      // ----------------------------------------------------
      // TESTO + ACCORDI (Invariato)
      // ----------------------------------------------------
      final preTag = document.querySelector("pre");
      final testo = preTag?.text.trim() ?? "";
      final preview = testo.length > 50 ? testo.substring(0, 50) : testo;
      print("DEBUG: primi 50 caratteri testo = '$preview'");

      return {
        "titolo": titolo.isEmpty ? "Titolo sconosciuto" : titolo,
        "artista": artista.isEmpty ? "Artista sconosciuto" : artista,
        "testo": testo,
      };
    } catch (e) {
      print("DEBUG: ERRORE in estraiDaLink → $e");
      return {
        "titolo": "Titolo sconosciuto",
        "artista": "Artista sconosciuto",
        "testo": "",
      };
    }
  }
}