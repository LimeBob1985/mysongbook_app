import 'package:flutter/material.dart';

class ChordUtils {
  static const Map<String, String> itaToInt = {
    "DO": "C", "RE": "D", "MI": "E", "FA": "F", "SOL": "G", "LA": "A", "SI": "B",
  };

  static const Map<String, String> intToIta = {
    "C": "DO", "D": "RE", "E": "MI", "F": "FA", "G": "SOL", "A": "LA", "B": "SI",
  };

  static const List<String> scaleSharp = [
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
  ];
  static const List<String> scaleFlat = [
    "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"
  ];

  static final RegExp chordRegex = RegExp(
    r'(?:DO|RE|MI|FA|SOL|LA|SI|[A-G])' 
    r'(?:#|b|bb|##)?'                  
    r'(?:[^\s]*)',                     
    caseSensitive: false,
  );

  static String normalizeChord(String chord) {
    if (chord.isEmpty) return chord;
    if (chord.contains("/")) {
      return chord.split("/").map((e) => normalizeChord(e.trim())).join("/");
    }

    final match = RegExp(r'^(DO|RE|MI|FA|SOL|LA|SI|[A-G])', caseSensitive: false)
        .firstMatch(chord);
    if (match == null) return chord.toUpperCase();

    final root = match.group(1)!.toUpperCase();
    final suffix = chord.substring(match.end);
    return root + suffix;
  }

  static bool isPureChordLine(String line) {
    if (line.startsWith("[AC]")) return true;

    String trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    List<String> words = trimmed.split(RegExp(r'\s+'));
    int chordWords = 0;
    bool containsLongLowercase = false;

    for (var word in words) {
      if (word.length >= 3 && RegExp(r'^[a-zàèìòù]+$').hasMatch(word)) {
        containsLongLowercase = true;
      }
      if (chordRegex.stringMatch(word) == word) {
        chordWords++;
      }
    }

    if (containsLongLowercase) return false;
    if (chordWords / words.length < 0.5) return false;

    final matches = chordRegex.allMatches(line);
    if (matches.isEmpty) return false;

    int chordCharsCount = 0;
    for (var m in matches) {
      chordCharsCount += m.group(0)!.length;
    }

    if (line.contains('/') && matches.isNotEmpty) return true;
    return chordCharsCount >= trimmed.length * 0.30;
  }

  static Map<String, String> splitLine(String line) {
    if (!isPureChordLine(line)) {
      return {"accordi": "", "testo": line};
    }

    String cleanLine = line.startsWith("[AC]") ? line.substring(4) : line;
    List<String> chordLineArr = List.filled(cleanLine.length, ' ');
    final matches = chordRegex.allMatches(cleanLine).toList();

    for (var m in matches) {
      String norm = normalizeChord(m.group(0)!);
      for (int i = 0; i < norm.length; i++) {
        if (m.start + i < chordLineArr.length) {
          chordLineArr[m.start + i] = norm[i];
        } else {
          chordLineArr.add(norm[i]);
        }
      }
    }
    return {"accordi": chordLineArr.join(), "testo": ""};
  }

  static bool preferFlats(String testo) {
    int bCount = RegExp(r'[A-G]b|SIb|LAb|SOLb|MIb|REb').allMatches(testo).length;
    int sharpCount = '#'.allMatches(testo).length;
    return bCount > sharpCount;
  }

  static String transposeSong(String originalTesto, int totalSemitoni, {bool? forcedPreferFlats}) {
    if (totalSemitoni == 0) return originalTesto;
    
    final lines = originalTesto.split('\n');
    final bool useFlats = forcedPreferFlats ?? preferFlats(originalTesto);

    return lines.map((line) {
      if (isPureChordLine(line)) {
        bool hasMarker = line.startsWith("[AC]");
        String content = hasMarker ? line.substring(4) : line;
        
        String transposedContent = content.replaceAllMapped(chordRegex, (m) {
          return transposeChord(m.group(0)!, totalSemitoni, !useFlats);
        });
        
        return hasMarker ? "[AC]$transposedContent" : transposedContent;
      }
      return line;
    }).join('\n');
  }

  static String transposeChord(String chord, int semitoni, bool useSharps) {
    if (chord.contains("/")) {
      return chord.split("/").map((p) => transposeChord(p.trim(), semitoni, useSharps)).join("/");
    }

    final rootMatch = RegExp(r'^(DO|RE|MI|FA|SOL|LA|SI|[A-G])([#b]*)', caseSensitive: false).firstMatch(chord);
    if (rootMatch == null) return chord;

    String root = rootMatch.group(1)!.toUpperCase();
    String alter = (rootMatch.group(2) ?? "");
    String suffix = chord.substring(rootMatch.end);

    String rootInt = itaToInt[root] ?? root;
    String base = rootInt + alter;

    if (base == "Fb") base = "E";
    else if (base == "Cb") base = "B";
    else if (base == "E#") base = "F";
    else if (base == "B#") base = "C";

    int index = scaleSharp.indexOf(base);
    if (index == -1) index = scaleFlat.indexOf(base);
    if (index == -1) return chord;

    int newIndex = (index + semitoni) % 12;
    if (newIndex < 0) newIndex += 12;

    String newRootInt = useSharps ? scaleSharp[newIndex] : scaleFlat[newIndex];
    
    bool isItalian = itaToInt.containsKey(root);
    if (isItalian) {
      String cleanRootInt = newRootInt.replaceAll("#", "").replaceAll("b", "");
      String newAlter = newRootInt.substring(cleanRootInt.length);
      String newRoot = intToIta[cleanRootInt] ?? cleanRootInt;
      return newRoot + newAlter + suffix;
    }

    return newRootInt + suffix;
  }
}