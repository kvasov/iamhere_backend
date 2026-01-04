class Photo {
  final int? id;
  final String path;

  Photo({
    this.id,
    required this.path,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
    };
  }

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as int?,
      path: json['path'] as String,
    );
  }
}

