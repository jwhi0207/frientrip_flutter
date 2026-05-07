import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_history_event.dart';
import '../repositories/history_repository.dart';

final historyRepositoryProvider =
    Provider<HistoryRepository>((_) => HistoryRepository());

final tripHistoryProvider =
    StreamProvider.family<List<TripHistoryEvent>, String>((ref, tripId) {
  return ref.watch(historyRepositoryProvider).getHistoryStream(tripId);
});
