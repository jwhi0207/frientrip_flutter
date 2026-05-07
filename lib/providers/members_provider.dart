import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_member.dart';
import 'auth_provider.dart';
import 'trip_provider.dart';

final tripMembersProvider =
    StreamProvider.family<List<TripMember>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getTripMembersStream(tripId);
});

final currentUserMemberProvider =
    Provider.family<TripMember?, String>((ref, tripId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  final members = ref.watch(tripMembersProvider(tripId)).valueOrNull;
  if (members == null) return null;
  try {
    return members.firstWhere((m) => m.uid == uid);
  } catch (_) {
    return null;
  }
});
