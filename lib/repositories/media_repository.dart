import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/trip_media.dart';

class MediaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference _mediaRef(String tripId) =>
      _db.collection('trips').doc(tripId).collection('media');

  Stream<List<TripMedia>> getMediaStream(String tripId) {
    return _mediaRef(tripId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TripMedia.fromFirestore).toList());
  }

  /// Uploads a file to Firebase Storage, writes a media doc, and returns
  /// the download URL and storage path so callers can reference the media.
  Future<({String url, String storagePath})> uploadMedia(
    String tripId, {
    required File file,
    required String type,
    required String uploadedByUid,
    required String uploadedByName,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uid4 = uploadedByUid.length >= 4
        ? uploadedByUid.substring(0, 4)
        : uploadedByUid;
    final storagePath = 'trips/$tripId/media/${ts}_$uid4.$ext';
    final fileName = '${ts}_$uid4.$ext';

    final task = await _storage.ref(storagePath).putFile(file);
    final url = await task.ref.getDownloadURL();

    await _mediaRef(tripId).add({
      'uploadedByUid': uploadedByUid,
      'uploadedByName': uploadedByName,
      'type': type,
      'storageUrl': url,
      'storagePath': storagePath,
      'fileName': fileName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return (url: url, storagePath: storagePath);
  }

  Future<void> deleteMedia(
      String tripId, String mediaId, String storagePath) async {
    await _storage.ref(storagePath).delete();
    await _mediaRef(tripId).doc(mediaId).delete();
  }
}
