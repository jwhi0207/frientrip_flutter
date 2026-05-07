import 'package:cloud_firestore/cloud_firestore.dart';

class RideRequest {
  final String uid;
  final String displayName;
  final String notes;

  const RideRequest({
    required this.uid,
    required this.displayName,
    this.notes = '',
  });

  factory RideRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RideRequest(
      uid: d['uid'] as String? ?? doc.id,
      displayName: d['displayName'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'notes': notes,
      };
}
