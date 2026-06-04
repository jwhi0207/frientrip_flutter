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

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

class ExpensesScreen extends ConsumerWidget {
  final String tripId;
  const ExpensesScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(tripExpensesProvider(tripId)).valueOrNull ?? [];
    final members = ref.watch(tripMembersProvider(tripId)).valueOrNull ?? [];
    final trip = ref.watch(tripStreamProvider(tripId)).valueOrNull;
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

    // Admin entry (always present — lodging)
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

    // Other submitters (non-admin, have approved expenses)
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

    final totalOwed =
        submitterEntries.fold(0.0, (s, e) => s + e.total);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Expenses'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        children: [
          // Total owed summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR TOTAL',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currency.format(totalOwed)} owed',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

          // Per-member cards
          for (int i = 0; i < submitterEntries.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SubmitterCard(
                tripId: tripId,
                entry: submitterEntries[i],
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
                  tripId: tripId,
                  expense: pending[i],
                  isAdmin: isAdmin,
                  currentUid: uid,
                  currentUserName: currentMember?.displayName ?? '',
                  accentIndex: submitterEntries.length + i,
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
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
                tripId,
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

  const _SubmitterEntry({
    required this.member,
    this.lodgingShare = 0,
    this.lodgingTotal = 0,
    this.lodgingSplitMethod,
    this.expenseShares = const [],
    required this.total,
    this.isAdmin = false,
  });
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.5),
                                    ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _currency.format(e.total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
            // Lodging row (admin only)
            if (e.isAdmin && e.lodgingShare > 0)
              _ExpenseRow(
                icon: Icons.home,
                description: 'Lodging',
                myShare: e.lodgingShare,
                total: e.lodgingTotal,
                splitLabel: 'Split by Nights',
                isApproved: true,
              ),
            // Expense rows
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
        content:
            Text('Remove "${expense.description}" (\$${expense.amount.toStringAsFixed(2)})?'),
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
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Expense Row (inside expanded card) ───────────────────────────────────────

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
                          .deleteExpense(
                              tripId, expense, currentUserName),
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
