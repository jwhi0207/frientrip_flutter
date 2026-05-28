import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/trip_history_event.dart';
import '../../providers/trip_provider.dart';

class HistoryScreen extends ConsumerWidget {
  final String tripId;
  const HistoryScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(tripHistoryProvider(tripId)).valueOrNull ?? [];

    final expenses = events.where((e) => e.category == 'expenses').toList();
    final supplies = events.where((e) => e.category == 'supplies').toList();
    final payments = events.where((e) => e.category == 'payments').toList();
    final members = events.where((e) => e.category == 'members').toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Trip History'),
      ),
      body: events.isEmpty
          ? Center(
              child: Text(
                'No activity yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 32),
              children: [
                if (expenses.isNotEmpty)
                  _SectionCard(
                    icon: Icons.attach_money,
                    iconColor: const Color(0xFF00838F),
                    iconBg: const Color(0xFFE0F7FA),
                    label: 'Expenses',
                    count: expenses.length,
                    events: expenses,
                    dotColor: const Color(0xFF00ACC1),
                  ),
                if (supplies.isNotEmpty)
                  _SectionCard(
                    icon: Icons.checklist,
                    iconColor: const Color(0xFF2E7D32),
                    iconBg: const Color(0xFFE8F5E9),
                    label: 'Supplies',
                    count: supplies.length,
                    events: supplies,
                    dotColor: const Color(0xFF43A047),
                  ),
                if (payments.isNotEmpty)
                  _SectionCard(
                    icon: Icons.payments,
                    iconColor: const Color(0xFF6A1B9A),
                    iconBg: const Color(0xFFF3E5F5),
                    label: 'Payments',
                    count: payments.length,
                    events: payments,
                    dotColor: const Color(0xFF8E24AA),
                  ),
                if (members.isNotEmpty)
                  _SectionCard(
                    icon: Icons.group,
                    iconColor: const Color(0xFFE65100),
                    iconBg: const Color(0xFFFFF3E0),
                    label: 'Members',
                    count: members.length,
                    events: members,
                    dotColor: const Color(0xFFEF6C00),
                  ),
              ],
            ),
    );
  }
}

// ── Section Card ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final int count;
  final List<TripHistoryEvent> events;
  final Color dotColor;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.count,
    required this.events,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...events.map((event) => _EventRow(event: event, dotColor: dotColor)),
          ],
        ),
      ),
    );
  }
}

// ── Event Row ──────────────────────────────────────────────────────────────

class _EventRow extends StatelessWidget {
  final TripHistoryEvent event;
  final Color dotColor;

  const _EventRow({required this.event, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(event.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}';
  }
}
