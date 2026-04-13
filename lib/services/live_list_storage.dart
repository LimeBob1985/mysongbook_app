import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_list.dart';

class LiveListStorage {
  static const String _key = 'live_lists';

  Future<List<LiveList>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    final List decoded = json.decode(jsonString);
    return decoded.map((e) => LiveList.fromJson(e)).toList();
  }

  Future<void> saveLists(List<LiveList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(lists.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}
