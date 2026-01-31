class RatingItem {
  final int ratingId;
  final int userId;
  final int routeId;
  final int score;
  final String comment;
  final DateTime? createdAt;
  final String? userName;

  const RatingItem({
    required this.ratingId,
    required this.userId,
    required this.routeId,
    required this.score,
    required this.comment,
    required this.createdAt,
    this.userName,
  });

  factory RatingItem.fromJson(Map<String, dynamic> json) {
    return RatingItem(
      ratingId: (json['rating_id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      routeId: (json['route_id'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      comment: (json['comment'] ?? '').toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'].toString()),
      userName: json['user_name']?.toString(),
    );
  }
}
