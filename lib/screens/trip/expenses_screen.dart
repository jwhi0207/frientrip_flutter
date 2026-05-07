import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/shared_expense.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class ExpensesScreen extends ConsumerWidget {
  final String tripId;
  const ExpensesScreen({super.key, required this.tripId});

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddExpenseSheet(
        onSubmit: (description, amount, splitMethod) {
          final profile = ref.read(userProfileProvider).valueOrNull;
          final uid = ref.read(currentUidProvider) ?? '';
          ref.read(tripRepositoryProvider).submitExpense(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(tripExpensesProvider(tripId)).valueOrNull ?? [];
    final members = ref.watch(tripMembersProvider(tripId)).valueOrNull ?? [];
    final uid = ref.watch(currentUidProvider);
    final tripOwner =
        ref.watch(tripStreamProvider(tripId)).valueOrNull?.ownerId;
    final isAdmin = uid == tripOwner;
    final currentMember = members.where((m) => m.uid == uid).firstOrNull;

    final pending = expenses.where((e) => !e.approved).toList();
    final approved = expenses.where((e) => e.approved).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Shared Expenses'),
        actions: [
          if (currentMember != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 17,
                backgroundImage: NetworkImage(
                  'https://api.dicebear.com/9.x/pixel-art/png'
                  '?seed=${currentMember.avatarSeed}&size=128',
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.account_circle),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      body: expenses.isEmpty
          ? Center(
              child: Text(
                'No expenses yet\nTap + to add one',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              children: [
                if (pending.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          'Pending',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        _StatusBadge(
                          label: _actionCount(pending, isAdmin, uid)
                              .let((n) => '$n ACTION REQUIRED'),
                          color: const Color(0xFFE65100),
                          bg: const Color(0xFFFFF3E0),
                        ),
                      ],
                    ),
                  ),
                  for (final expense in pending)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ExpenseCard(
                        tripId: tripId,
                        expense: expense,
                        isAdmin: isAdmin,
                        currentUid: uid,
                        currentUserName:
                            currentMember?.displayName ?? '',
                      ),
                    ),
                ],
                if (approved.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          'Approved',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        _StatusBadge(
                          label: '${approved.length} COMPLETED',
                          color: const Color(0xFF2E7D32),
                          bg: const Color(0xFFE8F5E9),
                        ),
                      ],
                    ),
                  ),
                  for (final expense in approved)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ExpenseCard(
                        tripId: tripId,
                        expense: expense,
                        isAdmin: isAdmin,
                        currentUid: uid,
                        currentUserName:
                            currentMember?.displayName ?? '',
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  int _actionCount(
      List<SharedExpense> pending, bool isAdmin, String? uid) {
    if (isAdmin) return pending.length;
    return pending.where((e) => e.submittedByUid == uid).length;
  }
}

// ── Expense Card ───────────────────────────────────────────────────────────

class _ExpenseCard extends ConsumerWidget {
  final String tripId;
  final SharedExpense expense;
  final bool isAdmin;
  final String? currentUid;
  final String currentUserName;

  const _ExpenseCard({
    required this.tripId,
    required this.expense,
    required this.isAdmin,
    required this.currentUid,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final splitLabel = expense.splitMethod == 'even'
        ? 'Split Evenly'
        : 'Split by Nights';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expense.approved)
                  _StatusBadge(
                    label: 'APPROVED',
                    color: const Color(0xFF2E7D32),
                    bg: const Color(0xFFE8F5E9),
                  )
                else
                  _StatusBadge(
                    label: 'PENDING APPROVAL',
                    color: const Color(0xFFE65100),
                    bg: const Color(0xFFFFF3E0),
                  ),
                const Spacer(),
                Text(
                  '\$${expense.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: expense.approved
                            ? cs.onSurface
                            : cs.primary,
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
              'Submitted by ${expense.submittedByName} • $splitLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            if (!expense.approved) ...[
              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              if (isAdmin)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => ref
                            .read(tripRepositoryProvider)
                            .approveExpense(
                              tripId,
                              expense.id,
                              currentUserName,
                            ),
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
                            .read(tripRepositoryProvider)
                            .deleteExpense(
                              tripId,
                              expense.id,
                              expense.description,
                              currentUserName,
                            ),
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
                        .read(tripRepositoryProvider)
                        .deleteExpense(
                          tripId,
                          expense.id,
                          expense.description,
                          currentUserName,
                        ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel Request'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status Badge ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

// ── Add Expense Sheet ──────────────────────────────────────────────────────

class _AddExpenseSheet extends StatefulWidget {
  final void Function(String description, double amount, String splitMethod)
      onSubmit;

  const _AddExpenseSheet({required this.onSubmit});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _splitMethod = 'even';

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double? get _parsedAmount =>
      double.tryParse(_amountCtrl.text.trim())?.let((v) => v > 0 ? v : null);

  bool get _canSubmit =>
      _descCtrl.text.trim().isNotEmpty && _parsedAmount != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Expense',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),

            // Description
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

            // Amount
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

            // Split method
            _SectionLabel('SPLIT METHOD'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Split Evenly'),
                  selected: _splitMethod == 'even',
                  onSelected: (_) =>
                      setState(() => _splitMethod = 'even'),
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
              child: const Text(
                'Submit Expense',
                style: TextStyle(fontWeight: FontWeight.bold),
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

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
