import 'package:uuid/uuid.dart';
import '../services/file_storage_service.dart';

class SongRepository {
  SongRepository._privateConstructor();
  static final SongRepository instance = SongRepository._privateConstructor();

  final Uuid _uuid = const Uuid();

  /// Carica tutti i brani dalla cartella locale
  Future<List<Map<String, dynamic>>> getSongs() async {
    return await FileStorageService.loadAllSongs();
  }

  /// Salva TUTTI i brani uno per uno nella cartella locale
  Future<void> saveSongs(List<Map<String, dynamic>> songs) async {
    for (final song in songs) {
      await FileStorageService.saveSong(song);
    }
  }

  /// Crea un nuovo brano e lo salva come file .mysongbook
  Future<void> createSong({
    required String title,
    required String artist,
    required List<String> lines,
    required int transpose,
  }) async {
    final newSong = {
      "id": _uuid.v4(),
      "title": title,
      "artist": artist,
      "lines": lines,
      "transpose": transpose,
      "deleted": false,
    };

    await FileStorageService.saveSong(newSong);
  }

  /// Aggiorna un brano esistente
  Future<void> updateSong(String id, Map<String, dynamic> updated) async {
    await FileStorageService.saveSong(updated);
  }

  /// Segna un brano come eliminato
  Future<void> deleteSong(String id) async {
    final songs = await getSongs();
    final index = songs.indexWhere((s) => s["id"] == id);
    if (index == -1) return;

    songs[index]["deleted"] = true;
    await FileStorageService.saveSong(songs[index]);
  }

  /// Ripristina un brano eliminato
  Future<void> restoreSong(String id) async {
    final songs = await getSongs();
    final index = songs.indexWhere((s) => s["id"] == id);
    if (index == -1) return;

    songs[index]["deleted"] = false;
    await FileStorageService.saveSong(songs[index]);
  }
}
