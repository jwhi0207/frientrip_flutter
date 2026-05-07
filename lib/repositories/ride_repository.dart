import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';

class RideRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Ride>> getRidesStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('rides')
        .snapshots()
        .map((snap) => snap.docs.map(Ride.fromFirestore).toList());
  }

  Stream<List<RideRequest>> getRideRequestsStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('rideRequests')
        .snapshots()
        .map((snap) => snap.docs.map(RideRequest.fromFirestore).toList());
  }

  Future<void> addRide(String tripId, Ride ride) async {
    await _db.collection('trips').doc(tripId).collection('rides').add(ride.toMap());
  }

  Future<void> updateRide(String tripId, Ride ride) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rides')
        .doc(ride.id)
        .update(ride.toMap());
  }

  Future<void> deleteRide(String tripId, String rideId) async {
    await _db.collection('trips').doc(tripId).collection('rides').doc(rideId).delete();
  }

  Future<void> addPassenger(
      String tripId, String rideId, String uid, String name) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rides')
        .doc(rideId)
        .update({
      'passengerUids': FieldValue.arrayUnion([uid]),
      'passengerNames': FieldValue.arrayUnion([name]),
    });
    await removeRideRequest(tripId, uid);
  }

  Future<void> removePassenger(
      String tripId, String rideId, String uid, String name) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rides')
        .doc(rideId)
        .update({
      'passengerUids': FieldValue.arrayRemove([uid]),
      'passengerNames': FieldValue.arrayRemove([name]),
    });
  }

  Future<void> addRideRequest(
      String tripId, String uid, String displayName) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rideRequests')
        .doc(uid)
        .set({'uid': uid, 'displayName': displayName, 'notes': ''});
  }

  Future<void> removeRideRequest(String tripId, String uid) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rideRequests')
        .doc(uid)
        .delete();
  }
}
