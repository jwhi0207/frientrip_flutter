import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final int avatarSeed;
  final int avatarColor;
  final String role;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarSeed = 0,
    this.avatarColor = 0,
    this.role = 'user',
  });

  bool get isAdmin => role == 'admin';

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      avatarSeed: (d['avatarSeed'] as num?)?.toInt() ?? 0,
      avatarColor: (d['avatarColor'] as num?)?.toInt() ?? 0,
      role: d['role'] as String? ?? 'user',
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'avatarSeed': avatarSeed,
    'avatarColor': avatarColor,
    'role': role,
  };
}
