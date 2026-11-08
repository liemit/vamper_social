class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role; // Added role
  final String? phone;
  final String? gender;
  final String? dateOfBirth;
  final String? bio;
  final String? profilePhoto;
  final String? location;
  final String? latitude;
  final String? longitude;
  final bool isVerified;
  final int coins;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;
  final int? activeProfileFrameId;
  final int? activePartyFrameId;
  final String? activeProfileFrameCode;
  final String? activePartyFrameCode;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.role = 'user',
    this.phone,
    this.gender,
    this.dateOfBirth,
    this.bio,
    this.profilePhoto,
    this.location,
    this.latitude,
    this.longitude,
    required this.isVerified,
    this.coins = 0,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.activeProfileFrameId,
    this.activePartyFrameId,
    this.activeProfileFrameCode,
    this.activePartyFrameCode,
  });

  int? get age {
    if (dateOfBirth == null) return null;
    try {
      final dob = DateTime.parse(dateOfBirth!);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? phone,
    String? gender,
    String? dateOfBirth,
    String? bio,
    String? profilePhoto,
    String? location,
    String? latitude,
    String? longitude,
    bool? isVerified,
    int? coins,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    int? activeProfileFrameId,
    int? activePartyFrameId,
    String? activeProfileFrameCode,
    String? activePartyFrameCode,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bio: bio ?? this.bio,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isVerified: isVerified ?? this.isVerified,
      coins: coins ?? this.coins,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeProfileFrameId: activeProfileFrameId ?? this.activeProfileFrameId,
      activePartyFrameId: activePartyFrameId ?? this.activePartyFrameId,
      activeProfileFrameCode:
          activeProfileFrameCode ?? this.activeProfileFrameCode,
      activePartyFrameCode: activePartyFrameCode ?? this.activePartyFrameCode,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      phone: json['phone'],
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'],
      bio: json['bio'],
      profilePhoto: json['profile_photo'],
      location: json['location'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      isVerified:
          json['is_verified'] == '1' ||
          json['is_verified'] == 1 ||
          json['is_verified'] == true,
      coins: int.tryParse(json['coins'].toString()) ?? 0,
      isActive:
          json['is_active'] == '1' ||
          json['is_active'] == 1 ||
          json['is_active'] == true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
      activeProfileFrameId: json['active_profile_frame_id'] != null
          ? int.tryParse(json['active_profile_frame_id'].toString())
          : null,
      activePartyFrameId: json['active_party_frame_id'] != null
          ? int.tryParse(json['active_party_frame_id'].toString())
          : null,
      activeProfileFrameCode: json['active_profile_frame_code']?.toString(),
      activePartyFrameCode: json['active_party_frame_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'phone': phone,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'bio': bio,
      'profile_photo': profilePhoto,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'is_verified': isVerified,
      'coins': coins,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'active_profile_frame_id': activeProfileFrameId,
      'active_party_frame_id': activePartyFrameId,
      'active_profile_frame_code': activeProfileFrameCode,
      'active_party_frame_code': activePartyFrameCode,
    };
  }
}
