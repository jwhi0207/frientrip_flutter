import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/trip_media.dart';

class MediaPreviewScreen extends StatefulWidget {
  final TripMedia media;
  final bool isOwner;
  final VoidCallback? onDelete;
  const MediaPreviewScreen({
    super.key,
    required this.media,
    this.isOwner = false,
    this.onDelete,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    if (widget.media.isVideo) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.media.storageUrl),
      )..initialize().then((_) {
          if (mounted) {
            setState(() => _videoInitialized = true);
            _videoController!.play();
            _videoController!.setLooping(true);
          }
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gallery access is required to save media.')),
            );
          }
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.media.fileName}');
      final response = await http.get(Uri.parse(widget.media.storageUrl));
      await file.writeAsBytes(response.bodyBytes);

      if (widget.media.isVideo) {
        await Gal.putVideo(file.path, album: 'Frientrip');
      } else {
        await Gal.putImage(file.path, album: 'Frientrip');
      }

      await file.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to your gallery')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Main media ───────────────────────────────────────────────
          Center(
            child: widget.media.isPhoto
                ? InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: widget.media.storageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const CircularProgressIndicator(),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  )
                : _videoInitialized
                    ? GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_videoController!.value.isPlaying) {
                              _videoController!.pause();
                            } else {
                              _videoController!.play();
                            }
                          });
                        },
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    : const CircularProgressIndicator(),
          ),

          // ── Video play/pause icon ────────────────────────────────────
          if (widget.media.isVideo && _videoInitialized)
            Center(
              child: AnimatedOpacity(
                opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                  ),
                ),
              ),
            ),

          // ── Top bar ──────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.media.uploadedByName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.media.createdAt != null)
                          Text(
                            DateFormat('MMM d, yyyy')
                                .format(widget.media.createdAt!),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom bar: save + delete ────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _downloading ? null : _download,
                      icon: _downloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download),
                      label: const Text('Save to Device'),
                    ),
                    if (widget.isOwner && widget.onDelete != null) ...[
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(widget.media.isVideo
                                  ? 'Delete Video?'
                                  : 'Delete Photo?'),
                              content: const Text(
                                  'This will permanently remove it from the trip.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Delete',
                                      style: TextStyle(
                                          color: Theme.of(ctx).colorScheme.error)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            nav.pop();
                            widget.onDelete!();
                          }
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
