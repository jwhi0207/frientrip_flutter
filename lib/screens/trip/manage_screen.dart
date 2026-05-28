import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';

class ManageScreen extends ConsumerWidget {
  final String tripId;
  const ManageScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripStreamProvider(tripId)).valueOrNull;
    final allMembers = ref.watch(tripMembersProvider(tripId)).valueOrNull ?? [];
    final supplies = ref.watch(tripSuppliesProvider(tripId)).valueOrNull ?? [];
    final rides = ref.watch(tripRidesProvider(tripId)).valueOrNull ?? [];
    final uid = ref.watch(currentUidProvider);

    final isAdmin = uid == trip?.ownerId;
    final ownerId = trip?.ownerId ?? '';

    final sorted = [...allMembers]..sort((a, b) {
        if (a.isDeactivated != b.isDeactivated) return a.isDeactivated ? 1 : -1;
        return a.displayName.compareTo(b.displayName);
      });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Manage Group'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddGuestDialog(context, ref, uid ?? ''),
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
      body: sorted.isEmpty
          ? const Center(child: Text('No members yet'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final member = sorted[i];
                final isOwner = member.uid == ownerId;
                final dimmed = member.isDeactivated;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Opacity(
                        opacity: dimmed ? 0.4 : 1.0,
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(
                            'https://api.dicebear.com/9.x/pixel-art/png'
                            '?seed=${member.avatarSeed}&size=128',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Opacity(
                          opacity: dimmed ? 0.4 : 1.0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isOwner) ...[
                                    const SizedBox(width: 6),
                                    _Pill(
                                      label: 'OWNER',
                                      bg: Theme.of(context).colorScheme.primaryContainer,
                                      fg: Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                  if (member.isGuest) ...[
                                    const SizedBox(width: 6),
                                    _Pill(
                                      label: 'GUEST',
                                      bg: Theme.of(context).colorScheme.secondaryContainer,
                                      fg: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ],
                                  if (member.isDeactivated) ...[
                                    const SizedBox(width: 6),
                                    _Pill(
                                      label: 'DEACTIVATED',
                                      bg: Theme.of(context).colorScheme.errorContainer,
                                      fg: Theme.of(context).colorScheme.error,
                                    ),
                                  ],
                                ],
                              ),
                              if (member.email.isNotEmpty)
                                Text(
                                  member.email,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (isAdmin && !isOwner) ...[
                        const SizedBox(width: 8),
                        _ActionButton(
                          member: member,
                          onDeactivate: () => _confirmDeactivate(
                              context, ref, member.displayName, () {
                            ref.read(tripRepositoryProvider).deactivateMember(
                                  tripId,
                                  member,
                                  _selfName(ref, uid ?? ''),
                                  supplies,
                                  rides,
                                );
                          }),
                          onReactivate: () => _confirmReactivate(
                              context, ref, member.displayName, () {
                            ref
                                .read(tripRepositoryProvider)
                                .reactivateMember(tripId, member.uid);
                          }),
                          onRemoveGuest: () => _confirmRemoveGuest(
                              context, ref, member.displayName, () {
                            ref.read(tripRepositoryProvider).removeGuestMember(
                                  tripId,
                                  member.uid,
                                  member.displayName,
                                  _selfName(ref, uid ?? ''),
                                );
                          }),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _selfName(WidgetRef ref, String uid) {
    final members = ref.read(tripMembersProvider(tripId)).valueOrNull ?? [];
    return members.where((m) => m.uid == uid).firstOrNull?.displayName ?? 'Admin';
  }

  void _showAddGuestDialog(BuildContext context, WidgetRef ref, String uid) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Guest Member'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Display name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: ctrl.text.trim().isEmpty
                  ? null
                  : () {
                      final name = ctrl.text.trim();
                      ref.read(tripRepositoryProvider).addGuestMember(
                            tripId,
                            name,
                            _selfName(ref, uid),
                          );
                      Navigator.pop(ctx);
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, WidgetRef ref, String name,
      VoidCallback onConfirm) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Deactivate Member'),
          content: Text(
              'Deactivate $name? They will be removed from the group and all supplies/rides.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                onConfirm();
                Navigator.pop(ctx);
              },
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Member'),
        content: Text(
            'Deactivate $name? They will be removed from the group and all supplies/rides.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _confirmReactivate(BuildContext context, WidgetRef ref, String name,
      VoidCallback onConfirm) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Reactivate Member'),
          content: Text('Reactivate $name? They will rejoin the group.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                onConfirm();
                Navigator.pop(ctx);
              },
              child: const Text('Reactivate'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate Member'),
        content: Text('Reactivate $name? They will rejoin the group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveGuest(BuildContext context, WidgetRef ref, String name,
      VoidCallback onConfirm) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Remove Guest'),
          content: Text('Permanently remove guest $name?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                onConfirm();
                Navigator.pop(ctx);
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Guest'),
        content: Text('Permanently remove guest $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ── Action Button ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final dynamic member;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;
  final VoidCallback onRemoveGuest;

  const _ActionButton({
    required this.member,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onRemoveGuest,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (member.isDeactivated) {
      return TextButton(
        onPressed: onReactivate,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF4CAF50),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('Reactivate', style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    if (member.isGuest) {
      return TextButton(
        onPressed: onRemoveGuest,
        style: TextButton.styleFrom(
          foregroundColor: cs.error,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    return TextButton(
      onPressed: onDeactivate,
      style: TextButton.styleFrom(
        foregroundColor: cs.error,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: const Text('Deactivate', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// ── Pill Badge ─────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: fg,
            ),
      ),
    );
  }
}
