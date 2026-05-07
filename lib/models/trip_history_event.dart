import 'package:cloud_firestore/cloud_firestore.dart';

class TripHistoryEvent {
  final String id;
  final String category;
  final String description;
  final DateTime timestamp;

  const TripHistoryEvent({
    required this.id,
    required this.category,
    required this.description,
    required this.timestamp,
  });

  factory TripHistoryEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['timestamp'];
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    return TripHistoryEvent(
      id: doc.id,
      category: d['category'] as String? ?? '',
      description: d['description'] as String? ?? '',
      timestamp: dt,
    );
  }
}
