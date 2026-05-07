import 'package:cloud_firestore/cloud_firestore.dart';

class Ride {
  final String id;
  final String driverUid;
  final String driverName;
  final String vehicleEmoji;
  final String vehicleLabel;
  final String departureLocation;
  final int totalSeats;
  final int departureTime;
  final int returnTime;
  final String notes;
  final List<String> passengerUids;
  final List<String> passengerNames;

  const Ride({
    required this.id,
    required this.driverUid,
    required this.driverName,
    this.vehicleEmoji = '🚗',
    this.vehicleLabel = '',
    this.departureLocation = '',
    this.totalSeats = 4,
    this.departureTime = 0,
    this.returnTime = 0,
    this.notes = '',
    this.passengerUids = const [],
    this.passengerNames = const [],
  });

  int get availableSeats => totalSeats - passengerUids.length;
  bool get isFull => availableSeats <= 0;

  factory Ride.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Ride(
      id: doc.id,
      driverUid: d['driverUid'] as String? ?? '',
      driverName: d['driverName'] as String? ?? '',
      vehicleEmoji: d['vehicleEmoji'] as String? ?? '🚗',
      vehicleLabel: d['vehicleLabel'] as String? ?? '',
      departureLocation: d['departureLocation'] as String? ?? '',
      totalSeats: (d['totalSeats'] as num?)?.toInt() ?? 4,
      departureTime: (d['departureTime'] as num?)?.toInt() ?? 0,
      returnTime: (d['returnTime'] as num?)?.toInt() ?? 0,
      notes: d['notes'] as String? ?? '',
      passengerUids: List<String>.from(d['passengerUids'] as List? ?? []),
      passengerNames: List<String>.from(d['passengerNames'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'driverUid': driverUid,
        'driverName': driverName,
        'vehicleEmoji': vehicleEmoji,
        'vehicleLabel': vehicleLabel,
        'departureLocation': departureLocation,
        'totalSeats': totalSeats,
        'departureTime': departureTime,
        'returnTime': returnTime,
        'notes': notes,
        'passengerUids': passengerUids,
        'passengerNames': passengerNames,
      };
}
