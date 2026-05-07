import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';

class GroupScreen extends ConsumerStatefulWidget {
  final String tripId;
  const GroupScreen({super.key, required this.tripId});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  void _copyInviteCode(BuildContext context, String code, String tripName) {
    Clipboard.setData(ClipboardData(
      text: 'Join my trip "$tripName" on Frientrip! Use invite code: $code',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite text copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip =
        ref.watch(tripStreamProvider(widget.tripId)).valueOrNull;
    final allMembers =
        ref.watch(tripMembersProvider(widget.tripId)).valueOrNull ?? [];
    final uid = ref.watch(currentUidProvider);

    final isAdmin = uid == trip?.ownerId;
    final members = allMembers.where((m) => !m.isDeactivated).toList();
    final pendingEmails = trip?.pendingInviteEmails ?? [];
    final inviteCode = trip?.inviteCode;
    final inviteCodeEnabled = trip?.inviteCodeEnabled ?? true;
    final ownerId = trip?.ownerId ?? '';

    final cs = Theme.of(context).colorScheme;
    final trimmedEmail = _emailCtrl.text.trim();
    final isValidEmail = _isValidEmail(trimmedEmail);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        // ── Invite Code (visible when enabled) ──────────────────────
        if (inviteCode != null && inviteCodeEnabled)
          _SectionCard(
            child: Column(
              children: [
                Text(
                  'INVITE CODE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  inviteCode,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _copyInviteCode(context, inviteCode, trip?.name ?? ''),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share Invite Code',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Admin: invite code controls ──────────────────────────────
        if (isAdmin)
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminLabel(),
                Row(
                  children: [
                    Expanded(
                      child: Text('Invite Code Enabled',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Switch(
                      value: inviteCodeEnabled,
                      onChanged: (v) => ref
                          .read(tripRepositoryProvider)
                          .toggleInviteCode(widget.tripId, v),
                    ),
                  ],
                ),
                if (inviteCodeEnabled) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(tripRepositoryProvider)
                          .regenerateInviteCode(widget.tripId),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Regenerate Code'),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // ── Admin: email invite ──────────────────────────────────────
        if (isAdmin)
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminLabel(),
                Text(
                  'Invite by Email',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'friend@example.com',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isValidEmail
                        ? () {
                            ref
                                .read(tripRepositoryProvider)
                                .addPendingInvite(
                                    widget.tripId, trimmedEmail);
                            _emailCtrl.clear();
                            setState(() {});
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Invite',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

        // ── Pending Invites ──────────────────────────────────────────
        if (isAdmin && pendingEmails.isNotEmpty) ...[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Text(
              'PENDING INVITES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ),
          for (final email in pendingEmails)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                        child: Text(
                          email,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => ref
                          .read(tripRepositoryProvider)
                          .removePendingInvite(widget.tripId, email),
                      icon: Icon(Icons.cancel,
                          size: 20,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],

        // ── Divider ──────────────────────────────────────────────────
        if (isAdmin)
          Divider(
            indent: 16,
            endIndent: 16,
            color: cs.outlineVariant,
          ),

        // ── Current Members ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
          child: Text(
            'CURRENT MEMBERS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
          ),
        ),

        for (final member in members)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(
                    'https://api.dicebear.com/9.x/pixel-art/png'
                    '?seed=${member.avatarSeed}&size=128',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
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
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (member.uid == ownerId) ...[
                            const SizedBox(width: 8),
                            _OwnerBadge(),
                          ],
                          if (member.isGuest) ...[
                            const SizedBox(width: 8),
                            _GuestBadge(),
                          ],
                        ],
                      ),
                      if (member.email.isNotEmpty)
                        Text(
                          member.email,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _AdminLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'ADMIN ONLY',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'OWNER',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: cs.primary,
            ),
      ),
    );
  }
}

class _GuestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'GUEST',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: cs.secondary,
            ),
      ),
    );
  }
}
