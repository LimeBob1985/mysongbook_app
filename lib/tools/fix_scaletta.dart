import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScalettaFixer {
  static Future<void> ripristinaTestiOriginali() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList("scaletta") ?? [];

    final nuovaLista = <String>[];

    for (final item in lista) {
      final map = Map<String, dynamic>.from(jsonDecode(item));

      final testoOriginale = map["testo_originale"]?.toString() ?? "";
      final testoTrasposto = map["testo"]?.toString() ?? "";

      // rileva testo corrotto
      final bool corrotto =
          testoOriginale.isEmpty ||
          testoOriginale.contains("R5A") ||
          testoOriginale.contains("S5A") ||
          testoOriginale.contains("Z6") ||
          testoOriginale.contains(RegExp(r'[0-9][A-Z][0-9]'));

      if (corrotto) {
        // ricostruzione del testo originale rimuovendo gli accordi dal testo trasposto
        final testoRipulito = testoTrasposto
            .replaceAll(RegExp(r'[A-G][#b]?[a-zA-Z0-9/]*'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        map["testo_originale"] = testoRipulito;
      }

      nuovaLista.add(jsonEncode(map));
    }

    await prefs.setStringList("scaletta", nuovaLista);
  }
}
