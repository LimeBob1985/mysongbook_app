import 'package:shared_preferences/shared_preferences.dart';

class ScalettaReset {
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("scaletta", []);
  }
}
