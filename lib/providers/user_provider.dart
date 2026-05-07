import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';
import 'auth_provider.dart';

final userRepositoryProvider =
    Provider<UserRepository>((_) => UserRepository());

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).getUserProfileStream(uid);
});
