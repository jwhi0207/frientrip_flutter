import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String senderUid;
  final String senderName;
  final int senderAvatarSeed;
  final int senderAvatarColor;
  final DateTime? createdAt;
  final bool deleted;
  final bool edited;
  final bool isAnnouncement;
  final String? mediaUrl;
  final String? mediaStoragePath;
  final String? mediaType; // 'photo' or 'video'
  final Map<String, List<String>> reactions; // emoji → list of uids

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  const Message({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.senderName,
    this.senderAvatarSeed = 0,
    this.senderAvatarColor = 0,
    this.createdAt,
    this.deleted = false,
    this.edited = false,
    this.isAnnouncement = false,
    this.mediaUrl,
    this.mediaStoragePath,
    this.mediaType,
    this.reactions = const {},
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      text: d['text'] as String? ?? '',
      senderUid: d['senderUid'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      senderAvatarSeed: (d['senderAvatarSeed'] as num?)?.toInt() ?? 0,
      senderAvatarColor: (d['senderAvatarColor'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      deleted: d['deleted'] as bool? ?? false,
      edited: d['edited'] as bool? ?? false,
      isAnnouncement: d['isAnnouncement'] as bool? ?? false,
      mediaUrl: d['mediaUrl'] as String?,
      mediaStoragePath: d['mediaStoragePath'] as String?,
      mediaType: d['mediaType'] as String?,
      reactions: _parseReactions(d['reactions']),
    );
  }

  static Map<String, List<String>> _parseReactions(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((key, value) => MapEntry(
          key as String,
          (value as List<dynamic>).cast<String>(),
        ));
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'senderUid': senderUid,
        'senderName': senderName,
        'senderAvatarSeed': senderAvatarSeed,
        'senderAvatarColor': senderAvatarColor,
        'createdAt': FieldValue.serverTimestamp(),
        'deleted': false,
        'edited': false,
        'isAnnouncement': isAnnouncement,
      };
}
