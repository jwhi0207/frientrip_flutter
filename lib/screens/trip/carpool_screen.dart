import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/ride.dart';
import '../../models/ride_request.dart';
import '../../models/trip_member.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/pickers.dart';
const _vehicleEmojis = ['🚗', '🚐', '🛻', '🚌', '🏎️', '🚙'];

class CarpoolScreen extends ConsumerStatefulWidget {
  final String tripId;
  const CarpoolScreen({super.key, required this.tripId});

  @override
  ConsumerState<CarpoolScreen> createState() => _CarpoolScreenState();
}

class _CarpoolScreenState extends ConsumerState<CarpoolScreen> {
  void _showAddSheet({Ride? editing}) {
    final trip = ref.read(tripStreamProvider(widget.tripId)).valueOrNull;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddVehicleSheet(
        initialRide: editing,
        defaultDepartureMillis: trip?.checkInMillis ?? 0,
        defaultReturnMillis: trip?.checkOutMillis ?? 0,
        onConfirm: (emoji, label, location, seats, depTime, retTime, notes) {
          final repo = ref.read(tripRepositoryProvider);
          if (editing != null) {
            repo.updateRide(
              widget.tripId,
              editing.id,
              vehicleEmoji: emoji,
              vehicleLabel: label,
              departureLocation: location,
              totalSeats: seats,
              departureTime: depTime,
              returnTime: retTime,
              notes: notes,
            );
          } else {
            final members =
                ref.read(tripMembersProvider(widget.tripId)).valueOrNull ?? [];
            final uid = ref.read(currentUidProvider) ?? '';
            final driverName =
                members.where((m) => m.uid == uid).firstOrNull?.displayName ??
                    '';
            repo.addRide(
              widget.tripId,
              driverUid: uid,
              driverName: driverName,
              vehicleEmoji: emoji,
              vehicleLabel: label,
              departureLocation: location,
              totalSeats: seats,
              departureTime: depTime,
              returnTime: retTime,
              notes: notes,
            );
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(Ride ride) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Remove Ride'),
          content: Text('Remove ${ride.driverName}\'s ${ride.vehicleLabel}?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                ref.read(tripRepositoryProvider).deleteRide(widget.tripId, ride.id);
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
        title: const Text('Remove Ride'),
        content: Text('Remove ${ride.driverName}\'s ${ride.vehicleLabel}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(tripRepositoryProvider).deleteRide(widget.tripId, ride.id);
              Navigator.pop(ctx);
            },
            child: Text('Remove',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rides =
        ref.watch(tripRidesProvider(widget.tripId)).valueOrNull ?? [];
    final requests =
        ref.watch(tripRideRequestsProvider(widget.tripId)).valueOrNull ?? [];
    final members =
        ref.watch(tripMembersProvider(widget.tripId)).valueOrNull ?? [];
    final uid = ref.watch(currentUidProvider);
    final ownerId =
        ref.watch(tripStreamProvider(widget.tripId)).valueOrNull?.ownerId;

    final hasMyRequest = requests.any((r) => r.uid == uid);
    final alreadyOfferedRide = rides.any((r) => r.driverUid == uid);

    return Scaffold(
      floatingActionButton: alreadyOfferedRide
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddSheet(),
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        children: [
          // ── Vehicles header ──────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Vehicles',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (rides.isNotEmpty)
                  _PillBadge(
                    '${rides.length} Active ${rides.length == 1 ? 'Ride' : 'Rides'}',
                  ),
              ],
            ),
          ),

          // ── Rides ────────────────────────────────────────────────────
          if (rides.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Text('🚗',
                      style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(
                    'No rides yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  Text(
                    'Tap + to offer a ride',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  ),
                ],
              ),
            )
          else
            for (final ride in rides)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: _RideCard(
                  ride: ride,
                  members: members,
                  currentUid: uid,
                  canEdit: uid == ride.driverUid || uid == ownerId,
                  onClaim: () {
                    final displayName = members
                            .where((m) => m.uid == uid)
                            .firstOrNull
                            ?.displayName ??
                        '';
                    ref.read(tripRepositoryProvider).claimSeat(
                          widget.tripId,
                          ride.id,
                          uid ?? '',
                          displayName,
                        );
                  },
                  onUnclaim: () {
                    final displayName = members
                            .where((m) => m.uid == uid)
                            .firstOrNull
                            ?.displayName ??
                        '';
                    ref.read(tripRepositoryProvider).unclaimSeat(
                          widget.tripId,
                          ride.id,
                          uid ?? '',
                          displayName,
                        );
                  },
                  onEdit: () => _showAddSheet(editing: ride),
                  onDelete: () => _confirmDelete(ride),
                ),
              ),

          // ── Need a Ride header ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  'Need a Ride',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final repo = ref.read(tripRepositoryProvider);
                    if (hasMyRequest) {
                      repo.cancelRideRequest(
                          widget.tripId, uid ?? '');
                    } else {
                      final displayName = members
                              .where((m) => m.uid == uid)
                              .firstOrNull
                              ?.displayName ??
                          '';
                      repo.addRideRequest(
                          widget.tripId, uid ?? '', displayName);
                    }
                  },
                  icon: Icon(
                    hasMyRequest ? Icons.cancel : Icons.add_circle,
                    size: 16,
                  ),
                  label: Text(
                    hasMyRequest ? 'Cancel Request' : 'I Need a Ride',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),

          // ── Ride requests ────────────────────────────────────────────
          if (requests.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Nobody needs a ride yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                    ),
              ),
            )
          else
            for (final request in requests)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 3),
                child: _RideRequestRow(
                    request: request, members: members),
              ),
        ],
      ),
    );
  }
}

// ── Ride Card ──────────────────────────────────────────────────────────────

class _RideCard extends StatelessWidget {
  final Ride ride;
  final List<TripMember> members;
  final String? currentUid;
  final bool canEdit;
  final VoidCallback onClaim;
  final VoidCallback onUnclaim;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RideCard({
    required this.ride,
    required this.members,
    required this.currentUid,
    required this.canEdit,
    required this.onClaim,
    required this.onUnclaim,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPassenger = ride.passengerUids.contains(currentUid);
    final isDriver = currentUid == ride.driverUid;
    final fmt = DateFormat('MMM d, h:mm a');
    final fraction = ride.totalSeats > 0
        ? ride.passengerUids.length / ride.totalSeats
        : 0.0;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(ride.vehicleEmoji,
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ride.driverName} – ${ride.vehicleLabel}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ride.notes.isNotEmpty)
                        Text(
                          ride.notes,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (canEdit)
                  _RideMenu(onEdit: onEdit, onDelete: onDelete),
              ],
            ),

            const SizedBox(height: 12),

            // ── Departure / Return ───────────────────────────────────
            if (ride.departureLocation.isNotEmpty ||
                ride.departureTime > 0) ...[
              _RideInfoRow(
                icon: Icons.trip_origin,
                label: 'DEPARTURE',
                value: [
                  if (ride.departureLocation.isNotEmpty)
                    ride.departureLocation,
                  if (ride.departureTime > 0)
                    fmt.format(
                        DateTime.fromMillisecondsSinceEpoch(
                            ride.departureTime)),
                ].join(' • '),
              ),
            ],
            if (ride.returnTime > 0) ...[
              const SizedBox(height: 6),
              _RideInfoRow(
                icon: Icons.keyboard_return,
                label: 'RETURN',
                value: fmt.format(
                    DateTime.fromMillisecondsSinceEpoch(ride.returnTime)),
              ),
            ],

            const SizedBox(height: 12),

            // ── Seat progress ────────────────────────────────────────
            Row(
              children: [
                Text(
                  'Seat Availability',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (ride.isFull)
                  Text(
                    'FULL',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                  )
                else
                  Text(
                    '${ride.passengerUids.length} / ${ride.totalSeats} Occupied',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.primary,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                color: ride.isFull
                    ? const Color(0xFF2E7D32)
                    : cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            if (!ride.isFull)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${ride.availableSeats} ${ride.availableSeats == 1 ? 'seat' : 'seats'} remaining',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                ),
              ),

            // ── Passengers ───────────────────────────────────────────
            if (ride.passengerUids.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'PASSENGERS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
              ),
              const SizedBox(height: 6),
              _StackedAvatars(
                  passengerUids: ride.passengerUids, members: members),
            ],

            const SizedBox(height: 12),

            // ── Action button ────────────────────────────────────────
            if (!isDriver)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: isPassenger
                    ? OutlinedButton(
                        onPressed: onUnclaim,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Leave Ride',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                      )
                    : FilledButton(
                        onPressed: ride.isFull ? null : onClaim,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          ride.isFull ? 'Full' : 'Claim Seat',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RideMenu extends StatefulWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RideMenu({required this.onEdit, required this.onDelete});

  @override
  State<_RideMenu> createState() => _RideMenuState();
}

class _RideMenuState extends State<_RideMenu> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5)),
        iconSize: 20,
        onSelected: (v) {
          if (v == 'edit') widget.onEdit();
          if (v == 'delete') widget.onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Edit Ride'),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete,
                  size: 18,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              const Text('Remove Ride'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _RideInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _RideInfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: cs.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
              ),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StackedAvatars extends StatelessWidget {
  final List<String> passengerUids;
  final List<TripMember> members;
  const _StackedAvatars(
      {required this.passengerUids, required this.members});

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    const overlap = 8.0;
    final passengers = passengerUids
        .map((uid) => members.where((m) => m.uid == uid).firstOrNull)
        .whereType<TripMember>()
        .take(5)
        .toList();

    if (passengers.isEmpty) return const SizedBox.shrink();

    final totalWidth =
        size + (passengers.length - 1) * (size - overlap);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < passengers.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: CircleAvatar(
                radius: size / 2,
                backgroundImage: NetworkImage(
                  'https://api.dicebear.com/9.x/pixel-art/png'
                  '?seed=${passengers[i].avatarSeed}&size=128',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Ride Request Row ───────────────────────────────────────────────────────

class _RideRequestRow extends StatelessWidget {
  final RideRequest request;
  final List<TripMember> members;
  const _RideRequestRow(
      {required this.request, required this.members});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final member =
        members.where((m) => m.uid == request.uid).firstOrNull;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: member != null
                  ? NetworkImage(
                      'https://api.dicebear.com/9.x/pixel-art/png'
                      '?seed=${member.avatarSeed}&size=128',
                    )
                  : null,
              child: member == null
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (request.notes.isNotEmpty)
                    Text(
                      request.notes,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pill Badge ─────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String label;
  const _PillBadge(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
      ),
    );
  }
}

// ── Add Vehicle Sheet ──────────────────────────────────────────────────────

class _AddVehicleSheet extends StatefulWidget {
  final Ride? initialRide;
  final int defaultDepartureMillis;
  final int defaultReturnMillis;
  final void Function(
    String emoji,
    String label,
    String location,
    int seats,
    int depTime,
    int retTime,
    String notes,
  ) onConfirm;

  const _AddVehicleSheet({
    this.initialRide,
    required this.defaultDepartureMillis,
    required this.defaultReturnMillis,
    required this.onConfirm,
  });

  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  late String _emoji;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;
  late int _seats;
  late int _depMillis;
  late int _retMillis;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRide;
    _emoji = r?.vehicleEmoji ?? '🚗';
    _labelCtrl = TextEditingController(text: r?.vehicleLabel ?? '');
    _locationCtrl =
        TextEditingController(text: r?.departureLocation ?? '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _seats = r?.totalSeats ?? 4;
    _depMillis =
        r?.departureTime ?? widget.defaultDepartureMillis;
    _retMillis = r?.returnTime ?? widget.defaultReturnMillis;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(int millis) =>
      millis > 0 ? DateFormat('MM/dd/yyyy').format(
          DateTime.fromMillisecondsSinceEpoch(millis)) : '';

  String _fmtTime(int millis) =>
      millis > 0 ? DateFormat('h:mm a').format(
          DateTime.fromMillisecondsSinceEpoch(millis)) : '';

  int _mergeDate(int dateMillis, int existing) {
    final d = DateTime.fromMillisecondsSinceEpoch(dateMillis);
    final e = existing > 0
        ? DateTime.fromMillisecondsSinceEpoch(existing)
        : d;
    return DateTime(d.year, d.month, d.day, e.hour, e.minute)
        .millisecondsSinceEpoch;
  }

  int _mergeTime(int existing, int hour, int minute) {
    final base = existing > 0
        ? DateTime.fromMillisecondsSinceEpoch(existing)
        : DateTime.now();
    return DateTime(base.year, base.month, base.day, hour, minute)
        .millisecondsSinceEpoch;
  }

  Future<void> _pickDepDate() async {
    final picked = await showPlatformDatePicker(
      context: context,
      initialDate: _depMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(_depMillis)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _depMillis =
          _mergeDate(picked.millisecondsSinceEpoch, _depMillis));
    }
  }

  Future<void> _pickDepTime() async {
    final initial = _depMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(_depMillis)
        : DateTime.now();
    final picked = await showPlatformTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (picked != null && mounted) {
      setState(() => _depMillis =
          _mergeTime(_depMillis, picked.hour, picked.minute));
    }
  }

  Future<void> _pickRetDate() async {
    final picked = await showPlatformDatePicker(
      context: context,
      initialDate: _retMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(_retMillis)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _retMillis =
          _mergeDate(picked.millisecondsSinceEpoch, _retMillis));
    }
  }

  Future<void> _pickRetTime() async {
    final initial = _retMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(_retMillis)
        : DateTime.now();
    final picked = await showPlatformTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (picked != null && mounted) {
      setState(() => _retMillis =
          _mergeTime(_retMillis, picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.initialRide != null;
    final canConfirm = _labelCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Edit Ride' : 'Offer a Ride',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ── Emoji picker ─────────────────────────────────────
            Text('Vehicle',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final e in _vehicleEmojis) ...[
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _emoji == e
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: _emoji == e
                            ? Border.all(
                                color: cs.primary, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(e,
                            style:
                                const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Vehicle label ────────────────────────────────────
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Vehicle description',
                hintText: 'e.g. Black Pickup Truck',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // ── Departure location ───────────────────────────────
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Departure location',
                hintText: 'e.g. Downtown Terminal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Seats stepper ────────────────────────────────────
            Text('Total Seats',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove,
                  onPressed: _seats > 1
                      ? () => setState(() => _seats--)
                      : null,
                ),
                const SizedBox(width: 16),
                Text(
                  '$_seats',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                _StepButton(
                  icon: Icons.add,
                  onPressed: _seats < 12
                      ? () => setState(() => _seats++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Departure date + time ────────────────────────────
            Text('Departure',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                    child: _DateTimeField(
                        value: _fmtDate(_depMillis),
                        hint: 'Date',
                        icon: Icons.calendar_month,
                        onTap: _pickDepDate)),
                const SizedBox(width: 8),
                Expanded(
                    child: _DateTimeField(
                        value: _fmtTime(_depMillis),
                        hint: 'Time',
                        icon: Icons.schedule,
                        onTap: _pickDepTime)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Return date + time ───────────────────────────────
            Text('Return',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                    child: _DateTimeField(
                        value: _fmtDate(_retMillis),
                        hint: 'Date',
                        icon: Icons.calendar_month,
                        onTap: _pickRetDate)),
                const SizedBox(width: 8),
                Expanded(
                    child: _DateTimeField(
                        value: _fmtTime(_retMillis),
                        hint: 'Time',
                        icon: Icons.schedule,
                        onTap: _pickRetTime)),
              ],
            ),
            const SizedBox(height: 12),

            // ── Notes ────────────────────────────────────────────
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Roof rack for boards/skis',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Buttons ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canConfirm
                        ? () => widget.onConfirm(
                              _emoji,
                              _labelCtrl.text.trim(),
                              _locationCtrl.text.trim(),
                              _seats,
                              _depMillis,
                              _retMillis,
                              _notesCtrl.text.trim(),
                            )
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(isEdit ? 'Save' : 'Add Ride'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _StepButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Icon(icon, size: 18,
              color: onPressed == null
                  ? Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)
                  : null),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  const _DateTimeField(
      {required this.value,
      required this.hint,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(icon, size: 18),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          value.isEmpty ? '' : value,
          style: value.isEmpty
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
