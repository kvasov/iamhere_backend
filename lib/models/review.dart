class Review {
  final int? id;
  final int userId;
  final int placeId;
  final String text;
  final int rating; // от 1 до 5

  Review({
    this.id,
    required this.userId,
    required this.placeId,
    required this.text,
    required this.rating,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'placeId': placeId,
      'text': text,
      'rating': rating,
    };
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int?,
      userId: json['user_id'] as int? ?? json['userId'] as int,
      placeId: json['place_id'] as int? ?? json['placeId'] as int,
      text: json['text'] as String,
      rating: json['rating'] as int,
    );
  }
}

