import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/members_provider.dart' hide tripMembersProvider;
import '../../providers/trip_provider.dart';
import '../../widgets/avatar_widget.dart';
import 'dashboard_screen.dart' show RenameTripDialog;

class TripShell extends ConsumerWidget {
  final Widget child;
  const TripShell({super.key, required this.child});

  String _tripId(BuildContext context) {
    final segments = GoRouterState.of(context).uri.pathSegments;
    // /trips/<tripId>/dashboard → segments[1]
    return segments.length >= 2 ? segments[1] : '';
  }

  int _activeTab(String path) {
    if (path.contains('/lodging')) return 1;
    if (path.contains('/supplies')) return 2;
    if (path.contains('/carpool')) return 3;
    if (path.contains('/messages')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripId = _tripId(context);
    final path = GoRouterState.of(context).uri.path;
    final tripAsync = ref.watch(tripStreamProvider(tripId));
    final tripName = tripAsync.valueOrNull?.name ?? '';
    final uid = ref.watch(currentUidProvider);
    final isAdmin = tripAsync.valueOrNull?.ownerId == uid;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(tripName.isEmpty ? 'Trip' : tripName),
        actions: [
          if (_activeTab(path) == 0 && isAdmin)
            IconButton(
              icon: Icon(Icons.edit,
                  size: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55)),
              tooltip: 'Rename trip',
              onPressed: () => showDialog(
                context: context,
                builder: (_) =>
                    RenameTripDialog(tripId: tripId, currentName: tripName),
              ),
            ),
          if (_activeTab(path) == 4)
            _MuteButton(tripId: tripId),
        ],
      ),
      drawer: _TripDrawer(tripId: tripId, isAdmin: isAdmin),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _activeTab(path),
        onDestinationSelected: (i) {
          const tabs = ['dashboard', 'lodging', 'supplies', 'carpool', 'messages'];
          context.go('/trips/$tripId/${tabs[i]}');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.hotel_outlined),
            selectedIcon: Icon(Icons.hotel),
            label: 'Lodging',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Supplies',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Carpool',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
        ],
      ),
    );
  }
}

class _MuteButton extends ConsumerWidget {
  final String tripId;
  const _MuteButton({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const SizedBox.shrink();

    final member = ref.watch(currentUserMemberProvider(tripId));
    final isMuted = member?.mutedMessages ?? false;

    return IconButton(
      icon: Icon(isMuted ? Icons.notifications_off : Icons.notifications_active),
      tooltip: isMuted ? 'Unmute notifications' : 'Mute notifications',
      onPressed: () {
        ref.read(tripRepositoryProvider).toggleMuteMessages(tripId, uid, !isMuted);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMuted
                ? 'Notifications unmuted for this trip'
                : 'Notifications muted for this trip'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

class _TripDrawer extends ConsumerWidget {
  final String tripId;
  final bool isAdmin;
  const _TripDrawer({required this.tripId, required this.isAdmin});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete,
            color: Theme.of(ctx).colorScheme.error),
        title: const Text('Delete Trip?'),
        content: const Text(
            'This will permanently delete this trip and all its data for everyone. This cannot be undone.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(tripRepositoryProvider)
                  .deleteTrip(tripId);
              if (context.mounted) context.go('/trips');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final uid = ref.watch(currentUidProvider);
    final trip = ref.watch(tripStreamProvider(tripId)).valueOrNull;
    final members =
        ref.watch(tripMembersProvider(tripId)).valueOrNull ?? [];
    final currentMember =
        members.where((m) => m.uid == uid).firstOrNull;

    void nav(void Function() go) {
      Navigator.of(context).pop();
      go();
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => nav(() => context.push('/profile')),
                    child: currentMember != null
                        ? AvatarWidget(
                            seed: currentMember.avatarSeed,
                            colorIndex: currentMember.avatarColor,
                            size: 56,
                          )
                        : CircleAvatar(
                            radius: 28,
                            backgroundColor: cs.primaryContainer,
                            child: Icon(Icons.person,
                                color: cs.onPrimaryContainer, size: 28),
                          ),
                  ),
                  if (currentMember != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      currentMember.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (trip?.name != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      trip!.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 24),

            // ── Navigation items ──────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Change Trips'),
              onTap: () => nav(() => context.go('/trips')),
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('Trip Announcements'),
              onTap: () => Navigator.of(context).pop(),
            ),
            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Manage Group'),
                onTap: () =>
                    nav(() => context.push('/trips/$tripId/manage')),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Trip History'),
                onTap: () =>
                    nav(() => context.push('/trips/$tripId/history')),
              ),
            ],

            // ── Bottom section ────────────────────────────────────────
            const Spacer(),
            const Divider(),
            if (isAdmin)
              ListTile(
                leading: Icon(Icons.delete, color: cs.error),
                title: Text('Delete Trip',
                    style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmDelete(context, ref);
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.of(context).pop();
                FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
