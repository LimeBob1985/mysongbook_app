import '../utils/chord_utils.dart';

class ChordTransposer {
  static const List<String> chromatic = [
    "C", "C#", "D", "D#", "E", "F",
    "F#", "G", "G#", "A", "A#", "B"
  ];

  static const Map<String, String> itToEn = {
    "DO": "C", "DO#": "C#", "DOb": "B",
    "RE": "D", "RE#": "D#", "REb": "C#",
    "MI": "E", "MI#": "F", "MIb": "D#",
    "FA": "F", "FA#": "F#", "FAb": "E",
    "SOL": "G", "SOL#": "G#", "SOLb": "F#",
    "LA": "A", "LA#": "A#", "LAb": "G#",
    "SI": "B", "SI#": "C", "SIb": "A#",
  };

  static const Map<String, String> enToItSharp = {
    "C": "DO", "C#": "DO#", "D": "RE", "D#": "RE#", "E": "MI",
    "F": "FA", "F#": "FA#", "G": "SOL", "G#": "SOL#", "A": "LA",
    "A#": "LA#", "B": "SI",
  };

  static const Map<String, String> enToItFlat = {
    "C": "DO", "C#": "REb", "D": "RE", "D#": "MIb", "E": "MI",
    "F": "FA", "F#": "SOLb", "G": "SOL", "G#": "LAb", "A": "LA",
    "A#": "SIb", "B": "SI",
  };

  static bool _isItalianRoot(String root) {
    final r = root.toUpperCase();
    return r.startsWith("DO") || r.startsWith("RE") || r.startsWith("MI") ||
           r.startsWith("FA") || r.startsWith("SOL") || r.startsWith("LA") || r.startsWith("SI");
  }

  static bool _isLikelyText(String chord) {
    String clean = chord.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    const textOnly = {"mi", "la", "si", "re", "fa", "do", "sol", "ma", "di", "per", "chi", "con"};

    if (textOnly.contains(clean)) {
      return !chord.contains(RegExp(r'[0-9#bmM+°\(\)/]'));
    }
    return false;
  }

  static bool _shouldPreferFlats(String text) {
    int flatCount = RegExp(r'[A-G]b|SIb|LAb|SOLb|MIb|REb').allMatches(text).length;
    int sharpCount = '#'.allMatches(text).length;
    return flatCount > sharpCount;
  }

  static String transposeChord(String chord, int semitones, bool preferFlats) {
    if (chord.isEmpty) return chord;

    if (chord.contains("/")) {
      return chord.split("/")
          .map((part) => transposeChord(part.trim(), semitones, preferFlats))
          .join("/");
    }

    final match = RegExp(
      r'^(DO|RE|MI|FA|SOL|LA|SI|[A-G])([#b]*)',
      caseSensitive: false,
    ).firstMatch(chord);

    if (match == null) return chord;

    String rawRoot = match.group(1)!.toUpperCase();
    String rawAlter = (match.group(2) ?? "");

    String rootFound = rawRoot + rawAlter;
    String suffix = chord.substring(match.end);

    String? enRoot = itToEn[rootFound];

    if (enRoot == null) {
      String upperRoot = rootFound.toUpperCase();
      if (upperRoot == "DB") enRoot = "C#";
      else if (upperRoot == "EB") enRoot = "D#";
      else if (upperRoot == "GB") enRoot = "F#";
      else if (upperRoot == "AB") enRoot = "G#";
      else if (upperRoot == "BB") enRoot = "A#";
      else if (chromatic.contains(upperRoot)) enRoot = upperRoot;
    }

    if (enRoot == null) return chord;

    final idx = chromatic.indexOf(enRoot);
    if (idx == -1) return chord;

    final newIdx = (idx + semitones) % 12;
    final normalizedNewIdx = newIdx < 0 ? newIdx + 12 : newIdx;
    final newEn = chromatic[normalizedNewIdx];

    final isIt = _isItalianRoot(match.group(1)!);

    String newRoot;
    if (isIt) {
      if (preferFlats) {
        newRoot = enToItFlat[newEn] ?? enToItSharp[newEn] ?? newEn;
      } else {
        newRoot = enToItSharp[newEn] ?? newEn;
      }
    } else {
      if (preferFlats) {
        if (newEn == "C#") newRoot = "Db";
        else if (newEn == "D#") newRoot = "Eb";
        else if (newEn == "F#") newRoot = "Gb";
        else if (newEn == "G#") newRoot = "Ab";
        else if (newEn == "A#") newRoot = "Bb";
        else newRoot = newEn;
      } else {
        newRoot = newEn;
      }
    }

    return newRoot + suffix;
  }

  // 🔥 VERSIONE BLINDATA: trasponi SOLO righe marcate con [AC]
  static String transposeText(String originalText, int totalSemitones) {
    if (originalText.isEmpty) return originalText;
    if (totalSemitones == 0) return originalText;

    final bool globalPreferFlats = _shouldPreferFlats(originalText);

    final lines = originalText.split('\n');
    List<String> processedLines = [];

    for (var line in lines) {
      final trimmed = line.trim();

      // ❌ NON È UNA RIGA ACCORDI → NON TOCCARE
      if (!trimmed.startsWith("[AC]")) {
        processedLines.add(line);
        continue;
      }

      // 🔎 Estrai contenuto dopo [AC]
      final int tagIndex = line.indexOf("[AC]");
      final String prefix = line.substring(0, tagIndex + 4);
      String content = line.substring(tagIndex + 4);

      if (content.trim().isEmpty) {
        processedLines.add(line);
        continue;
      }

      String newContent = "";
      int lastOriginalPos = 0;

      final matches = ChordUtils.chordRegex.allMatches(content).toList();

      for (var m in matches) {
        newContent += content.substring(lastOriginalPos, m.start);
        String originalChord = m.group(0)!;

        if (_isLikelyText(originalChord)) {
          newContent += originalChord;
        } else {
          String transposed =
              transposeChord(originalChord, totalSemitones, globalPreferFlats);
          newContent += transposed;

          int lengthDiff = originalChord.length - transposed.length;
          if (lengthDiff > 0) {
            newContent += " " * lengthDiff;
          }
        }
        lastOriginalPos = m.end;
      }

      if (lastOriginalPos < content.length) {
        newContent += content.substring(lastOriginalPos);
      }

      processedLines.add(prefix + newContent);
    }

    return processedLines.join('\n');
  }
}
