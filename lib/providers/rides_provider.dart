import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../repositories/ride_repository.dart';

final rideRepositoryProvider =
    Provider<RideRepository>((_) => RideRepository());

final ridesProvider =
    StreamProvider.family<List<Ride>, String>((ref, tripId) {
  return ref.watch(rideRepositoryProvider).getRidesStream(tripId);
});

final rideRequestsProvider =
    StreamProvider.family<List<RideRequest>, String>((ref, tripId) {
  return ref.watch(rideRepositoryProvider).getRideRequestsStream(tripId);
});
