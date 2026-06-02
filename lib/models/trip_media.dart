import 'package:cloud_firestore/cloud_firestore.dart';

class TripMedia {
  final String id;
  final String uploadedByUid;
  final String uploadedByName;
  final String type; // 'photo' or 'video'
  final String storageUrl;
  final String storagePath;
  final String fileName;
  final DateTime? createdAt;

  const TripMedia({
    required this.id,
    required this.uploadedByUid,
    required this.uploadedByName,
    required this.type,
    required this.storageUrl,
    required this.storagePath,
    required this.fileName,
    this.createdAt,
  });

  bool get isVideo => type == 'video';
  bool get isPhoto => type == 'photo';

  factory TripMedia.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TripMedia(
      id: doc.id,
      uploadedByUid: d['uploadedByUid'] as String? ?? '',
      uploadedByName: d['uploadedByName'] as String? ?? '',
      type: d['type'] as String? ?? 'photo',
      storageUrl: d['storageUrl'] as String? ?? '',
      storagePath: d['storagePath'] as String? ?? '',
      fileName: d['fileName'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
