/// Mirrors the backend's ProfileRead (GET/PUT /profile).
class Profile {
  final String userId;
  final int profileId;

  final String name;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? gender;

  final String role;
  final String? email;

  /// Copied from the most recent body metric by the backend, so the profile
  /// screen does not need a second request.
  final double? heightCm;
  final double? weightKg;

  /// Bumped by the database on every write, which is what makes it usable as
  /// a cache-busting key for the avatar: the signed URL is re-signed on every
  /// read and so cannot serve that purpose itself.
  final DateTime updatedAt;

  const Profile({
    required this.userId,
    required this.profileId,
    required this.name,
    required this.role,
    required this.updatedAt,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    this.email,
    this.heightCm,
    this.weightKg,
  });

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    // Numeric columns arrive as JSON strings ("175.00").
    return value is num ? value.toDouble() : double.tryParse(value.toString());
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        userId: json['user_id'].toString(),
        profileId: json['profile_id'] as int,
        name: json['name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        dateOfBirth: json['date_of_birth'] == null
            ? null
            : DateTime.tryParse(json['date_of_birth'].toString()),
        gender: json['gender'] as String?,
        role: (json['role'] as String?) ?? 'user',
        email: json['email'] as String?,
        heightCm: _toDouble(json['height_cm']),
        weightKg: _toDouble(json['weight_kg']),
        updatedAt: DateTime.tryParse('${json['updated_at']}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Age in whole years, or null when no birth date is recorded.
  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    // Birthday not reached yet this year.
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years -= 1;
    }
    return years < 0 ? null : years;
  }
}
