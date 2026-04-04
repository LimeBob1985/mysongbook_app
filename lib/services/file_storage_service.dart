import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  static Directory? _folder;

  /// Restituisce la cartella MySongBookScaletta, creandola se non esiste
  static Future<Directory> getFolder() async {
    if (_folder != null) return _folder!;

    // 🔥 DEVE ESSERE DOCUMENTS per essere visibile nell’app File
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory("${baseDir.path}/MySongBookScaletta");

    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        print("Errore creazione cartella: $e");
      }
    }

    _folder = dir;
    return dir;
  }

  /// Salva un singolo brano come file .mysongbook
  static Future<void> saveSong(Map<String, dynamic> song) async {
    final dir = await getFolder();

    final safeTitle = song["titolo"]
        .toString()
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), "_");

    final file = File("${dir.path}/$safeTitle.mysongbook");

    try {
      await file.writeAsString(jsonEncode(song), flush: true);
      print("🔥 Salvato file in: ${file.path}");
    } catch (e) {
      print("Errore salvataggio file $safeTitle: $e");
    }
  }

  /// Carica tutti i file presenti nella cartella
  static Future<List<Map<String, dynamic>>> loadAllSongs() async {
    final dir = await getFolder();
    final files = dir.listSync().whereType<File>().toList();

    List<Map<String, dynamic>> songs = [];

    for (final f in files) {
      try {
        final content = await f.readAsString();
        final decoded = jsonDecode(content);

        if (decoded is Map<String, dynamic>) {
          songs.add(decoded);
        }
      } catch (e) {
        print("Errore lettura file ${f.path}: $e");
      }
    }

    return songs;
  }

  /// Elimina fisicamente un file .mysongbook
  static Future<void> deleteSong(Map<String, dynamic> song) async {
    final dir = await getFolder();

    final safeTitle = song["titolo"]
        .toString()
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), "_");

    final file = File("${dir.path}/$safeTitle.mysongbook");

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print("Errore eliminazione file $safeTitle: $e");
    }
  }
}
