import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../models/trip_media.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/messages_provider.dart';
import '../../widgets/avatar_widget.dart';
import 'media_preview_screen.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  final String tripId;
  const MessagesScreen({super.key, required this.tripId});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  // Edit mode state
  String? _editingMessageId;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startEditing(Message msg) {
    setState(() {
      _editingMessageId = msg.id;
      _controller.text = msg.text;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _controller.clear();
    });
  }

  void _showMediaPickSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              subtitle: const Text('Photos & videos'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendMedia(fromCamera: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendMedia(fromCamera: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isVideoFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }

  Future<void> _pickAndSendMedia({required bool fromCamera}) async {
    XFile? xfile;
    if (fromCamera) {
      xfile = await ImagePicker().pickImage(source: ImageSource.camera);
    } else {
      xfile = await ImagePicker().pickMedia();
    }
    if (xfile == null || !mounted) return;

    final isVideo = _isVideoFile(xfile.name);
    const maxPhotoBytes = 25 * 1024 * 1024;
    const maxVideoBytes = 100 * 1024 * 1024;
    final size = File(xfile.path).lengthSync();
    if (size > (isVideo ? maxVideoBytes : maxPhotoBytes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'File is too large. Limit is ${isVideo ? '100 MB' : '25 MB'}.'),
        ));
      }
      return;
    }

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final members =
        ref.read(tripMembersProvider(widget.tripId)).valueOrNull ?? [];
    final me = members.where((m) => m.uid == uid).firstOrNull;
    if (me == null) return;

    setState(() => _sending = true);
    try {
      // Upload to media collection — also surfaces in Photos tab
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final result = await mediaRepo.uploadMedia(
        widget.tripId,
        file: File(xfile.path),
        type: isVideo ? 'video' : 'photo',
        uploadedByUid: uid,
        uploadedByName: me.displayName,
      );

      // Send as a message referencing the uploaded media
      await ref.read(messageRepositoryProvider).sendMessage(
        widget.tripId,
        text: '',
        senderUid: uid,
        senderName: me.displayName,
        senderAvatarSeed: me.avatarSeed,
        senderAvatarColor: me.avatarColor,
        mediaUrl: result.url,
        mediaStoragePath: result.storagePath,
        mediaType: isVideo ? 'video' : 'photo',
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final repo = ref.read(messageRepositoryProvider);

    // If editing an existing message
    if (_editingMessageId != null) {
      setState(() => _sending = true);
      final msgId = _editingMessageId!;
      _cancelEditing();
      try {
        await repo.editMessage(widget.tripId, msgId, text);
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    // Sending a new message
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final members =
        ref.read(tripMembersProvider(widget.tripId)).valueOrNull ?? [];
    final me = members.where((m) => m.uid == uid).firstOrNull;
    if (me == null) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await repo.sendMessage(
        widget.tripId,
        text: text,
        senderUid: uid,
        senderName: me.displayName,
        senderAvatarSeed: me.avatarSeed,
        senderAvatarColor: me.avatarColor,
      );
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final uid = ref.watch(currentUidProvider);
    final messagesAsync = ref.watch(messagesProvider(widget.tripId));

    // Auto-scroll when new messages arrive
    ref.listen(messagesProvider(widget.tripId), (prev, next) {
      final prevLen = prev?.valueOrNull?.length ?? 0;
      final nextLen = next.valueOrNull?.length ?? 0;
      if (nextLen > prevLen) _scrollToBottom();
    });

    return Column(
      children: [
        // ── Message list ──────────────────────────────────────────────
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading messages')),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: cs.onSurfaceVariant.withAlpha(80)),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start the conversation!',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withAlpha(150)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderUid == uid;
                  final showAvatar = index == 0 ||
                      messages[index - 1].senderUid != msg.senderUid ||
                      messages[index - 1].deleted;
                  final showTimestamp = index == 0 ||
                      _shouldShowTimestamp(
                          messages[index - 1].createdAt, msg.createdAt);

                  return _MessageBubble(
                    message: msg,
                    isMe: isMe,
                    showAvatar: showAvatar,
                    showTimestamp: showTimestamp,
                    isEditing: _editingMessageId == msg.id,
                    onEdit: isMe && !msg.deleted
                        ? () => _startEditing(msg)
                        : null,
                    onDelete: isMe && !msg.deleted
                        ? () => ref
                            .read(messageRepositoryProvider)
                            .deleteMessage(widget.tripId, msg.id)
                        : null,
                    tripId: widget.tripId,
                    currentUid: uid ?? '',
                    onReaction: (emoji) {
                      if (uid == null) return;
                      ref.read(messageRepositoryProvider).toggleReaction(
                            widget.tripId, msg.id, emoji, uid);
                    },
                  );
                },
              );
            },
          ),
        ),

        // ── Edit banner ───────────────────────────────────────────────
        if (_editingMessageId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              border: Border(
                top: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.edit, size: 16, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Text('Editing message',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onPrimaryContainer)),
                const Spacer(),
                GestureDetector(
                  onTap: _cancelEditing,
                  child: Icon(Icons.close, size: 18, color: cs.onPrimaryContainer),
                ),
              ],
            ),
          ),

        // ── Input bar ─────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                children: [
                  if (_editingMessageId == null)
                    IconButton(
                      icon: const Icon(Icons.image_outlined),
                      tooltip: 'Send photo or video',
                      onPressed: _sending ? null : _showMediaPickSheet,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      maxLines: 4,
                      minLines: 1,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _editingMessageId != null
                            ? 'Edit message...'
                            : 'Message...',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _editingMessageId != null
                                ? Icons.check
                                : Icons.send,
                            size: 20,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldShowTimestamp(DateTime? prev, DateTime? current) {
    if (prev == null || current == null) return true;
    return current.difference(prev).inMinutes > 15;
  }
}

const _reactionEmojis = ['👍', '❤️', '😂', '😮', '🎉', '🔥'];

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  final bool showTimestamp;
  final bool isEditing;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String tripId;
  final String currentUid;
  final ValueChanged<String>? onReaction;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.showTimestamp,
    required this.tripId,
    required this.currentUid,
    this.isEditing = false,
    this.onEdit,
    this.onDelete,
    this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Timestamp separator
        if (showTimestamp && message.createdAt != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _formatTimestamp(message.createdAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withAlpha(150)),
              ),
            ),
          ),

        // Announcement label
        if (message.isAnnouncement && !message.deleted)
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 44,
              right: isMe ? 44 : 0,
              bottom: 2,
              top: 4,
            ),
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign,
                      size: 13,
                      color: Colors.orange.shade700),
                  const SizedBox(width: 3),
                  Text(
                    'Announcement',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Sender name (when avatar shown, for all users)
        if (showAvatar && !message.deleted)
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 44,
              right: isMe ? 44 : 0,
              bottom: 2,
            ),
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                message.senderName,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
          ),

        // Bubble row
        Padding(
          padding: EdgeInsets.only(
            top: showAvatar ? 4 : 1,
            bottom: 1,
            left: isMe ? 64 : 0,
            right: isMe ? 0 : 64,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              // Avatar (left side for others)
              if (!isMe)
                SizedBox(
                  width: 36,
                  child: showAvatar && !message.deleted
                      ? AvatarWidget(
                          seed: message.senderAvatarSeed,
                          colorIndex: message.senderAvatarColor,
                          size: 32,
                        )
                      : null,
                ),

              if (!isMe) const SizedBox(width: 8),

              // Bubble + reactions
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    message.deleted
                        ? _buildDeletedBubble(theme, cs)
                        : _buildMessageBubble(context, theme, cs),
                    if (message.reactions.isNotEmpty)
                      _buildReactions(context, theme, cs),
                  ],
                ),
              ),

              // Avatar (right side for own messages)
              if (isMe) const SizedBox(width: 8),
              if (isMe)
                SizedBox(
                  width: 36,
                  child: showAvatar && !message.deleted
                      ? AvatarWidget(
                          seed: message.senderAvatarSeed,
                          colorIndex: message.senderAvatarColor,
                          size: 32,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeletedBubble(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: cs.onSurfaceVariant.withAlpha(120)),
          const SizedBox(width: 6),
          Text(
            'Message deleted',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant.withAlpha(150),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      BuildContext context, ThemeData theme, ColorScheme cs) {
    // Media-only bubble (no text)
    if (message.hasMedia && message.text.isEmpty) {
      final borderRadius = BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMe ? 18 : (showAvatar ? 4 : 18)),
        bottomRight: Radius.circular(isMe ? (showAvatar ? 4 : 18) : 18),
      );
      return GestureDetector(
        onTap: () {
          final media = TripMedia(
            id: message.id,
            uploadedByUid: message.senderUid,
            uploadedByName: message.senderName,
            type: message.mediaType ?? 'photo',
            storageUrl: message.mediaUrl!,
            storagePath: message.mediaStoragePath ?? '',
            fileName: '',
            createdAt: message.createdAt,
          );
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MediaPreviewScreen(media: media)),
          );
        },
        onLongPress: () => _showOptionsSheet(context),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
            width: 200,
            height: 200,
            child: message.mediaType == 'video'
                ? Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Icon(Icons.play_circle_fill,
                          size: 48, color: Colors.white70),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey.shade800,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showOptionsSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isAnnouncement
              ? Colors.orange.shade600
              : isEditing
                  ? (isMe ? cs.primary.withAlpha(180) : cs.primaryContainer)
                  : (isMe ? cs.primary : cs.surfaceContainerHighest),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                Radius.circular(isMe ? 18 : (showAvatar ? 4 : 18)),
            bottomRight:
                Radius.circular(isMe ? (showAvatar ? 4 : 18) : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: message.isAnnouncement
                      ? Colors.white
                      : (isMe ? cs.onPrimary : cs.onSurface),
                ),
              ),
            ),
            if (message.edited)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'edited',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: (isMe ? cs.onPrimary : cs.onSurfaceVariant)
                        .withAlpha(150),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactions(BuildContext context, ThemeData theme, ColorScheme cs) {
    final sorted = message.reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: sorted.map((entry) {
          final isMine = entry.value.contains(currentUid);
          return GestureDetector(
            onTap: () => onReaction?.call(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMine
                    ? cs.primary.withAlpha(40)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMine ? cs.primary.withAlpha(120) : cs.outlineVariant,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.key, style: const TextStyle(fontSize: 14)),
                  if (entry.value.length > 1) ...[
                    const SizedBox(width: 3),
                    Text('${entry.value.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isMine ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji reaction bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _reactionEmojis.map((emoji) {
                  final reacted =
                      message.reactions[emoji]?.contains(currentUid) ?? false;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onReaction?.call(emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: reacted
                            ? cs.primary.withAlpha(40)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onEdit!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete, color: cs.error),
                title: Text('Delete', style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showDeleteDialog(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
            'This message will be replaced with "Message deleted" for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete?.call();
            },
            child: Text('Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return DateFormat.jm().format(dt);
    } else if (diff.inDays == 1) {
      return 'Yesterday ${DateFormat.jm().format(dt)}';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE').add_jm().format(dt);
    } else {
      return DateFormat.yMMMd().add_jm().format(dt);
    }
  }
}
