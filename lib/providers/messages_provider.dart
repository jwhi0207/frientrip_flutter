import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../repositories/message_repository.dart';

final messageRepositoryProvider =
    Provider<MessageRepository>((_) => MessageRepository());

final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, tripId) {
  return ref.watch(messageRepositoryProvider).getMessagesStream(tripId);
});
