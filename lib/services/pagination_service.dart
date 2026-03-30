import 'package:flutter/material.dart';
// L'import ora punta correttamente alla cartella utils
import '../utils/chord_utils.dart'; 

enum LineType { chord, text, empty }

class PageData {
  final List<String> lines;
  PageData(this.lines);
}

class PaginationService {
  static LineType getLineType(String line) {
    if (line.trim().isEmpty) return LineType.empty;
    return ChordUtils.isPureChordLine(line) ? LineType.chord : LineType.text;
  }

  static List<PageData> paginate({
    required List<String> lines,
    required double maxHeight,
    required TextStyle textStyle,
  }) {
    final pages = <PageData>[];
    List<String> currentPage = [];
    double currentHeight = 0;

    double measure(String text) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);
      return tp.height + 6;
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final h = measure(line);

      if (currentHeight + h > maxHeight && currentPage.isNotEmpty) {
        if (getLineType(currentPage.last) == LineType.chord && getLineType(line) == LineType.text) {
          String last = currentPage.removeLast();
          pages.add(PageData(List.from(currentPage)));
          currentPage = [last, line];
          currentHeight = measure(last) + h;
        } else {
          pages.add(PageData(List.from(currentPage)));
          currentPage = [line];
          currentHeight = h;
        }
        continue;
      }
      currentPage.add(line);
      currentHeight += h;
    }
    if (currentPage.isNotEmpty) pages.add(PageData(List.from(currentPage)));
    return pages;
  }
}