import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  /// Restituisce la cartella DOCUMENTS visibile nell’app File (iOS)
  static Future<Directory> getFolder() async {
    final dir = await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Genera un nome file sicuro combinando titolo e artista
  static String _getFileName(Map<String, dynamic> song) {
    final titolo = (song["titolo"] ?? "SenzaTitolo").toString().trim();
    final artista = (song["artista"] ?? "Ignoto").toString().trim();

    // Rimuove caratteri non validi per i nomi file su iOS/Android
    final safeName = "${titolo}_$artista"
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), "_");

    return "$safeName.mysongbook";
  }

  /// Salva un singolo brano come file .mysongbook
  static Future<void> saveSong(Map<String, dynamic> song) async {
    try {
      final dir = await getFolder();
      final fileName = _getFileName(song);
      final file = File("${dir.path}/$fileName");

      await file.writeAsString(jsonEncode(song), flush: true);

      print("📁 Salvato: ${file.path}");
    } catch (e) {
      print("❌ Errore salvataggio file: $e");
    }
  }

  /// Carica tutti i file .mysongbook presenti nella cartella
  static Future<List<Map<String, dynamic>>> loadAllSongs() async {
    try {
      final dir = await getFolder();
      final List<FileSystemEntity> entities = dir.listSync();

      List<Map<String, dynamic>> songs = [];

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith(".mysongbook")) {
          try {
            final content = await entity.readAsString();
            final Map<String, dynamic> decoded = jsonDecode(content);

            // Mapping uniforme e compatibile con ScalettaScreen
            final testo = decoded["testo"]
                ?? decoded["testo_originale"]
                ?? decoded["content"]
                ?? "";

            songs.add({
              "titolo": decoded["titolo"] ?? decoded["title"] ?? "Senza Titolo",
              "artista": decoded["artista"] ?? decoded["artist"] ?? "Artista Sconosciuto",
              "testo": testo,
              "trasposizione": decoded["trasposizione"] ?? 0,

              // Manteniamo questi campi se presenti
              "righe": decoded["righe"],
              "struttura_completa": decoded["struttura_completa"],
            });
          } catch (e) {
            print("❌ Errore parsing file ${entity.path}: $e");
          }
        }
      }

      return songs;
    } catch (e) {
      print("❌ Errore caricamento cartella: $e");
      return [];
    }
  }

  /// Elimina fisicamente un file .mysongbook
  static Future<void> deleteSong(Map<String, dynamic> song) async {
    try {
      final dir = await getFolder();
      final fileName = _getFileName(song);
      final file = File("${dir.path}/$fileName");

      if (await file.exists()) {
        await file.delete();
        print("🗑️ Eliminato: ${file.path}");
      } else {
        print("ℹ️ Nessun file da eliminare: ${file.path}");
      }
    } catch (e) {
      print("❌ Errore eliminazione file: $e");
    }
  }
}
