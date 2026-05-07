import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supply_item.dart';
import '../models/trip_member.dart';

class SupplyRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<SupplyItem>> getSuppliesStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs.map(SupplyItem.fromFirestore).toList());
  }

  Future<void> addSupplyItem(
    String tripId, {
    required String name,
    required String category,
    required String quantity,
    required int sortOrder,
    required String actorName,
  }) async {
    await _db.collection('trips').doc(tripId).collection('supplies').add({
      'name': name,
      'category': category,
      'quantity': quantity,
      'claimedByUids': [],
      'claimedByName': '',
      'sortOrder': sortOrder,
    });
    await _logHistory(tripId, 'supplies', '$actorName added $name ($quantity)');
  }

  Future<void> deleteSupplyItem(
      String tripId, SupplyItem item, String actorName) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .doc(item.id)
        .delete();
    await _logHistory(tripId, 'supplies', '$actorName removed ${item.name}');
  }

  Future<void> claimSupplyItem(
    String tripId,
    SupplyItem item,
    TripMember member,
    String personQuantity,
  ) async {
    final updated = item.addClaim(member.uid, member.displayName, personQuantity);
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .doc(item.id)
        .update({
      'claimedByUids': updated.claimedByUids,
      'claimedByName': updated.claimedByName,
      'quantity': updated.quantity,
    });
    await _logHistory(
        tripId, 'supplies', '${member.displayName} claimed ${item.name} ($personQuantity)');
  }

  Future<void> unclaimSupplyItem(
      String tripId, SupplyItem item, TripMember member) async {
    final updated = item.removeClaim(member.uid, member.displayName);
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .doc(item.id)
        .update({
      'claimedByUids': updated.claimedByUids,
      'claimedByName': updated.claimedByName,
      'quantity': updated.quantity,
    });
    await _logHistory(tripId, 'supplies', '${member.displayName} unclaimed ${item.name}');
  }

  Future<void> updateSortOrder(
      String tripId, String supplyId, int sortOrder) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('supplies')
        .doc(supplyId)
        .update({'sortOrder': sortOrder});
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
