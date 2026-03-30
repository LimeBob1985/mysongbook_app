import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class SongRepository {
  SongRepository._privateConstructor();
  static final SongRepository instance = SongRepository._privateConstructor();

  final Uuid _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> getSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('songs');
    if (jsonString == null) return [];
    return List<Map<String, dynamic>>.from(json.decode(jsonString));
  }

  Future<void> saveSongs(List<Map<String, dynamic>> songs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('songs', json.encode(songs));
  }

  Future<void> createSong({
    required String title,
    required String artist,
    required List<String> lines,
    required int transpose,
  }) async {
    final songs = await getSongs();

    songs.add({
      "id": _uuid.v4(),
      "title": title,
      "artist": artist,
      "lines": lines,
      "transpose": transpose,
      "deleted": false,
    });

    await saveSongs(songs);
  }

  Future<void> updateSong(String id, Map<String, dynamic> updated) async {
    final songs = await getSongs();
    final index = songs.indexWhere((s) => s["id"] == id);
    if (index == -1) return;

    songs[index] = updated;
    await saveSongs(songs);
  }

  Future<void> deleteSong(String id) async {
    final songs = await getSongs();
    final index = songs.indexWhere((s) => s["id"] == id);
    if (index == -1) return;

    songs[index]["deleted"] = true;
    await saveSongs(songs);
  }

  Future<void> restoreSong(String id) async {
    final songs = await getSongs();
    final index = songs.indexWhere((s) => s["id"] == id);
    if (index == -1) return;

    songs[index]["deleted"] = false;
    await saveSongs(songs);
  }
}
