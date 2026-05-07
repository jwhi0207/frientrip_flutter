import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_history_event.dart';

class HistoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<TripHistoryEvent>> getHistoryStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TripHistoryEvent.fromFirestore).toList());
  }
}
