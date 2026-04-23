import 'package:cloud_firestore/cloud_firestore.dart';

class TripMember {
  final String uid;
  final String displayName;
  final String email;
  final int avatarSeed;
  final int avatarColor;
  final int nightsStayed;
  final double amountPaid;
  final double pendingPaymentAmount;
  final String pendingPaymentStatus;
  final String status;

  const TripMember({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarSeed = 0,
    this.avatarColor = 0,
    this.nightsStayed = 0,
    this.amountPaid = 0.0,
    this.pendingPaymentAmount = 0.0,
    this.pendingPaymentStatus = 'none',
    this.status = 'active',
  });

  bool get isDeactivated => status == 'deactivated';

  factory TripMember.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TripMember(
      uid: d['uid'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      avatarSeed: (d['avatarSeed'] as num?)?.toInt() ?? 0,
      avatarColor: (d['avatarColor'] as num?)?.toInt() ?? 0,
      nightsStayed: (d['nightsStayed'] as num?)?.toInt() ?? 0,
      amountPaid: (d['amountPaid'] as num?)?.toDouble() ?? 0.0,
      pendingPaymentAmount: (d['pendingPaymentAmount'] as num?)?.toDouble() ?? 0.0,
      pendingPaymentStatus: d['pendingPaymentStatus'] as String? ?? 'none',
      status: d['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'avatarSeed': avatarSeed,
    'avatarColor': avatarColor,
    'nightsStayed': nightsStayed,
    'amountPaid': amountPaid,
    'pendingPaymentAmount': pendingPaymentAmount,
    'pendingPaymentStatus': pendingPaymentStatus,
    'status': status,
  };

  TripMember copyWith({
    String? displayName,
    int? avatarSeed,
    int? avatarColor,
    int? nightsStayed,
    double? amountPaid,
    double? pendingPaymentAmount,
    String? pendingPaymentStatus,
    String? status,
  }) => TripMember(
    uid: uid,
    displayName: displayName ?? this.displayName,
    email: email,
    avatarSeed: avatarSeed ?? this.avatarSeed,
    avatarColor: avatarColor ?? this.avatarColor,
    nightsStayed: nightsStayed ?? this.nightsStayed,
    amountPaid: amountPaid ?? this.amountPaid,
    pendingPaymentAmount: pendingPaymentAmount ?? this.pendingPaymentAmount,
    pendingPaymentStatus: pendingPaymentStatus ?? this.pendingPaymentStatus,
    status: status ?? this.status,
  );
}
