class Place {
  final int? id;
  final double latitude;
  final double longitude;
  final String country;
  final String address;
  final String name;

  Place({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.country,
    required this.address,
    required this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'country': country,
      'address': address,
      'name': name,
    };
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as int?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      country: json['country'] as String,
      address: json['address'] as String,
      name: json['name'] as String,
    );
  }
}

