import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supply_item.dart';
import '../repositories/supply_repository.dart';

final supplyRepositoryProvider =
    Provider<SupplyRepository>((_) => SupplyRepository());

final suppliesProvider =
    StreamProvider.family<List<SupplyItem>, String>((ref, tripId) {
  return ref.watch(supplyRepositoryProvider).getSuppliesStream(tripId);
});
