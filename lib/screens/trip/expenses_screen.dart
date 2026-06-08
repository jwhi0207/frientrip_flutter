import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/shared_expense.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/cost_calculator.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/vivid_card.dart';
import 'dashboard_screen.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

class ExpensesScreen extends ConsumerStatefulWidget {
  final String tripId;
  const ExpensesScreen({super.key, required this.tripId});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  // ── Pay Expenses — with payee selection when multiple submitters ──────────

  void _showPayExpenses(
    TripMember member,
    double remainingOwed,
    List<_SubmitterEntry> entries,
  ) {
    final nonZero = entries.where((e) => e.effectiveDue > 0.005).toList();

    if (nonZero.length <= 1) {
      // Single (or no) payee — go straight to payment sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => PayExpensesSheet(
          tripId: widget.tripId,
          member: member,
          amountDue: remainingOwed,
        ),
      );
    } else {
      // Multiple payees — let the user pick who they are paying
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetCtx) => _PayeeSelectionSheet(
          submitterEntries: nonZero,
          totalAmountDue: remainingOwed,
          onSelected: (amountDue) {
            Navigator.pop(sheetCtx);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => PayExpensesSheet(
                  tripId: widget.tripId,
                  member: member,
                  amountDue: amountDue,
                ),
              );
            });
          },
        ),
      );
    }
  }

  // ── Add Payment — member picker (admin only) ──────────────────────────────

  void _showAddPaymentPicker(
    List<TripMember> activeMembers,
    Map<String, double> memberCosts,
    Map<String, double> houseCosts,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _MemberPickerSheet(
        activeMembers: activeMembers,
        memberCosts: memberCosts,
        onSelected: (member) {
          Navigator.pop(sheetCtx);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final owed = memberCosts[member.uid] ?? 0.0;
            final house = houseCosts[member.uid] ?? 0.0;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => AddPaymentSheet(
                tripId: widget.tripId,
                member: member,
                computedOwed: owed,
                houseShare: house,
                expensesShare: owed - house,
              ),
            );
          });
        },
      ),
    );
  }

  // ── Add Expense sheet ─────────────────────────────────────────────────────

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExpenseFormSheet(
        onSubmit: (description, amount, splitMethod) {
          final profile = ref.read(userProfileProvider).valueOrNull;
          final uid = ref.read(currentUidProvider) ?? '';
          ref.read(expenseRepositoryProvider).addExpense(
                widget.tripId,
                description: description,
                amount: amount,
                splitMethod: splitMethod,
                submittedByUid: uid,
                submittedByName: profile?.displayName ?? '',
              );
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses =
        ref.watch(tripExpensesProvider(widget.tripId)).valueOrNull ?? [];
    final members =
        ref.watch(tripMembersProvider(widget.tripId)).valueOrNull ?? [];
    final trip = ref.watch(tripStreamProvider(widget.tripId)).valueOrNull;
    final uid = ref.watch(currentUidProvider);
    final isAdmin = uid == trip?.ownerId;
    final currentMember = members.where((m) => m.uid == uid).firstOrNull;
    final activeMembers = members.where((m) => !m.isDeactivated).toList();

    final houseCosts = trip != null
        ? CostCalculator.computeHouseCosts(trip, activeMembers)
        : <String, double>{};
    final myHouseCost = houseCosts[uid] ?? 0.0;

    final expensesBySubmitter = trip != null && uid != null
        ? CostCalculator.computeExpenseSharePerSubmitter(
            trip, activeMembers, expenses, uid)
        : <String, List<ExpenseShare>>{};

    final pending = expenses.where((e) => !e.approved).toList();

    // Build submitter list: admin always first (lodging), then others
    final submitterEntries = <_SubmitterEntry>[];
    final adminUid = trip?.ownerId ?? '';

    final adminMember = members.where((m) => m.uid == adminUid).firstOrNull;
    if (adminMember != null) {
      final adminExpenses = expensesBySubmitter[adminUid] ?? [];
      final adminTotal =
          myHouseCost + adminExpenses.fold(0.0, (s, e) => s + e.myShare);
      submitterEntries.add(_SubmitterEntry(
        member: adminMember,
        lodgingShare: myHouseCost,
        lodgingTotal: trip?.totalCost ?? 0,
        lodgingSplitMethod: 'byNights',
        expenseShares: adminExpenses,
        total: adminTotal,
        isAdmin: true,
      ));
    }

    for (final entry in expensesBySubmitter.entries) {
      if (entry.key == adminUid) continue;
      final member = members.where((m) => m.uid == entry.key).firstOrNull;
      if (member == null) continue;
      final total = entry.value.fold(0.0, (s, e) => s + e.myShare);
      submitterEntries.add(_SubmitterEntry(
        member: member,
        expenseShares: entry.value,
        total: total,
      ));
    }

    final totalOwed = submitterEntries.fold(0.0, (s, e) => s + e.total);

    // Remaining balance after approved payments
    final amountPaid = currentMember?.amountPaid ?? 0.0;
    final remainingOwed = (totalOwed - amountPaid).clamp(0.0, double.infinity);
    final paydownFactor = totalOwed > 0.001 ? remainingOwed / totalOwed : 0.0;

    // Stamp effectiveDue on each card (proportional to their share of totalOwed)
    final entriesWithDue = submitterEntries
        .map((e) => _SubmitterEntry(
              member: e.member,
              lodgingShare: e.lodgingShare,
              lodgingTotal: e.lodgingTotal,
              lodgingSplitMethod: e.lodgingSplitMethod,
              expenseShares: e.expenseShares,
              total: e.total,
              isAdmin: e.isAdmin,
              effectiveDue: (e.total * paydownFactor).clamp(0.0, e.total),
            ))
        .toList();

    // All member costs needed for the admin Add Payment picker
    final allMemberCosts = trip != null
        ? CostCalculator.computeMemberCosts(trip, activeMembers, expenses)
        : <String, double>{};

    final cs = Theme.of(context).colorScheme;
    final dueColor =
        remainingOwed < 0.005 ? Colors.green.shade600 : Colors.red.shade600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Expenses'),
        actions: [
          // Pay Expenses — current user pays their own balance
          if (currentMember != null)
            IconButton(
              icon: const Icon(Icons.payments),
              tooltip: 'Pay Expenses',
              onPressed: remainingOwed > 0.005
                  ? () => _showPayExpenses(
                      currentMember, remainingOwed, entriesWithDue)
                  : null,
            ),
          // Add Payment — admin records a payment for any member
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Payment',
              onPressed: () =>
                  _showAddPaymentPicker(activeMembers, allMemberCosts, houseCosts),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        children: [
          // ── YOUR TOTAL — right-aligned, color-coded ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YOUR TOTAL',
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _currency.format(remainingOwed),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: dueColor,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Due',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: dueColor,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Per-member cards
          for (int i = 0; i < entriesWithDue.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SubmitterCard(
                tripId: widget.tripId,
                entry: entriesWithDue[i],
                accentIndex: i,
                currentUid: uid,
                trip: trip,
              ),
            ),

          // Pending section
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'PENDING APPROVAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
              ),
            ),
            for (int i = 0; i < pending.length; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _PendingExpenseCard(
                  tripId: widget.tripId,
                  expense: pending[i],
                  isAdmin: isAdmin,
                  currentUid: uid,
                  currentUserName: currentMember?.displayName ?? '',
                  accentIndex: entriesWithDue.length + i,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Data model for submitter entries ─────────────────────────────────────────

class _SubmitterEntry {
  final TripMember member;
  final double lodgingShare;
  final double lodgingTotal;
  final String? lodgingSplitMethod;
  final List<ExpenseShare> expenseShares;
  final double total;
  final bool isAdmin;
  // Remaining balance after proportional payment allocation.
  // Defaults to `total` if no payments have been made.
  final double effectiveDue;

  _SubmitterEntry({
    required this.member,
    this.lodgingShare = 0,
    this.lodgingTotal = 0,
    this.lodgingSplitMethod,
    this.expenseShares = const [],
    required this.total,
    this.isAdmin = false,
    double? effectiveDue,
  }) : effectiveDue = effectiveDue ?? total;
}

// ── Submitter Card (expandable) ──────────────────────────────────────────────

class _SubmitterCard extends ConsumerStatefulWidget {
  final String tripId;
  final _SubmitterEntry entry;
  final int accentIndex;
  final String? currentUid;
  final Trip? trip;

  const _SubmitterCard({
    required this.tripId,
    required this.entry,
    required this.accentIndex,
    required this.currentUid,
    required this.trip,
  });

  @override
  ConsumerState<_SubmitterCard> createState() => _SubmitterCardState();
}

class _SubmitterCardState extends ConsumerState<_SubmitterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.entry;
    final isPaidOff = e.effectiveDue < 0.005;
    final amountColor = isPaidOff ? Colors.green.shade600 : cs.primary;

    return VividCard(
      accentIndex: widget.accentIndex,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
              child: Row(
                children: [
                  AvatarWidget(
                    seed: e.member.avatarSeed,
                    colorIndex: e.member.avatarColor,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.member.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (e.isAdmin)
                          Text(
                            'Trip Admin',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      cs.onSurface.withValues(alpha: 0.5),
                                ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _currency.format(e.effectiveDue),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 20,
                        color: cs.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3)),
            // Lodging row (admin only) — shows original amounts for history
            if (e.isAdmin && e.lodgingShare > 0)
              _ExpenseRow(
                icon: Icons.home,
                description: 'Lodging',
                myShare: e.lodgingShare,
                total: e.lodgingTotal,
                splitLabel: 'Split by Nights',
                isApproved: true,
              ),
            // Expense rows — show original amounts for history
            for (final share in e.expenseShares)
              _ExpenseRow(
                icon: Icons.receipt,
                description: share.expense.description,
                myShare: share.myShare,
                total: share.expense.amount,
                splitLabel: share.expense.splitMethod == 'even'
                    ? 'Split per Person'
                    : 'Split by Nights',
                isApproved: true,
                canEdit: share.expense.submittedByUid == widget.currentUid,
                onEdit: share.expense.submittedByUid == widget.currentUid
                    ? () => _showEditSheet(context, share.expense)
                    : null,
                onDelete: share.expense.submittedByUid == widget.currentUid
                    ? () => _confirmDelete(context, share.expense)
                    : null,
              ),
          ],
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, SharedExpense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExpenseFormSheet(
        initialDescription: expense.description,
        initialAmount: expense.amount,
        initialSplitMethod: expense.splitMethod,
        submitLabel: 'Update Expense',
        onSubmit: (description, amount, splitMethod) {
          final profile = ref.read(userProfileProvider).valueOrNull;
          ref.read(expenseRepositoryProvider).updateExpense(
                widget.tripId,
                expense,
                description: description,
                amount: amount,
                splitMethod: splitMethod,
                actorName: profile?.displayName ?? '',
              );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, SharedExpense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
            'Remove "${expense.description}" (\$${expense.amount.toStringAsFixed(2)})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final profile = ref.read(userProfileProvider).valueOrNull;
              ref.read(expenseRepositoryProvider).deleteExpense(
                    widget.tripId,
                    expense,
                    profile?.displayName ?? '',
                  );
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Expense Row (inside expanded card — historical amounts unchanged) ─────────

class _ExpenseRow extends StatelessWidget {
  final IconData icon;
  final String description;
  final double myShare;
  final double total;
  final String splitLabel;
  final bool isApproved;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ExpenseRow({
    required this.icon,
    required this.description,
    required this.myShare,
    required this.total,
    required this.splitLabel,
    this.isApproved = false,
    this.canEdit = false,
    this.onEdit,
    this.onDelete,
  });

  void _showActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(description,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                onEdit?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: cs.error),
              title: Text('Delete', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: canEdit ? () => _showActions(context) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    '${_currency.format(total)} total · $splitLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ),
            Text(
              _currency.format(myShare),
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pending Expense Card ─────────────────────────────────────────────────────

class _PendingExpenseCard extends ConsumerWidget {
  final String tripId;
  final SharedExpense expense;
  final bool isAdmin;
  final String? currentUid;
  final String currentUserName;
  final int accentIndex;

  const _PendingExpenseCard({
    required this.tripId,
    required this.expense,
    required this.isAdmin,
    required this.currentUid,
    required this.currentUserName,
    required this.accentIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final splitLabel = expense.splitMethod == 'even'
        ? 'Split per Person'
        : 'Split by Nights';

    return VividCard(
      accentIndex: accentIndex,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PENDING',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE65100),
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                const Spacer(),
                Text(
                  _currency.format(expense.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              expense.description,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'by ${expense.submittedByName} · $splitLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 12),
            if (isAdmin)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ref
                          .read(expenseRepositoryProvider)
                          .approveExpense(tripId, expense, currentUserName),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(expenseRepositoryProvider)
                          .deleteExpense(tripId, expense, currentUserName),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              )
            else if (expense.submittedByUid == currentUid)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ref
                      .read(expenseRepositoryProvider)
                      .deleteExpense(tripId, expense, currentUserName),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel Request'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Payee Selection Sheet ─────────────────────────────────────────────────────
// Shown before PayExpensesSheet when the user owes money to multiple submitters.

class _PayeeSelectionSheet extends StatelessWidget {
  final List<_SubmitterEntry> submitterEntries;
  final double totalAmountDue;
  final void Function(double amountDue) onSelected;

  const _PayeeSelectionSheet({
    required this.submitterEntries,
    required this.totalAmountDue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text(
              'Who are you paying?',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Select a payee to pre-fill the amount, or pay your full balance at once.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ),
          // Per-submitter options
          for (final entry in submitterEntries)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: AvatarWidget(
                seed: entry.member.avatarSeed,
                colorIndex: entry.member.avatarColor,
                size: 40,
              ),
              title: Text(entry.member.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: entry.isAdmin
                  ? Text('Trip Admin',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 12))
                  : null,
              trailing: Text(
                _currency.format(entry.effectiveDue),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
              ),
              onTap: () => onSelected(entry.effectiveDue),
            ),
          // Pay Total option
          const Divider(height: 1, indent: 20, endIndent: 20),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.payments, color: cs.primary, size: 20),
            ),
            title: const Text('Pay Total Balance',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Pay your full remaining balance at once',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
            ),
            trailing: Text(
              _currency.format(totalAmountDue),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
            ),
            onTap: () => onSelected(totalAmountDue),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Member Picker Sheet ───────────────────────────────────────────────────────
// Admin-only: select a member to add a payment for.

class _MemberPickerSheet extends StatelessWidget {
  final List<TripMember> activeMembers;
  final Map<String, double> memberCosts;
  final void Function(TripMember member) onSelected;

  const _MemberPickerSheet({
    required this.activeMembers,
    required this.memberCosts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Text(
              'Add Payment For',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          for (final member in activeMembers)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: AvatarWidget(
                seed: member.avatarSeed,
                colorIndex: member.avatarColor,
                size: 40,
              ),
              title: Text(member.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Paid: ${_currency.format(member.amountPaid)}',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
              ),
              trailing: Builder(builder: (context) {
                final owed = memberCosts[member.uid] ?? 0.0;
                final remaining = (owed - member.amountPaid)
                    .clamp(0.0, double.infinity);
                final isPaidUp = remaining < 0.005;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currency.format(remaining),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPaidUp
                                ? Colors.green.shade600
                                : cs.primary,
                          ),
                    ),
                    Text(
                      isPaidUp ? 'Paid up' : 'Due',
                      style: TextStyle(
                          fontSize: 11,
                          color: isPaidUp
                              ? Colors.green.shade600
                              : cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                );
              }),
              onTap: () => onSelected(member),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Expense Form Sheet (add / edit) ──────────────────────────────────────────

class _ExpenseFormSheet extends StatefulWidget {
  final String? initialDescription;
  final double? initialAmount;
  final String? initialSplitMethod;
  final String submitLabel;
  final void Function(String description, double amount, String splitMethod)
      onSubmit;

  const _ExpenseFormSheet({
    this.initialDescription,
    this.initialAmount,
    this.initialSplitMethod,
    this.submitLabel = 'Submit Expense',
    required this.onSubmit,
  });

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amountCtrl;
  late String _splitMethod;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.initialDescription ?? '');
    _amountCtrl = TextEditingController(
        text: widget.initialAmount != null
            ? widget.initialAmount!.toStringAsFixed(2)
            : '');
    _splitMethod = widget.initialSplitMethod ?? 'even';
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double? get _parsedAmount {
    final v = double.tryParse(_amountCtrl.text.trim());
    return v != null && v > 0 ? v : null;
  }

  bool get _canSubmit =>
      _descCtrl.text.trim().isNotEmpty && _parsedAmount != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initialDescription != null
                  ? 'Edit Expense'
                  : 'Add Expense',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            _SectionLabel('DESCRIPTION'),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Groceries for dinner',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _SectionLabel('AMOUNT'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '0.00',
                border: const OutlineInputBorder(),
                prefixText: '\$ ',
                prefixStyle: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _SectionLabel('SPLIT METHOD'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Split per Person'),
                  selected: _splitMethod == 'even',
                  onSelected: (_) => setState(() => _splitMethod = 'even'),
                  selectedColor: cs.primary,
                  labelStyle: _splitMethod == 'even'
                      ? TextStyle(color: cs.onPrimary)
                      : null,
                ),
                FilterChip(
                  label: const Text('Split by Nights'),
                  selected: _splitMethod == 'byNights',
                  onSelected: (_) =>
                      setState(() => _splitMethod = 'byNights'),
                  selectedColor: cs.primary,
                  labelStyle: _splitMethod == 'byNights'
                      ? TextStyle(color: cs.onPrimary)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSubmit
                  ? () => widget.onSubmit(
                        _descCtrl.text.trim(),
                        _parsedAmount!,
                        _splitMethod,
                      )
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                widget.submitLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
    );
  }
}
