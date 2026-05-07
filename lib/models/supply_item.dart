import 'package:cloud_firestore/cloud_firestore.dart';

class SupplyItem {
  final String id;
  final String name;
  final String category;
  final String quantity;
  final List<String> claimedByUids;
  final String claimedByName;
  final int sortOrder;

  const SupplyItem({
    required this.id,
    required this.name,
    this.category = '',
    this.quantity = '',
    this.claimedByUids = const [],
    this.claimedByName = '',
    this.sortOrder = 0,
  });

  List<String> get claimedNames => claimedByName.isNotEmpty
      ? claimedByName.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
      : [];

  bool get isClaimed => claimedByUids.isNotEmpty;

  Map<String, String> get claimEntries {
    if (!quantity.contains('=')) return {};
    final entries = <String, String>{};
    for (final part in quantity.split('|')) {
      final idx = part.indexOf('=');
      if (idx > 0) entries[part.substring(0, idx)] = part.substring(idx + 1);
    }
    return entries;
  }

  String get displayQuantity {
    final entries = claimEntries;
    if (entries.isEmpty) return quantity;
    return entries.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  String? quantityForPerson(String name) => claimEntries[name];

  SupplyItem addClaim(String uid, String displayName, String personQuantity) {
    final newEntries = Map<String, String>.from(claimEntries)..[displayName] = personQuantity;
    final newQuantity = newEntries.entries.map((e) => '${e.key}=${e.value}').join('|');
    return SupplyItem(
      id: id,
      name: name,
      category: category,
      quantity: newQuantity,
      claimedByUids: [...claimedByUids, uid],
      claimedByName: [...claimedNames, displayName].join(','),
      sortOrder: sortOrder,
    );
  }

  SupplyItem removeClaim(String uid, String displayName) {
    final newUids = claimedByUids.where((u) => u != uid).toList();
    final newNames = claimedNames.where((n) => n != displayName).toList();
    final newEntries = Map<String, String>.from(claimEntries)..remove(displayName);
    final newQuantity = newEntries.isEmpty
        ? quantity
        : newEntries.entries.map((e) => '${e.key}=${e.value}').join('|');
    return SupplyItem(
      id: id,
      name: name,
      category: category,
      quantity: newQuantity,
      claimedByUids: newUids,
      claimedByName: newNames.join(','),
      sortOrder: sortOrder,
    );
  }

  factory SupplyItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SupplyItem(
      id: doc.id,
      name: d['name'] as String? ?? '',
      category: d['category'] as String? ?? '',
      quantity: d['quantity'] as String? ?? '',
      claimedByUids: List<String>.from(d['claimedByUids'] as List? ?? []),
      claimedByName: d['claimedByName'] as String? ?? '',
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'quantity': quantity,
        'claimedByUids': claimedByUids,
        'claimedByName': claimedByName,
        'sortOrder': sortOrder,
      };
}
