import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/user_provider.dart';
import 'create_trip_sheet.dart';
import 'join_trip_dialog.dart';
import '../../widgets/vivid_card.dart';

enum _TripFilter { upcoming, past }

class TripListScreen extends ConsumerStatefulWidget {
  const TripListScreen({super.key});

  @override
  ConsumerState<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends ConsumerState<TripListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, bool> _acceptingInvite = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const CreateTripSheet(),
      );

  void _showJoinDialog() => showDialog(
        context: context,
        builder: (_) => const JoinTripDialog(),
      );

  Future<void> _acceptInvite(String tripId) async {
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (uid == null || profile == null) return;

    setState(() => _acceptingInvite[tripId] = true);
    try {
      await ref.read(tripRepositoryProvider).acceptSingleInvite(
            tripId,
            uid,
            profile.email,
            profile.displayName,
            profile.avatarSeed,
            profile.avatarColor,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      }
    } finally {
      if (mounted) setState(() => _acceptingInvite.remove(tripId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(userTripsProvider);
    final inviteTripsAsync = ref.watch(pendingInviteTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'Invites'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Join with code',
            onPressed: _showJoinDialog,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTripList(tripsAsync, _TripFilter.upcoming),
          _buildTripList(tripsAsync, _TripFilter.past),
          _buildInviteList(inviteTripsAsync),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTripList(
      AsyncValue<List<Trip>> tripsAsync, _TripFilter filter) {
    return tripsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorView('Error loading trips: $e'),
      data: (trips) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final filtered = trips
            .where((t) => filter == _TripFilter.upcoming
                ? t.checkOutMillis <= 0 || t.checkOutMillis >= now
                : t.checkOutMillis > 0 && t.checkOutMillis < now)
            .toList()
          ..sort((a, b) {
            final aIn = a.checkInMillis == 0
                ? double.maxFinite.toInt()
                : a.checkInMillis;
            final bIn = b.checkInMillis == 0
                ? double.maxFinite.toInt()
                : b.checkInMillis;
            if (aIn != bIn) return aIn.compareTo(bIn);
            return a.name.compareTo(b.name);
          });

        if (filtered.isEmpty) {
          return _emptyView(filter == _TripFilter.upcoming
              ? 'No upcoming trips\nTap + to create one'
              : 'No past trips yet');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: filtered.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TripCard(trip: filtered[i], accentIndex: i),
          ),
        );
      },
    );
  }

  Widget _buildInviteList(AsyncValue<List<Trip>> inviteTripsAsync) {
    return inviteTripsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorView('Error: $e'),
      data: (trips) {
        final uid = ref.read(currentUidProvider);
        final pending =
            trips.where((t) => !t.memberIds.contains(uid)).toList();
        if (pending.isEmpty) {
          return _emptyView('No pending invitations');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: pending.length,
          itemBuilder: (_, i) {
            final trip = pending[i];
            final loading = _acceptingInvite[trip.id] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InviteCard(
                trip: trip,
                loading: loading,
                accentIndex: i,
                onAccept: loading ? null : () => _acceptInvite(trip.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyView(String message) => Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
          textAlign: TextAlign.center,
        ),
      );

  Widget _errorView(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}

// ---------------------------------------------------------------------------
// Trip Card
// ---------------------------------------------------------------------------

class _TripCard extends StatelessWidget {
  final Trip trip;
  final int accentIndex;
  const _TripCard({required this.trip, required this.accentIndex});

  String _dateRange() {
    if (trip.checkInMillis == 0) return 'Dates TBD';
    final fmt = DateFormat('MMM d');
    final checkIn =
        DateTime.fromMillisecondsSinceEpoch(trip.checkInMillis);
    if (trip.checkOutMillis == 0) return fmt.format(checkIn);
    final checkOut =
        DateTime.fromMillisecondsSinceEpoch(trip.checkOutMillis);
    return '${fmt.format(checkIn)} – ${DateFormat('MMM d, y').format(checkOut)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasThumb =
        trip.thumbnailURL != null && trip.thumbnailURL!.isNotEmpty;
    final costStr = trip.totalCost > 0
        ? NumberFormat.currency(symbol: '\$', decimalDigits: 2)
            .format(trip.totalCost)
        : '';

    return VividCard(
      accentIndex: accentIndex,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      onTap: () => context.go('/trips/${trip.id}/dashboard'),
      child: SizedBox(
        height: 180,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            if (hasThumb)
              CachedNetworkImage(
                imageUrl: trip.thumbnailURL!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _gradient(theme),
              )
            else
              _gradient(theme),
            // Bottom scrim
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
            // Emoji
            if (trip.emoji.isNotEmpty)
              Positioned(
                top: 10,
                left: 12,
                child:
                    Text(trip.emoji, style: const TextStyle(fontSize: 26)),
              ),
            // Cost badge
            if (costStr.isNotEmpty)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    costStr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            // Bottom info
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black54)
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(Icons.calendar_month, _dateRange()),
                      const SizedBox(width: 8),
                      _chip(Icons.group,
                          '${trip.memberIds.length}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradient(ThemeData theme) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  Widget _chip(IconData icon, String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Invite Card
// ---------------------------------------------------------------------------

class _InviteCard extends StatelessWidget {
  final Trip trip;
  final bool loading;
  final int accentIndex;
  final VoidCallback? onAccept;

  const _InviteCard(
      {required this.trip, required this.loading, required this.accentIndex, this.onAccept});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = trip.memberIds.length;

    return VividCard(
      accentIndex: accentIndex,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: trip.emoji.isNotEmpty
                  ? Text(trip.emoji,
                      style: const TextStyle(fontSize: 22))
                  : Text(
                      trip.name.isNotEmpty
                          ? trip.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              theme.colorScheme.onPrimaryContainer),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'member' : 'members'}',
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : FilledButton.tonal(
                    onPressed: onAccept,
                    child: const Text('Join'),
                  ),
          ],
        ),
      ),
    );
  }
}
