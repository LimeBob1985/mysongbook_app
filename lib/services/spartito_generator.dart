class SpartitoGenerator {
  static List<String> generaPagine(String testo) {
    final righe = testo.split("\n");
    const maxRighe = 40;

    List<String> pagine = [];
    List<String> buffer = [];

    for (final riga in righe) {
      buffer.add(riga);
      if (buffer.length >= maxRighe) {
        pagine.add(buffer.join("\n"));
        buffer = [];
      }
    }

    if (buffer.isNotEmpty) {
      pagine.add(buffer.join("\n"));
    }

    return pagine;
  }
}
