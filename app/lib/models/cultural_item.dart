class CulturalItem {
  final int id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String? period;
  final String type;

  CulturalItem({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.period,
  });

  factory CulturalItem.fromJson(Map<String, dynamic> json) {
    return CulturalItem(
      id: json['item_id'],
      title: json['title'],
      description: json['description'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: json['item_type'],
      period: json['period'],
    );
  }
}
