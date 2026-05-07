import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/trip_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/cost_calculator.dart';
import '../../widgets/avatar_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String tripId;
  const DashboardScreen({super.key, required this.tripId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  void _showEditNights(TripMember member, int maxNights) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => EditNightsSheet(
            tripId: widget.tripId, member: member, maxNights: maxNights),
      );

  void _showAddPayment(
      TripMember member, double owed, double houseShare, double expShare) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddPaymentSheet(
          tripId: widget.tripId,
          member: member,
          computedOwed: owed,
          houseShare: houseShare,
          expensesShare: expShare,
        ),
      );

  void _showPayExpenses(TripMember member, double amountDue) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => PayExpensesSheet(
            tripId: widget.tripId, member: member, amountDue: amountDue),
      );

  void _showVerifyPayment(TripMember member) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            VerifyPaymentSheet(tripId: widget.tripId, member: member),
      );

  void _showRenameDialog(String currentName) => showDialog(
        context: context,
        builder: (_) =>
            RenameTripDialog(tripId: widget.tripId, currentName: currentName),
      );

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));
    final membersAsync = ref.watch(tripMembersProvider(widget.tripId));
    final suppliesAsync = ref.watch(tripSuppliesProvider(widget.tripId));
    final ridesAsync = ref.watch(tripRidesProvider(widget.tripId));
    final rideRequestsAsync = ref.watch(tripRideRequestsProvider(widget.tripId));
    final expensesAsync = ref.watch(tripExpensesProvider(widget.tripId));
    final uid = ref.watch(currentUidProvider);

    final trip = tripAsync.valueOrNull;
    final members = membersAsync.valueOrNull ?? [];
    final supplies = suppliesAsync.valueOrNull ?? [];
    final rides = ridesAsync.valueOrNull ?? [];
    final rideRequests = rideRequestsAsync.valueOrNull ?? [];
    final expenses = expensesAsync.valueOrNull ?? [];

    final activeMembers = members.where((m) => !m.isDeactivated).toList();
    final isAdmin = trip?.ownerId == uid;
    final memberCosts = trip != null
        ? CostCalculator.computeMemberCosts(trip, activeMembers, expenses)
        : <String, double>{};
    final houseCosts = trip != null
        ? CostCalculator.computeHouseCosts(trip, activeMembers)
        : <String, double>{};

    final unclaimed = supplies.where((s) => !s.isClaimed).length;
    final availRides = rides.fold(0, (sum, r) => sum + r.availableSeats);
    final pendingExpenseCount = expenses.where((e) => !e.approved).length;
    final approvedTotal = expenses.where((e) => e.approved).fold(0.0, (sum, e) => sum + e.amount);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Scaffold(
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            // ── Hero card ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HeroCard(
                trip: trip,
                guestCount: activeMembers.length,
                onTap: () => context.push('/trips/${widget.tripId}/lodging'),
              ),
            ),
            const SizedBox(height: 16),

            // ── Feature cards ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.shopping_bag_outlined,
                          badge: unclaimed > 0 ? '$unclaimed New' : null,
                          title: 'Supplies',
                          subtitle: supplies.isEmpty
                              ? 'No items yet'
                              : '${supplies.length} items total',
                          accentColor: Theme.of(context).colorScheme.tertiary,
                          onTap: () =>
                              context.go('/trips/${widget.tripId}/supplies'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.directions_car_outlined,
                          badge: rideRequests.isNotEmpty
                              ? '${rideRequests.length} Need Ride'
                              : availRides > 0
                                  ? '$availRides Avail'
                                  : null,
                          badgeIsWarning: rideRequests.isNotEmpty,
                          title: 'Carpool',
                          subtitle:
                              rides.isEmpty ? 'No rides yet' : 'Rides active',
                          accentColor: Theme.of(context).colorScheme.secondary,
                          onTap: () =>
                              context.go('/trips/${widget.tripId}/carpool'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Expenses full-width card
                  Card(
                    elevation: 1,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          context.push('/trips/${widget.tripId}/expenses'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.account_balance_wallet_outlined,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Expenses',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  if (isAdmin && pendingExpenseCount > 0)
                                    _StatusChip(
                                        label:
                                            '$pendingExpenseCount Pending',
                                        color: Colors.orange.shade700,
                                        bg: Colors.orange.shade50)
                                  else
                                    Text(
                                      expenses.isEmpty
                                          ? 'No expenses yet'
                                          : '${expenses.length} expenses',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6)),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              currency.format(approvedTotal),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Group Members header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Group Members',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (isAdmin) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.edit,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45)),
                      tooltip: 'Rename trip',
                      onPressed: () =>
                          _showRenameDialog(trip?.name ?? ''),
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        context.go('/trips/${widget.tripId}/group'),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),

            // ── Member list ────────────────────────────────────────────────
            if (activeMembers.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Text(
                  isAdmin
                      ? 'Nobody here yet\nTap the person icon to invite friends'
                      : 'Nobody here yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 1,
                  child: Column(
                    children: [
                      for (int i = 0; i < activeMembers.length; i++) ...[
                        _MemberRow(
                          member: activeMembers[i],
                          computedOwed:
                              memberCosts[activeMembers[i].uid] ?? 0.0,
                          isAdmin: isAdmin,
                          isCurrentUser: activeMembers[i].uid == uid,
                          onEditNights: () => _showEditNights(
                              activeMembers[i], trip?.totalNights ?? 0),
                          onAddPayment: () {
                            final m = activeMembers[i];
                            final owed = memberCosts[m.uid] ?? 0.0;
                            final house = houseCosts[m.uid] ?? 0.0;
                            _showAddPayment(m, owed, house, owed - house);
                          },
                          onPayExpenses: () {
                            final m = activeMembers[i];
                            final owed = memberCosts[m.uid] ?? 0.0;
                            final remaining = owed - m.amountPaid;
                            _showPayExpenses(m, remaining > 0 ? remaining : 0.0);
                          },
                          onVerifyPayment: () =>
                              _showVerifyPayment(activeMembers[i]),
                        ),
                        if (i < activeMembers.length - 1)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final dynamic trip;
  final int guestCount;
  final VoidCallback onTap;

  const _HeroCard(
      {required this.trip, required this.guestCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasThumb =
        trip?.thumbnailURL != null && (trip!.thumbnailURL as String).isNotEmpty;
    final address = trip?.address as String? ?? '';
    final totalCost = (trip?.totalCost as double?) ?? 0.0;
    final checkIn = (trip?.checkInMillis as int?) ?? 0;
    final checkOut = (trip?.checkOutMillis as int?) ?? 0;
    final houseURL = trip?.houseURL as String? ?? '';
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final fmt = DateFormat('MMM d');

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasThumb)
                    CachedNetworkImage(
                      imageUrl: trip!.thumbnailURL as String,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(context),
                    )
                  else
                    _placeholder(context),
                  // scrim
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
                  // cost badge
                  if (totalCost > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(totalCost),
                              style: const TextStyle(
                                color: Color(0xFF00F5FF),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Total Stay',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // bottom content
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          houseURL.isNotEmpty ? 'Lodging' : 'Add Lodging Details',
                          style: TextStyle(
                            color: houseURL.isNotEmpty
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (checkIn > 0 && checkOut > 0) ...[
                              _HeroChip(
                                icon: Icons.calendar_month,
                                label:
                                    '${fmt.format(DateTime.fromMillisecondsSinceEpoch(checkIn))} – ${fmt.format(DateTime.fromMillisecondsSinceEpoch(checkOut))}',
                              ),
                              const SizedBox(width: 8),
                            ],
                            _HeroChip(
                              icon: Icons.group,
                              label:
                                  '$guestCount ${guestCount == 1 ? 'Guest' : 'Guests'}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (address.isNotEmpty) ...[
              Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.4)),
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                padding: const EdgeInsets.only(
                    left: 14, right: 4, top: 6, bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            Clipboard.setData(ClipboardData(text: address)),
                        child: Text(
                          address,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.navigation,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18),
                      iconSize: 18,
                      onPressed: () => launchUrl(
                        Uri.parse(
                            'geo:0,0?q=${Uri.encodeComponent(address)}'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Feature card ──────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final bool badgeIsWarning;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    this.badge,
    this.badgeIsWarning = false,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        color: theme.colorScheme.primary, size: 20),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeIsWarning
                            ? Colors.orange.shade50
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeIsWarning
                              ? Colors.orange.shade700
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Member row ────────────────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  final TripMember member;
  final double computedOwed;
  final bool isAdmin;
  final bool isCurrentUser;
  final VoidCallback onEditNights;
  final VoidCallback onAddPayment;
  final VoidCallback onPayExpenses;
  final VoidCallback onVerifyPayment;

  const _MemberRow({
    required this.member,
    required this.computedOwed,
    required this.isAdmin,
    required this.isCurrentUser,
    required this.onEditNights,
    required this.onAddPayment,
    required this.onPayExpenses,
    required this.onVerifyPayment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = member;
    final remaining = computedOwed - m.amountPaid;
    final isPaidUp = remaining <= 0.0;
    final hasPending = m.pendingPaymentStatus == 'pending';
    final canEditNights = isCurrentUser || isAdmin;
    final canAddPayment = isAdmin;
    final canPayExpenses = isCurrentUser || isAdmin;
    final canVerifyPayment = isAdmin && hasPending;
    final hasMenu = canEditNights || canAddPayment || canPayExpenses || canVerifyPayment;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AvatarWidget(seed: m.avatarSeed, colorIndex: m.avatarColor, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.displayName,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.nightlight_round,
                        size: 13, color: const Color(0xFFB347EA)),
                    const SizedBox(width: 3),
                    Text(
                      m.nightsStayed == 0
                          ? 'Nights TBD'
                          : '${m.nightsStayed} ${m.nightsStayed == 1 ? 'night' : 'nights'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (computedOwed > 0 && m.nightsStayed > 0)
                isPaidUp
                    ? _StatusChip(
                        label: 'PAID UP',
                        color: Colors.green.shade700,
                        bg: Colors.green.shade50)
                    : _StatusChip(
                        label: '${currency.format(remaining)} DUE',
                        color: Colors.red.shade700,
                        bg: Colors.red.shade50),
              if (isAdmin && hasPending) ...[
                const SizedBox(height: 4),
                _StatusChip(
                    label: 'REVIEW',
                    color: Colors.orange.shade800,
                    bg: Colors.orange.shade50),
              ],
            ],
          ),
          if (hasMenu)
            PopupMenuButton<String>(
              iconSize: 18,
              icon: Icon(Icons.more_vert,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 18),
              onSelected: (value) {
                switch (value) {
                  case 'nights':
                    onEditNights();
                  case 'payment':
                    onAddPayment();
                  case 'pay':
                    onPayExpenses();
                  case 'verify':
                    onVerifyPayment();
                }
              },
              itemBuilder: (_) => [
                if (canEditNights)
                  const PopupMenuItem(
                      value: 'nights',
                      child: ListTile(
                          leading: Icon(Icons.nightlight_round),
                          title: Text('Edit Nights'),
                          dense: true,
                          contentPadding: EdgeInsets.zero)),
                if (canAddPayment)
                  const PopupMenuItem(
                      value: 'payment',
                      child: ListTile(
                          leading: Icon(Icons.attach_money),
                          title: Text('Add Payment'),
                          dense: true,
                          contentPadding: EdgeInsets.zero)),
                if (canPayExpenses)
                  const PopupMenuItem(
                      value: 'pay',
                      child: ListTile(
                          leading: Icon(Icons.payment),
                          title: Text('Pay Expenses'),
                          dense: true,
                          contentPadding: EdgeInsets.zero)),
                if (canVerifyPayment)
                  const PopupMenuItem(
                      value: 'verify',
                      child: ListTile(
                          leading: Icon(Icons.fact_check_outlined),
                          title: Text('Verify Payment'),
                          dense: true,
                          contentPadding: EdgeInsets.zero)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _StatusChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

// ── Edit Nights sheet ─────────────────────────────────────────────────────────

class EditNightsSheet extends ConsumerStatefulWidget {
  final String tripId;
  final TripMember member;
  final int maxNights;
  const EditNightsSheet(
      {super.key,
      required this.tripId,
      required this.member,
      required this.maxNights});

  @override
  ConsumerState<EditNightsSheet> createState() => _EditNightsSheetState();
}

class _EditNightsSheetState extends ConsumerState<EditNightsSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final n = widget.member.nightsStayed;
    _ctrl = TextEditingController(text: n > 0 ? '$n' : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int? get _parsed {
    final v = int.tryParse(_ctrl.text);
    if (v == null || v < 0) return null;
    if (widget.maxNights > 0 && v > widget.maxNights) return null;
    return v;
  }

  Future<void> _save() async {
    final nights = _parsed;
    if (nights == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tripRepositoryProvider)
          .updateMemberNights(widget.tripId, widget.member.uid, nights);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Edit Nights', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Nights',
              border: const OutlineInputBorder(),
              helperText: widget.maxNights > 0
                  ? 'Enter 0–${widget.maxNights} (trip is ${widget.maxNights} ${widget.maxNights == 1 ? 'night' : 'nights'} total)'
                  : 'Currently: ${widget.member.nightsStayed} nights',
              errorText: _ctrl.text.isNotEmpty && _parsed == null
                  ? 'Value out of range'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _parsed != null && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add Payment sheet ─────────────────────────────────────────────────────────

class AddPaymentSheet extends ConsumerStatefulWidget {
  final String tripId;
  final TripMember member;
  final double computedOwed;
  final double houseShare;
  final double expensesShare;
  const AddPaymentSheet({
    super.key,
    required this.tripId,
    required this.member,
    required this.computedOwed,
    required this.houseShare,
    required this.expensesShare,
  });

  @override
  ConsumerState<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<AddPaymentSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? get _parsed => double.tryParse(_ctrl.text.trim())?.let((v) => v > 0 ? v : null);

  Future<void> _save() async {
    final amount = _parsed;
    if (amount == null) return;
    setState(() => _saving = true);
    try {
      final adminProfile = ref.read(userProfileProvider).valueOrNull;
      await ref.read(tripRepositoryProvider).approvePayment(
            widget.tripId,
            widget.member.uid,
            amount,
            widget.member.displayName,
            adminProfile?.displayName ?? 'Admin',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final remaining = widget.computedOwed - widget.member.amountPaid;

    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Add Payment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                if (widget.houseShare > 0 || widget.expensesShare > 0) ...[
                  _SummaryRow('House share',
                      currency.format(widget.houseShare)),
                  _SummaryRow('Expenses share',
                      currency.format(widget.expensesShare)),
                  const Divider(height: 12),
                ],
                _SummaryRow('Total owed',
                    currency.format(widget.computedOwed)),
                _SummaryRow(
                    'Already paid', currency.format(widget.member.amountPaid)),
                const Divider(height: 12),
                _SummaryRow(
                  'Remaining',
                  remaining <= 0
                      ? 'Paid up ✓'
                      : currency.format(remaining),
                  valueColor: remaining <= 0
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Payment amount',
              prefixText: '\$',
              hintText: '0.00',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _parsed != null && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Record'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}

// ── Pay Expenses sheet ────────────────────────────────────────────────────────

class PayExpensesSheet extends ConsumerStatefulWidget {
  final String tripId;
  final TripMember member;
  final double amountDue;
  const PayExpensesSheet({
    super.key,
    required this.tripId,
    required this.member,
    required this.amountDue,
  });

  @override
  ConsumerState<PayExpensesSheet> createState() => _PayExpensesSheetState();
}

class _PayExpensesSheetState extends ConsumerState<PayExpensesSheet> {
  late final TextEditingController _ctrl;
  bool _copied = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.amountDue > 0
            ? widget.amountDue.toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? get _parsed {
    final v = double.tryParse(_ctrl.text.trim());
    return (v != null && v >= 0.01) ? v : null;
  }

  Future<void> _submit() async {
    final amount = _parsed;
    if (amount == null) return;
    final capped =
        amount > widget.amountDue && widget.amountDue > 0 ? widget.amountDue : amount;
    setState(() => _saving = true);
    try {
      await ref.read(tripRepositoryProvider).submitPayment(
            widget.tripId,
            widget.member.uid,
            capped,
            widget.member.displayName,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final isRejected = widget.member.pendingPaymentStatus == 'rejected';

    return SingleChildScrollView(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text('Pay Expenses',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          if (isRejected) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your last payment submission was rejected by the trip manager.',
                      style: TextStyle(
                          color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Amount due — tap to copy
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(
                  text: widget.amountDue.toStringAsFixed(2)));
              setState(() => _copied = true);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('Amount Due',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(widget.amountDue),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _copied ? 'Copied to clipboard ✓' : 'Tap to copy amount',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _parsed != null && !_saving ? _submit : null,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Pay with',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
          ),
          const SizedBox(height: 8),
          ...[
            [
              ('PayPal', const Color(0xFF003087),
                  'https://www.paypal.com/myaccount/transfer/homepage/pay'),
              ('Venmo', const Color(0xFF3D95CE), 'https://venmo.com/'),
            ],
            [
              ('Cash App', const Color(0xFF00C244), 'https://cash.app/'),
              ('Zelle', const Color(0xFF6D1ED4), 'https://www.zellepay.com/'),
            ],
            [
              ('GPay', Colors.black, 'https://pay.google.com/'),
            ],
          ].map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  for (final (label, color, url) in row) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: () => launchUrl(Uri.parse(url),
                            mode: LaunchMode.externalApplication),
                        style: FilledButton.styleFrom(backgroundColor: color),
                        child: Text(label,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                    if (row.indexOf((label, color, url)) < row.length - 1)
                      const SizedBox(width: 10),
                  ],
                  if (row.length == 1) ...[
                    const SizedBox(width: 10),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Verify Payment sheet ──────────────────────────────────────────────────────

class VerifyPaymentSheet extends ConsumerStatefulWidget {
  final String tripId;
  final TripMember member;
  const VerifyPaymentSheet(
      {super.key, required this.tripId, required this.member});

  @override
  ConsumerState<VerifyPaymentSheet> createState() =>
      _VerifyPaymentSheetState();
}

class _VerifyPaymentSheetState extends ConsumerState<VerifyPaymentSheet> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final adminProfile = ref.read(userProfileProvider).valueOrNull;
      await ref.read(tripRepositoryProvider).approvePayment(
            widget.tripId,
            widget.member.uid,
            widget.member.pendingPaymentAmount,
            widget.member.displayName,
            adminProfile?.displayName ?? 'Admin',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      final adminProfile = ref.read(userProfileProvider).valueOrNull;
      await ref.read(tripRepositoryProvider).rejectPayment(
            widget.tripId,
            widget.member.uid,
            widget.member.displayName,
            adminProfile?.displayName ?? 'Admin',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final m = widget.member;

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text('Verify Payment',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(m.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('Amount Submitted',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text(
                  currency.format(m.pendingPaymentAmount),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _reject,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B6B)),
                  child: const Text('Reject',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _approve,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF39FF14)),
                  child: const Text('Approve',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Rename Trip dialog ────────────────────────────────────────────────────────

class RenameTripDialog extends ConsumerStatefulWidget {
  final String tripId;
  final String currentName;
  const RenameTripDialog(
      {super.key, required this.tripId, required this.currentName});

  @override
  ConsumerState<RenameTripDialog> createState() => _RenameTripDialogState();
}

class _RenameTripDialogState extends ConsumerState<RenameTripDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final t = _ctrl.text.trim();
    return t.isNotEmpty && t != widget.currentName && !_saving;
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty || name == widget.currentName) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tripRepositoryProvider)
          .updateTripDetails(widget.tripId, name: name);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Trip'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _canSave ? _save() : null,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        TextButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Rename')),
      ],
    );
  }
}

extension _DoubleX on double {
  T let<T>(T Function(double) f) => f(this);
}
