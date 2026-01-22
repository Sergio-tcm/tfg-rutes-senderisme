class CulturalItem {
  final int id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String type;
  final String? period;
  final String? sourceUrl;
  final double? distanceM;

  CulturalItem({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.period,
    this.sourceUrl,
    this.distanceM,
  });

  factory CulturalItem.fromJson(Map<String, dynamic> json) {
    return CulturalItem(
      id: json['item_id'],
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: (json['item_type'] ?? 'other').toString(),
      period: json['period']?.toString(),
      sourceUrl: json['source_url']?.toString(),
      distanceM: (json['distance_m'] is num) ? (json['distance_m'] as num).toDouble() : null,
    );
  }
}
