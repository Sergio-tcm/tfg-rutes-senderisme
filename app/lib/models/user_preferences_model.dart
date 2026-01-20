class UserPreferencesModel {
  final int prefId;
  final int userId;
  final String? fitnessLevel; // bajo/medio/alto
  final double? preferredDistance;
  final String? environmentType;
  final String? culturalInterest;
  final DateTime? updatedAt;

  const UserPreferencesModel({
    required this.prefId,
    required this.userId,
    this.fitnessLevel,
    this.preferredDistance,
    this.environmentType,
    this.culturalInterest,
    this.updatedAt,
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.parse(v.toString());
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.parse(v.toString());
  }

  factory UserPreferencesModel.fromJson(Map<String, dynamic> json) {
    return UserPreferencesModel(
      prefId: _toInt(json['pref_id']),
      userId: _toInt(json['user_id']),
      fitnessLevel: json['fitness_level']?.toString(),
      preferredDistance: json['preferred_distance'] == null
          ? null
          : _toDouble(json['preferred_distance']),
      environmentType: json['environment_type']?.toString(),
      culturalInterest: json['cultural_interest']?.toString(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'].toString()),
    );
  }
}
