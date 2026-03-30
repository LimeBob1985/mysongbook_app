class Song {
  final String id;
  final String title;
  final String artist;
  final List<String> lines;
  final List<String> lineTypes; // New: Memorizza se la riga è "A" (Accordi) o "T" (Testo)
  final int transpose;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.lines,
    required this.lineTypes, // New: Obbligatorio per il nuovo sistema
    required this.transpose,
  });
}