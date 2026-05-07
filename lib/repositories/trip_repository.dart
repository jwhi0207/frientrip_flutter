import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../models/trip_member.dart';
import '../models/supply_item.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../models/shared_expense.dart';
import '../models/trip_history_event.dart';
import '../utils/invite_code.dart' as ic;

class TripRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Trip>> getUserTripsStream(String uid) {
    return _db
        .collection('trips')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs.map(Trip.fromFirestore).toList());
  }

  Stream<Trip?> getTripStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .snapshots()
        .map((doc) => doc.exists ? Trip.fromFirestore(doc) : null);
  }

  Stream<List<TripMember>> getTripMembersStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('members')
        .snapshots()
        .map((snap) => snap.docs.map(TripMember.fromFirestore).toList());
  }

  Stream<List<SupplyItem>> getSuppliesStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .snapshots()
        .map((snap) => snap.docs.map(SupplyItem.fromFirestore).toList());
  }

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

  Stream<List<SharedExpense>> getExpensesStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .snapshots()
        .map((snap) => snap.docs.map(SharedExpense.fromFirestore).toList());
  }

  Future<String> createTrip({
    required String name,
    required String ownerId,
    required String displayName,
    required String email,
    required int avatarSeed,
    required int avatarColor,
    String emoji = '',
    String description = '',
    List<String> pendingEmails = const [],
    int checkInMillis = 0,
    int checkOutMillis = 0,
    String address = '',
    String houseURL = '',
    double totalCost = 0.0,
  }) async {
    final inviteCode = ic.generateInviteCode();
    final tripRef = _db.collection('trips').doc();
    final batch = _db.batch();

    batch.set(tripRef, {
      'name': name,
      'ownerId': ownerId,
      'memberIds': [ownerId],
      'deactivatedMemberIds': [],
      'pendingInviteEmails': pendingEmails.map((e) => e.toLowerCase()).toList(),
      'inviteCode': inviteCode,
      'inviteCodeEnabled': true,
      'emoji': emoji,
      'description': description,
      'checkInMillis': checkInMillis,
      'checkOutMillis': checkOutMillis,
      'address': address,
      'houseURL': houseURL,
      'totalCost': totalCost,
      'totalNights': 0,
      'thumbnailURL': null,
    });

    batch.set(tripRef.collection('members').doc(ownerId), {
      'uid': ownerId,
      'displayName': displayName,
      'email': email,
      'avatarSeed': avatarSeed,
      'avatarColor': avatarColor,
      'nightsStayed': 0,
      'amountPaid': 0.0,
      'pendingPaymentAmount': 0.0,
      'pendingPaymentStatus': 'none',
      'status': 'active',
      'isGuest': false,
    });

    await batch.commit();
    return tripRef.id;
  }

  Future<void> updateTripDetails(
    String tripId, {
    String? name,
    String? emoji,
    String? description,
    List<String>? pendingEmails,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (emoji != null) updates['emoji'] = emoji;
    if (description != null) updates['description'] = description;
    if (pendingEmails != null) {
      updates['pendingInviteEmails'] = pendingEmails.map((e) => e.toLowerCase()).toList();
    }
    if (updates.isEmpty) return;
    await _db.collection('trips').doc(tripId).update(updates);
  }

  Future<void> updateHouseDetails({
    required String tripId,
    required String houseURL,
    required String address,
    required int totalNights,
    required double totalCost,
    required int checkInMillis,
    required int checkOutMillis,
  }) async {
    await _db.collection('trips').doc(tripId).update({
      'houseURL': houseURL,
      'address': address,
      'totalNights': totalNights,
      'totalCost': totalCost,
      'checkInMillis': checkInMillis,
      'checkOutMillis': checkOutMillis,
    });
  }

  // ── Rides ──────────────────────────────────────────────────────────────────

  Future<void> addRide(
    String tripId, {
    required String driverUid,
    required String driverName,
    required String vehicleEmoji,
    required String vehicleLabel,
    required String departureLocation,
    required int totalSeats,
    required int departureTime,
    required int returnTime,
    required String notes,
  }) async {
    await _db.collection('trips').doc(tripId).collection('rides').add({
      'driverUid': driverUid,
      'driverName': driverName,
      'vehicleEmoji': vehicleEmoji,
      'vehicleLabel': vehicleLabel,
      'departureLocation': departureLocation,
      'totalSeats': totalSeats,
      'departureTime': departureTime,
      'returnTime': returnTime,
      'notes': notes,
      'passengerUids': [],
      'passengerNames': [],
    });
  }

  Future<void> updateRide(
    String tripId,
    String rideId, {
    required String vehicleEmoji,
    required String vehicleLabel,
    required String departureLocation,
    required int totalSeats,
    required int departureTime,
    required int returnTime,
    required String notes,
  }) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rides')
        .doc(rideId)
        .update({
      'vehicleEmoji': vehicleEmoji,
      'vehicleLabel': vehicleLabel,
      'departureLocation': departureLocation,
      'totalSeats': totalSeats,
      'departureTime': departureTime,
      'returnTime': returnTime,
      'notes': notes,
    });
  }

  Future<void> deleteRide(String tripId, String rideId) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rides')
        .doc(rideId)
        .delete();
  }

  Future<void> claimSeat(
    String tripId,
    String rideId,
    String uid,
    String displayName,
  ) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rides')
        .doc(rideId)
        .update({
      'passengerUids': FieldValue.arrayUnion([uid]),
      'passengerNames': FieldValue.arrayUnion([displayName]),
    });
    // also clear any pending ride request for this person
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rideRequests')
        .doc(uid)
        .delete();
  }

  Future<void> unclaimSeat(
    String tripId,
    String rideId,
    String uid,
    String displayName,
  ) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rides')
        .doc(rideId)
        .update({
      'passengerUids': FieldValue.arrayRemove([uid]),
      'passengerNames': FieldValue.arrayRemove([displayName]),
    });
  }

  Future<void> addRideRequest(
    String tripId,
    String uid,
    String displayName,
  ) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rideRequests')
        .doc(uid)
        .set({'uid': uid, 'displayName': displayName, 'notes': ''});
  }

  Future<void> cancelRideRequest(String tripId, String uid) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('rideRequests')
        .doc(uid)
        .delete();
  }

  // ── Supplies ───────────────────────────────────────────────────────────────

  Future<void> addSupplyItem(
    String tripId,
    String name,
    String category,
    String quantity,
  ) async {
    final snap = await _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .orderBy('sortOrder', descending: true)
        .limit(1)
        .get();
    final nextOrder = snap.docs.isNotEmpty
        ? ((snap.docs.first.data()['sortOrder'] as num?)?.toInt() ?? 0) + 1
        : 0;
    await _db.collection('trips').doc(tripId).collection('supplies').add({
      'name': name,
      'category': category,
      'quantity': quantity,
      'claimedByUids': [],
      'claimedByName': '',
      'sortOrder': nextOrder,
    });
  }

  Future<void> deleteSupplyItem(String tripId, String supplyId) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .doc(supplyId)
        .delete();
  }

  Future<void> claimSupplyItem(
    String tripId,
    SupplyItem supply,
    String uid,
    String displayName,
    String personQuantity,
  ) async {
    final updated = supply.addClaim(uid, displayName, personQuantity);
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .doc(supply.id)
        .update({
      'claimedByUids': updated.claimedByUids,
      'claimedByName': updated.claimedByName,
      'quantity': updated.quantity,
    });
    await _logHistory(tripId, 'supplies', '$displayName claimed ${supply.name}');
  }

  Future<void> unclaimSupplyItem(
    String tripId,
    SupplyItem supply,
    String uid,
    String displayName,
  ) async {
    final updated = supply.removeClaim(uid, displayName);
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .doc(supply.id)
        .update({
      'claimedByUids': updated.claimedByUids,
      'claimedByName': updated.claimedByName,
      'quantity': updated.quantity,
    });
    await _logHistory(tripId, 'supplies', '$displayName unclaimed ${supply.name}');
  }

  Future<void> reorderSupplyItems(
      String tripId, List<SupplyItem> items) async {
    final batch = _db.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(
        _db.collection('trips').doc(tripId).collection('supplies').doc(items[i].id),
        {'sortOrder': i},
      );
    }
    await batch.commit();
  }

  // ── Expenses ───────────────────────────────────────────────────────────────

  Future<void> submitExpense(
    String tripId, {
    required String description,
    required double amount,
    required String splitMethod,
    required String submittedByUid,
    required String submittedByName,
    String category = 'misc',
    String? linkedSupplyId,
  }) async {
    await _db.collection('trips').doc(tripId).collection('expenses').add({
      'description': description,
      'amount': amount,
      'splitMethod': splitMethod,
      'submittedByUid': submittedByUid,
      'submittedByName': submittedByName,
      'category': category,
      'linkedSupplyId': linkedSupplyId,
      'approved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _logHistory(
        tripId, 'expenses', '$submittedByName submitted expense: $description');
  }

  Future<void> approveExpense(
      String tripId, String expenseId, String adminName) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expenseId)
        .update({'approved': true});
    await _logHistory(tripId, 'expenses', '$adminName approved an expense');
  }

  Future<void> deleteExpense(
      String tripId, String expenseId, String description, String adminName) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
    await _logHistory(
        tripId, 'expenses', '$adminName deleted expense: $description');
  }

  Future<void> regenerateInviteCode(String tripId) async {
    final code = ic.generateInviteCode();
    await _db.collection('trips').doc(tripId).update({'inviteCode': code});
  }

  Future<void> toggleInviteCode(String tripId, bool enabled) async {
    await _db.collection('trips').doc(tripId).update({'inviteCodeEnabled': enabled});
  }

  Future<Trip?> findTripByInviteCode(String code) async {
    final normalized = ic.normalizeInviteCode(code);
    final snap = await _db
        .collection('trips')
        .where('inviteCode', isEqualTo: normalized)
        .where('inviteCodeEnabled', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Trip.fromFirestore(snap.docs.first);
  }

  Future<void> joinTripByCode(String tripId, TripMember member) async {
    final batch = _db.batch();
    final tripRef = _db.collection('trips').doc(tripId);
    batch.update(tripRef, {
      'memberIds': FieldValue.arrayUnion([member.uid]),
    });
    batch.set(tripRef.collection('members').doc(member.uid), member.toMap());
    await batch.commit();
  }

  Future<void> addPendingInvite(String tripId, String email) async {
    await _db.collection('trips').doc(tripId).update({
      'pendingInviteEmails': FieldValue.arrayUnion([email.toLowerCase()]),
    });
  }

  Future<void> removePendingInvite(String tripId, String email) async {
    await _db.collection('trips').doc(tripId).update({
      'pendingInviteEmails': FieldValue.arrayRemove([email.toLowerCase()]),
    });
  }

  Future<void> updateMemberNights(String tripId, String uid, int nights) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('members')
        .doc(uid)
        .update({'nightsStayed': nights});
  }

  Future<void> submitPayment(
      String tripId, String uid, double amount, String memberName) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('members')
        .doc(uid)
        .update({
      'pendingPaymentAmount': amount,
      'pendingPaymentStatus': 'pending',
    });
    await _logHistory(tripId, 'payments', '$memberName submitted \$$amount payment');
  }

  Future<void> approvePayment(
    String tripId,
    String uid,
    double amount,
    String memberName,
    String adminName,
  ) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('members')
        .doc(uid)
        .update({
      'amountPaid': FieldValue.increment(amount),
      'pendingPaymentAmount': 0.0,
      'pendingPaymentStatus': 'none',
    });
    await _logHistory(
        tripId, 'payments', "$adminName approved $memberName's \$$amount payment");
  }

  Future<void> rejectPayment(
    String tripId,
    String uid,
    String memberName,
    String adminName,
  ) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('members')
        .doc(uid)
        .update({'pendingPaymentStatus': 'rejected'});
    await _logHistory(tripId, 'payments', "$adminName rejected $memberName's payment");
  }

  Future<void> deactivateMember(
    String tripId,
    TripMember member,
    String adminName,
    List<SupplyItem> supplies,
    List<Ride> rides,
  ) async {
    final batch = _db.batch();
    final tripRef = _db.collection('trips').doc(tripId);
    final uid = member.uid;

    batch.update(tripRef, {
      'memberIds': FieldValue.arrayRemove([uid]),
      'deactivatedMemberIds': FieldValue.arrayUnion([uid]),
    });

    batch.update(tripRef.collection('members').doc(uid), {
      'status': 'deactivated',
      'pendingPaymentStatus': 'none',
    });

    for (final supply in supplies) {
      if (supply.claimedByUids.contains(uid)) {
        final updated = supply.removeClaim(uid, member.displayName);
        batch.update(tripRef.collection('supplies').doc(supply.id), {
          'claimedByUids': updated.claimedByUids,
          'claimedByName': updated.claimedByName,
          'quantity': updated.quantity,
        });
      }
    }

    for (final ride in rides) {
      if (ride.driverUid == uid) {
        batch.delete(tripRef.collection('rides').doc(ride.id));
        for (int i = 0; i < ride.passengerUids.length; i++) {
          final passengerUid = ride.passengerUids[i];
          final passengerName =
              i < ride.passengerNames.length ? ride.passengerNames[i] : '';
          batch.set(tripRef.collection('rideRequests').doc(passengerUid), {
            'uid': passengerUid,
            'displayName': passengerName,
            'notes': '',
          });
        }
      } else if (ride.passengerUids.contains(uid)) {
        final idx = ride.passengerUids.indexOf(uid);
        final name =
            idx >= 0 && idx < ride.passengerNames.length ? ride.passengerNames[idx] : '';
        batch.update(tripRef.collection('rides').doc(ride.id), {
          'passengerUids': FieldValue.arrayRemove([uid]),
          'passengerNames': FieldValue.arrayRemove([name]),
        });
      }
    }

    await batch.commit();
    await _logHistory(tripId, 'members', '$adminName deactivated ${member.displayName}');
  }

  Future<void> reactivateMember(String tripId, String uid) async {
    final batch = _db.batch();
    final tripRef = _db.collection('trips').doc(tripId);
    batch.update(tripRef, {
      'memberIds': FieldValue.arrayUnion([uid]),
      'deactivatedMemberIds': FieldValue.arrayRemove([uid]),
    });
    batch.update(tripRef.collection('members').doc(uid), {'status': 'active'});
    await batch.commit();
  }

  Future<void> addGuestMember(
      String tripId, String displayName, String adminName) async {
    final guestRef = _db.collection('trips').doc(tripId).collection('members').doc();
    final avatarSeed = DateTime.now().millisecondsSinceEpoch % 12 + 1;
    await guestRef.set({
      'uid': guestRef.id,
      'displayName': displayName,
      'email': '',
      'avatarSeed': avatarSeed,
      'avatarColor': 0,
      'nightsStayed': 0,
      'amountPaid': 0.0,
      'pendingPaymentAmount': 0.0,
      'pendingPaymentStatus': 'none',
      'status': 'active',
      'isGuest': true,
    });
    await _logHistory(tripId, 'members', '$adminName added guest member $displayName');
  }

  Future<void> removeGuestMember(
      String tripId, String uid, String displayName, String adminName) async {
    await _db.collection('trips').doc(tripId).collection('members').doc(uid).delete();
    await _logHistory(tripId, 'members', '$adminName removed guest member $displayName');
  }

  Stream<List<TripHistoryEvent>> getHistoryStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TripHistoryEvent.fromFirestore).toList());
  }

  Stream<List<Trip>> getPendingInviteTripsStream(String email) {
    return _db
        .collection('trips')
        .where('pendingInviteEmails', arrayContains: email.toLowerCase())
        .snapshots()
        .map((snap) => snap.docs.map(Trip.fromFirestore).toList());
  }

  Future<void> acceptSingleInvite(
    String tripId,
    String uid,
    String email,
    String displayName,
    int avatarSeed,
    int avatarColor,
  ) async {
    final batch = _db.batch();
    final tripRef = _db.collection('trips').doc(tripId);
    batch.update(tripRef, {
      'memberIds': FieldValue.arrayUnion([uid]),
      'pendingInviteEmails': FieldValue.arrayRemove([email.toLowerCase()]),
    });
    batch.set(tripRef.collection('members').doc(uid), {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'avatarSeed': avatarSeed,
      'avatarColor': avatarColor,
      'nightsStayed': 0,
      'amountPaid': 0.0,
      'pendingPaymentAmount': 0.0,
      'pendingPaymentStatus': 'none',
      'status': 'active',
      'isGuest': false,
    });
    await batch.commit();
  }

  Future<void> _logHistory(
      String tripId, String category, String description) async {
    try {
      await _db.collection('trips').doc(tripId).collection('history').add({
        'category': category,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
