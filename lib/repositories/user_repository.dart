import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

const _adminEmails = ['jwhi0207@gmail.com', 'benjamincroberts@gmail.com'];

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _roleForEmail(String email) =>
      _adminEmails.contains(email.toLowerCase()) ? 'admin' : 'user';

  Future<void> createUserProfile(
    String uid,
    String displayName,
    String email, {
    int avatarSeed = 1,
    int avatarColor = 0,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'avatarSeed': avatarSeed,
      'avatarColor': avatarColor,
      'role': _roleForEmail(email),
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  Stream<UserProfile?> getUserProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  Future<void> ensureRoleSet(String uid, String email) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    if (data['role'] == null) {
      await _db.collection('users').doc(uid).update({'role': _roleForEmail(email)});
    }
  }

  Future<void> updateProfile(
      String uid, String displayName, int avatarSeed, int avatarColor) async {
    await _db.collection('users').doc(uid).update({
      'displayName': displayName,
      'avatarSeed': avatarSeed,
      'avatarColor': avatarColor,
    });

    final tripsSnap = await _db
        .collection('trips')
        .where('memberIds', arrayContains: uid)
        .get();
    if (tripsSnap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final tripDoc in tripsSnap.docs) {
      batch.update(
        _db.collection('trips').doc(tripDoc.id).collection('members').doc(uid),
        {
          'displayName': displayName,
          'avatarSeed': avatarSeed,
          'avatarColor': avatarColor,
        },
      );
    }
    await batch.commit();
  }

  Future<void> addFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> removeFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  Future<void> checkAndAcceptPendingInvites(String uid, String email) async {
    final profile = await getUserProfile(uid);
    if (profile == null) return;

    final lowerEmail = email.toLowerCase();
    final tripsSnap = await _db
        .collection('trips')
        .where('pendingInviteEmails', arrayContains: lowerEmail)
        .get();
    if (tripsSnap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final tripDoc in tripsSnap.docs) {
      final tripRef = tripDoc.reference;
      batch.update(tripRef, {
        'memberIds': FieldValue.arrayUnion([uid]),
        'pendingInviteEmails': FieldValue.arrayRemove([lowerEmail]),
      });
      batch.set(tripRef.collection('members').doc(uid), {
        'uid': uid,
        'displayName': profile.displayName,
        'email': email,
        'avatarSeed': profile.avatarSeed,
        'avatarColor': profile.avatarColor,
        'nightsStayed': 0,
        'amountPaid': 0.0,
        'pendingPaymentAmount': 0.0,
        'pendingPaymentStatus': 'none',
        'status': 'active',
        'isGuest': false,
      });
    }
    await batch.commit();
  }
}
