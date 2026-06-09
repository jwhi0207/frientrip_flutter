import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../repositories/message_repository.dart';
import 'auth_provider.dart';
import 'members_provider.dart';

final messageRepositoryProvider =
    Provider<MessageRepository>((_) => MessageRepository());

final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, tripId) {
  return ref.watch(messageRepositoryProvider).getMessagesStream(tripId);
});

final unreadMessageCountProvider =
    Provider.family<int, String>((ref, tripId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return 0;
  final member = ref.watch(currentUserMemberProvider(tripId));
  if (member == null) return 0;
  final messages = ref.watch(messagesProvider(tripId)).valueOrNull ?? [];
  final lastSeen = member.lastSeenMessages;
  if (lastSeen == null) return messages.where((m) => m.senderUid != uid && !m.deleted).length;
  return messages.where((m) =>
      m.senderUid != uid &&
      !m.deleted &&
      m.createdAt != null &&
      m.createdAt!.isAfter(lastSeen)).length;
});
