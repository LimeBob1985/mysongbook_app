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

  /// Genera un nome file stabile e prevedibile
  static String _getFileName(Map<String, dynamic> song) {
    final titolo = (song["titolo"] ?? "senza_titolo").toString().toLowerCase();
    final artista = (song["artista"] ?? "sconosciuto").toString().toLowerCase();

    String normalize(String input) {
      return input
          .replaceAll(RegExp(r'[^a-z0-9]+'), "_")
          .replaceAll(RegExp(r'_+'), "_")
          .replaceAll(RegExp(r'^_|_$'), "");
    }

    final safeTitle = normalize(titolo);
    final safeArtist = normalize(artista);

    return "${safeTitle}_${safeArtist}.mysongbook";
  }

  /// Salva un singolo brano come file .mysongbook
  static Future<void> saveSong(Map<String, dynamic> song) async {
    try {
      final dir = await getFolder();
      final fileName = _getFileName(song);

      // Salviamo il nome file dentro il JSON
      song["fileName"] = fileName;

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

            final testo = decoded["testo"]
                ?? decoded["testo_originale"]
                ?? decoded["content"]
                ?? "";

            songs.add({
              "titolo": decoded["titolo"] ?? decoded["title"] ?? "Senza Titolo",
              "artista": decoded["artista"] ?? decoded["artist"] ?? "Artista Sconosciuto",
              "testo": testo,
              "trasposizione": decoded["trasposizione"] ?? 0,

              // Manteniamo eventuali campi extra
              "righe": decoded["righe"],
              "struttura_completa": decoded["struttura_completa"],

              // Nome file reale
              "fileName": entity.path.split("/").last,
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

  /// Elimina fisicamente un file .mysongbook (anche legacy)
  static Future<void> deleteSong(Map<String, dynamic> song) async {
    try {
      final dir = await getFolder();

      // 1) Tentativo normale: usa fileName se presente, altrimenti _getFileName
      final primaryFileName = song["fileName"] ?? _getFileName(song);
      final primaryFile = File("${dir.path}/$primaryFileName");

      bool deletedSomething = false;

      if (await primaryFile.exists()) {
        await primaryFile.delete();
        print("🗑️ Eliminato (primary): ${primaryFile.path}");
        deletedSomething = true;
      } else {
        print("ℹ️ File primary non trovato: ${primaryFile.path}");
      }

      // 2) FALLBACK: cerca QUALSIASI file .mysongbook con stesso titolo/artista
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith(".mysongbook")) {
          try {
            final content = await entity.readAsString();
            final decoded = jsonDecode(content);

            final titoloFile =
                (decoded["titolo"] ?? decoded["title"] ?? "").toString();
            final artistaFile =
                (decoded["artista"] ?? decoded["artist"] ?? "").toString();

            if (titoloFile == (song["titolo"] ?? "") &&
                artistaFile == (song["artista"] ?? "")) {
              await entity.delete();
              print("🗑️ Eliminato (fallback match titolo/artista): ${entity.path}");
              deletedSomething = true;
            }
          } catch (e) {
            print("❌ Errore lettura file in fallback delete: $e");
          }
        }
      }

      if (!deletedSomething) {
        print("ℹ️ Nessun file eliminato per il brano: ${song["titolo"]} - ${song["artista"]}");
      }
    } catch (e) {
      print("❌ Errore eliminazione file: $e");
    }
  }
}
