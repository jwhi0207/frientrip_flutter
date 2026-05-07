import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip.dart';
import '../models/trip_member.dart';
import '../models/supply_item.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../models/shared_expense.dart';
import '../models/trip_history_event.dart';
import '../repositories/trip_repository.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

final tripRepositoryProvider = Provider<TripRepository>((_) => TripRepository());

final userTripsProvider = StreamProvider<List<Trip>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(tripRepositoryProvider).getUserTripsStream(uid);
});

final tripStreamProvider = StreamProvider.family<Trip?, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getTripStream(tripId);
});

final tripMembersProvider = StreamProvider.family<List<TripMember>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getTripMembersStream(tripId);
});

final tripSuppliesProvider = StreamProvider.family<List<SupplyItem>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getSuppliesStream(tripId);
});

final tripRidesProvider = StreamProvider.family<List<Ride>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getRidesStream(tripId);
});

final tripRideRequestsProvider = StreamProvider.family<List<RideRequest>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getRideRequestsStream(tripId);
});

final tripExpensesProvider = StreamProvider.family<List<SharedExpense>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getExpensesStream(tripId);
});

final tripHistoryProvider = StreamProvider.family<List<TripHistoryEvent>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getHistoryStream(tripId);
});

final pendingInviteTripsProvider = StreamProvider<List<Trip>>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return const Stream.empty();
  return ref.watch(tripRepositoryProvider).getPendingInviteTripsStream(profile.email);
});
