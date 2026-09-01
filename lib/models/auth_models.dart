/// Mirrors the backend's TokenResponse.
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int? expiresIn;
  final int? expiresAt;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    this.expiresIn,
    this.expiresAt,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenType: (json['token_type'] as String?) ?? 'bearer',
        expiresIn: json['expires_in'] as int?,
        expiresAt: json['expires_at'] as int?,
      );
}

/// Mirrors the backend's AuthUser (the Supabase Auth account).
class AuthUser {
  final String id;
  final String? email;
  final DateTime? createdAt;

  const AuthUser({required this.id, this.email, this.createdAt});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        email: json['email'] as String?,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'].toString()),
      );
}

/// Mirrors the backend's UserProfileRead.
class UserProfile {
  final int profileId;
  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? gender;
  final String role;

  const UserProfile({
    required this.profileId,
    required this.userId,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        profileId: json['profile_id'] as int,
        userId: json['user_id'].toString(),
        name: json['name'] as String,
        role: (json['role'] as String?) ?? 'user',
        avatarUrl: json['avatar_url'] as String?,
        dateOfBirth: json['date_of_birth'] == null
            ? null
            : DateTime.tryParse(json['date_of_birth'].toString()),
        gender: json['gender'] as String?,
      );
}

/// Mirrors the backend's MeResponse (GET /auth/me).
class CurrentUser {
  final AuthUser user;
  final UserProfile? profile;
  final String role;

  const CurrentUser({required this.user, required this.role, this.profile});

  bool get isAdmin => role == 'admin';

  String get displayName => profile?.name ?? user.email ?? 'Bodify user';

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        profile: json['profile'] == null
            ? null
            : UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
        role: (json['role'] as String?) ?? 'user',
      );
}

/// Mirrors the backend's RegisterResponse.
class RegisterResult {
  final AuthUser user;
  final UserProfile profile;

  /// Null when the Supabase project requires email confirmation - the account
  /// exists but cannot be used until the user confirms.
  final AuthSession? session;

  const RegisterResult({
    required this.user,
    required this.profile,
    this.session,
  });

  bool get needsEmailConfirmation => session == null;

  factory RegisterResult.fromJson(Map<String, dynamic> json) => RegisterResult(
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
        session: json['session'] == null
            ? null
            : AuthSession.fromJson(json['session'] as Map<String, dynamic>),
      );
}
