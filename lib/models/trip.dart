import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String name;
  final String ownerId;
  final String houseURL;
  final String? thumbnailURL;
  final String address;
  final int totalNights;
  final double totalCost;
  final int checkInMillis;
  final int checkOutMillis;
  final List<String> memberIds;
  final List<String> deactivatedMemberIds;
  final List<String> pendingInviteEmails;
  final String? inviteCode;
  final bool inviteCodeEnabled;
  final String description;
  final String emoji;
  final bool nightsLocked;

  const Trip({
    required this.id,
    required this.name,
    required this.ownerId,
    this.houseURL = '',
    this.thumbnailURL,
    this.address = '',
    this.totalNights = 0,
    this.totalCost = 0.0,
    this.checkInMillis = 0,
    this.checkOutMillis = 0,
    this.memberIds = const [],
    this.deactivatedMemberIds = const [],
    this.pendingInviteEmails = const [],
    this.inviteCode,
    this.inviteCodeEnabled = true,
    this.description = '',
    this.emoji = '',
    this.nightsLocked = false,
  });

  factory Trip.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Trip(
      id: doc.id,
      name: d['name'] as String? ?? '',
      ownerId: d['ownerId'] as String? ?? '',
      houseURL: d['houseURL'] as String? ?? '',
      thumbnailURL: d['thumbnailURL'] as String?,
      address: d['address'] as String? ?? '',
      totalNights: (d['totalNights'] as num?)?.toInt() ?? 0,
      totalCost: (d['totalCost'] as num?)?.toDouble() ?? 0.0,
      checkInMillis: (d['checkInMillis'] as num?)?.toInt() ?? 0,
      checkOutMillis: (d['checkOutMillis'] as num?)?.toInt() ?? 0,
      memberIds: List<String>.from(d['memberIds'] as List? ?? []),
      deactivatedMemberIds: List<String>.from(d['deactivatedMemberIds'] as List? ?? []),
      pendingInviteEmails: List<String>.from(d['pendingInviteEmails'] as List? ?? []),
      inviteCode: d['inviteCode'] as String?,
      inviteCodeEnabled: d['inviteCodeEnabled'] as bool? ?? true,
      description: d['description'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '',
      nightsLocked: d['nightsLocked'] as bool? ?? false,
    );
  }
}
