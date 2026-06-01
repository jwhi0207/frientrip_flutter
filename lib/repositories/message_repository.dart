import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class MessageRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _messagesRef(String tripId) =>
      _db.collection('trips').doc(tripId).collection('messages');

  Stream<List<Message>> getMessagesStream(String tripId) {
    return _messagesRef(tripId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(Message.fromFirestore).toList());
  }

  Future<void> sendMessage(
    String tripId, {
    required String text,
    required String senderUid,
    required String senderName,
    required int senderAvatarSeed,
    required int senderAvatarColor,
  }) async {
    await _messagesRef(tripId).add({
      'text': text,
      'senderUid': senderUid,
      'senderName': senderName,
      'senderAvatarSeed': senderAvatarSeed,
      'senderAvatarColor': senderAvatarColor,
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
      'edited': false,
    });
  }

  Future<void> editMessage(
      String tripId, String messageId, String newText) async {
    await _messagesRef(tripId).doc(messageId).update({
      'text': newText,
      'edited': true,
    });
  }

  Future<void> deleteMessage(String tripId, String messageId) async {
    await _messagesRef(tripId).doc(messageId).update({
      'deleted': true,
      'text': '',
    });
  }
}
