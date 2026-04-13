class LiveList {
  final String id;
  final String name;
  final List<String> songIds;

  LiveList({
    required this.id,
    required this.name,
    required this.songIds,
  });

  LiveList copyWith({
    String? id,
    String? name,
    List<String>? songIds,
  }) {
    return LiveList(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songIds': songIds,
    };
  }

  factory LiveList.fromJson(Map<String, dynamic> json) {
    return LiveList(
      id: json['id'],
      name: json['name'],
      songIds: List<String>.from(json['songIds']),
    );
  }
}
