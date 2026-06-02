import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_media.dart';
import '../repositories/media_repository.dart';

final mediaRepositoryProvider =
    Provider<MediaRepository>((_) => MediaRepository());

final mediaStreamProvider =
    StreamProvider.family<List<TripMedia>, String>((ref, tripId) {
  return ref.watch(mediaRepositoryProvider).getMediaStream(tripId);
});
