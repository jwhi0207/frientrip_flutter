import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/trip_media.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/members_provider.dart' hide tripMembersProvider;
import 'media_preview_screen.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  final String tripId;
  const PhotosScreen({super.key, required this.tripId});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  String? _filterUid;
  DateTime? _filterDate;
  bool _uploading = false;
  int _uploadedCount = 0;
  int _uploadTotal = 0;
  bool _downloading = false;
  int _downloadedCount = 0;
  int _downloadTotal = 0;

  List<TripMedia> _applyFilters(List<TripMedia> all) {
    return all.where((m) {
      if (_filterUid != null && m.uploadedByUid != _filterUid) return false;
      if (_filterDate != null && m.createdAt != null) {
        final d = m.createdAt!;
        final f = _filterDate!;
        if (d.year != f.year || d.month != f.month || d.day != f.day) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              subtitle: const Text('Photos & videos · up to 10 items'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final files = await ImagePicker().pickMultipleMedia(limit: 10);
    if (files.isEmpty || !mounted) return;
    await _uploadFiles(files);
  }

  Future<void> _pickFromCamera() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (xfile == null || !mounted) return;
    await _uploadFiles([xfile]);
  }

  Future<void> _uploadFiles(List<XFile> files) async {
    const maxPhotoBytes = 25 * 1024 * 1024;
    const maxVideoBytes = 100 * 1024 * 1024;

    for (final f in files) {
      final isVideo = _isVideoFile(f.name);
      final size = File(f.path).lengthSync();
      final limit = isVideo ? maxVideoBytes : maxPhotoBytes;
      if (size > limit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              '"${f.name}" is too large. Limit is ${isVideo ? '100 MB' : '25 MB'}.',
            ),
          ));
        }
        return;
      }
    }

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final member = ref.read(currentUserMemberProvider(widget.tripId));
    final name = member?.displayName ?? 'Member';

    setState(() {
      _uploading = true;
      _uploadTotal = files.length;
      _uploadedCount = 0;
    });

    try {
      final repo = ref.read(mediaRepositoryProvider);
      for (final xfile in files) {
        await repo.uploadMedia(
          widget.tripId,
          file: File(xfile.path),
          type: _isVideoFile(xfile.name) ? 'video' : 'photo',
          uploadedByUid: uid,
          uploadedByName: name,
        ); // return value not needed here — stream picks it up
        if (mounted) setState(() => _uploadedCount++);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${files.length} ${files.length == 1 ? 'item' : 'items'} uploaded',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool _isVideoFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }

  Future<void> _downloadAll(List<TripMedia> items) async {
    if (items.isEmpty || _downloading) return;

    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Gallery access is required to save media.')),
          );
        }
        return;
      }
    }

    setState(() {
      _downloading = true;
      _downloadTotal = items.length;
      _downloadedCount = 0;
    });

    try {
      final dir = await getTemporaryDirectory();
      for (final item in items) {
        final file = File('${dir.path}/${item.fileName}');
        final response = await http.get(Uri.parse(item.storageUrl));
        await file.writeAsBytes(response.bodyBytes);
        if (item.isVideo) {
          await Gal.putVideo(file.path, album: 'Frientrip');
        } else {
          await Gal.putImage(file.path, album: 'Frientrip');
        }
        await file.delete();
        if (mounted) setState(() => _downloadedCount++);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${items.length} ${items.length == 1 ? 'item' : 'items'} saved to gallery',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _confirmDelete(TripMedia media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(media.isVideo ? 'Delete Video?' : 'Delete Photo?'),
        content: const Text('This will permanently remove it from the trip.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(mediaRepositoryProvider)
          .deleteMedia(widget.tripId, media.id, media.storagePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _showFilterSheet(List<TripMedia> allMedia) {
    final Map<String, String> uploaders = {};
    for (final m in allMedia) {
      uploaders[m.uploadedByUid] = m.uploadedByName;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          String? selectedUid = _filterUid;
          DateTime? selectedDate = _filterDate;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter by Member',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('All Members'),
                        selected: selectedUid == null,
                        onSelected: (_) => setModal(() => selectedUid = null),
                      ),
                      ...uploaders.entries.map(
                        (e) => FilterChip(
                          label: Text(e.value),
                          selected: selectedUid == e.key,
                          onSelected: (_) =>
                              setModal(() => selectedUid = e.key),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Filter by Date',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          selectedDate != null
                              ? DateFormat('MMM d, yyyy').format(selectedDate)
                              : 'Any Date',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModal(() => selectedDate = picked);
                          }
                        },
                      ),
                      if (selectedDate != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setModal(() => selectedDate = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterUid = null;
                            _filterDate = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear Filters'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _filterUid = selectedUid;
                            _filterDate = selectedDate;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaStreamProvider(widget.tripId));
    final hasFilters = _filterUid != null || _filterDate != null;
    final busy = _uploading || _downloading;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: busy ? null : _showUploadSheet,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_photo_alternate),
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allMedia) {
          final currentUid = ref.watch(currentUidProvider);
          final filtered = _applyFilters(allMedia);
          return Stack(
            children: [
              Column(
                children: [
                  // ── Action row ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                    child: Row(
                      children: [
                        Text(
                          filtered.isEmpty
                              ? 'No items'
                              : '${filtered.length} ${filtered.length == 1 ? 'item' : 'items'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        if (hasFilters)
                          TextButton(
                            onPressed: () => setState(() {
                              _filterUid = null;
                              _filterDate = null;
                            }),
                            child: const Text('Clear'),
                          ),
                        Badge(
                          isLabelVisible: hasFilters,
                          child: IconButton(
                            icon: const Icon(Icons.filter_list),
                            tooltip: 'Filter',
                            onPressed: allMedia.isEmpty
                                ? null
                                : () => _showFilterSheet(allMedia),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Download all',
                          onPressed: filtered.isEmpty || _downloading
                              ? null
                              : () => _downloadAll(filtered),
                        ),
                      ],
                    ),
                  ),

                  // ── Grid or empty state ────────────────────────────────
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyState(
                            hasFilters: hasFilters,
                            onUpload: _showUploadSheet,
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(2, 0, 2, 88),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final media = filtered[i];
                              final isOwner =
                                  media.uploadedByUid == currentUid;
                              return _MediaTile(
                                media: media,
                                isOwner: isOwner,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MediaPreviewScreen(
                                      media: media,
                                      isOwner: isOwner,
                                      onDelete: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        try {
                                          await ref
                                              .read(mediaRepositoryProvider)
                                              .deleteMedia(widget.tripId, media.id, media.storagePath);
                                        } catch (e) {
                                          messenger.showSnackBar(
                                            SnackBar(content: Text('Delete failed: $e')),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                onLongPress: isOwner
                                    ? () => _confirmDelete(media)
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),

              // ── Upload / download progress card ────────────────────────
              if (busy)
                Positioned(
                  bottom: 88,
                  left: 24,
                  right: 24,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _uploading
                                ? 'Uploading $_uploadedCount of $_uploadTotal...'
                                : 'Saving $_downloadedCount of $_downloadTotal...',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Media tile ────────────────────────────────────────────────────────────────

class _MediaTile extends StatelessWidget {
  final TripMedia media;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _MediaTile({
    required this.media,
    required this.isOwner,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media.isPhoto)
            CachedNetworkImage(
              imageUrl: media.storageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.grey.shade800,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade800,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            )
          else
            Container(
              color: Colors.grey.shade900,
              child: const Center(
                child: Icon(Icons.play_circle_fill,
                    size: 36, color: Colors.white70),
              ),
            ),
          // Bottom name overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 3),
              child: Text(
                media.uploadedByName.split(' ').first,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Video badge
          if (media.isVideo)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.videocam, size: 14, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onUpload;
  const _EmptyState({required this.hasFilters, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 72, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No photos match this filter' : 'No photos yet',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 8),
            Text(
              'Tap + to share the first memory!',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
