import 'package:cloud_firestore/cloud_firestore.dart';

class SharedExpense {
  final String id;
  final String description;
  final double amount;
  final String category;
  final String splitMethod;
  final String submittedByUid;
  final String submittedByName;
  final bool approved;
  final String? linkedSupplyId;
  final DateTime createdAt;

  const SharedExpense({
    required this.id,
    required this.description,
    required this.amount,
    this.category = 'misc',
    this.splitMethod = 'even',
    required this.submittedByUid,
    required this.submittedByName,
    this.approved = false,
    this.linkedSupplyId,
    required this.createdAt,
  });

  factory SharedExpense.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['createdAt'];
    // Canonical type is epoch millis (what the Android app writes and reads),
    // but tolerate Timestamp for docs written before the millis migration.
    final createdAt = ts is num
        ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
        : ts is Timestamp
            ? ts.toDate()
            : DateTime.now();
    return SharedExpense(
      id: doc.id,
      description: d['description'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      category: d['category'] as String? ?? 'misc',
      splitMethod: d['splitMethod'] as String? ?? 'even',
      submittedByUid: d['submittedByUid'] as String? ?? '',
      submittedByName: d['submittedByName'] as String? ?? '',
      approved: d['approved'] as bool? ?? false,
      linkedSupplyId: d['linkedSupplyId'] as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'description': description,
        'amount': amount,
        'category': category,
        'splitMethod': splitMethod,
        'submittedByUid': submittedByUid,
        'submittedByName': submittedByName,
        'approved': approved,
        'linkedSupplyId': linkedSupplyId,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}
