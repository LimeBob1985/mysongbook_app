class Spartito {
  String id;
  String titolo;
  String artista;
  String testo;
  Map<int, List<Accordo>> accordiPerRiga;

  Spartito({
    required this.id,
    required this.titolo,
    required this.artista,
    required this.testo,
    required this.accordiPerRiga,
  });

  // Conversione per salvataggio (JSON)
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "titolo": titolo,
      "artista": artista,
      "testo": testo,
      "accordiPerRiga": accordiPerRiga.map(
        (k, v) => MapEntry(
          k.toString(),
          v.map((a) => a.toJson()).toList(),
        ),
      ),
    };
  }

  // Conversione da JSON
  factory Spartito.fromJson(Map<String, dynamic> json) {
    return Spartito(
      id: json["id"],
      titolo: json["titolo"],
      artista: json["artista"],
      testo: json["testo"],
      accordiPerRiga: (json["accordiPerRiga"] as Map<String, dynamic>).map(
        (k, v) => MapEntry(
          int.parse(k),
          (v as List).map((a) => Accordo.fromJson(a)).toList(),
        ),
      ),
    );
  }
}

class Accordo {
  String valore;
  int posizione;

  Accordo({
    required this.valore,
    required this.posizione,
  });

  Map<String, dynamic> toJson() {
    return {
      "valore": valore,
      "posizione": posizione,
    };
  }

  factory Accordo.fromJson(Map<String, dynamic> json) {
    return Accordo(
      valore: json["valore"],
      posizione: json["posizione"],
    );
  }
}
