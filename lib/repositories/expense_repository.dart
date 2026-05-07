import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shared_expense.dart';

class ExpenseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<SharedExpense>> getExpensesStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(SharedExpense.fromFirestore).toList());
  }

  Future<void> addExpense(
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
      'category': category,
      'splitMethod': splitMethod,
      'submittedByUid': submittedByUid,
      'submittedByName': submittedByName,
      'approved': false,
      'linkedSupplyId': linkedSupplyId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _logHistory(
        tripId, 'expenses', "$submittedByName submitted '$description' (\$$amount)");
  }

  Future<void> approveExpense(
      String tripId, SharedExpense expense, String adminName) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expense.id)
        .update({'approved': true});
    await _logHistory(tripId, 'expenses',
        "$adminName approved '${expense.description}' (\$${expense.amount})");
  }

  Future<void> deleteExpense(
      String tripId, SharedExpense expense, String actorName) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expense.id)
        .delete();
    await _logHistory(tripId, 'expenses',
        "$actorName deleted '${expense.description}' (\$${expense.amount})");
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
