import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/trip_provider.dart';

class AnnouncementScreen extends ConsumerStatefulWidget {
  final String tripId;
  const AnnouncementScreen({super.key, required this.tripId});

  @override
  ConsumerState<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends ConsumerState<AnnouncementScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final members =
        ref.read(tripMembersProvider(widget.tripId)).valueOrNull ?? [];
    final me = members.where((m) => m.uid == uid).firstOrNull;
    if (me == null) return;

    setState(() => _sending = true);

    try {
      // 1. Send as a message on the messages screen (with announcement flag)
      await ref.read(messageRepositoryProvider).sendAnnouncement(
            widget.tripId,
            text: text,
            senderUid: uid,
            senderName: me.displayName,
            senderAvatarSeed: me.avatarSeed,
            senderAvatarColor: me.avatarColor,
          );

      // 2. Save announcement text + timestamp on the trip doc (for the banner)
      await ref
          .read(tripRepositoryProvider)
          .saveAnnouncement(widget.tripId, text);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _controller.text.trim().isNotEmpty && !_sending;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Trip Announcement'),
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: canSend ? _send : null,
              child: Text(
                'Send',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: canSend
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withAlpha(80),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
          expands: false,
          minLines: 12,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Write your announcement...',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }
}
