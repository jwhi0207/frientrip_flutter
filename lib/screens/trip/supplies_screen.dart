import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/supply_item.dart';
import '../../models/shared_expense.dart';
import '../../models/trip_member.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/vivid_card.dart';

// â”€â”€ Constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _categories = [
  'Food',
  'Disposables',
  'Entertainment',
  'Outdoor & Games',
  'Other',
];

const _units = [
  '',
  'pieces',
  'dozen',
  'packs',
  'boxes',
  'bags',
  'cases',
  'bottles',
  'cans',
  'lbs',
  'oz',
  'gallons',
  'liters',
];

const _quickAddItems = [
  ('Burgers', 'Food'),
  ('Buns', 'Food'),
  ('Hot Dogs', 'Food'),
  ('Hot Dog Buns', 'Food'),
  ('Chili', 'Food'),
  ('Ketchup', 'Food'),
  ('Mustard', 'Food'),
  ('Eggs', 'Food'),
  ('Bacon', 'Food'),
  ('Coffee', 'Food'),
  ('Garbage Bags', 'Disposables'),
  ('Plastic Cups', 'Disposables'),
  ('Plastic Utensils', 'Disposables'),
  ('Bluetooth Speaker', 'Entertainment'),
  ('Cards', 'Outdoor & Games'),
  ('Board Games', 'Outdoor & Games'),
  ("S'mores Kit", 'Food'),
];

IconData _categoryIcon(String category) => switch (category) {
      'Food' => Icons.restaurant,
      'Disposables' => Icons.shopping_bag,
      'Entertainment' => Icons.sports_esports,
      'Outdoor & Games' => Icons.sports_baseball,
      _ => Icons.category,
    };

// â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class SuppliesScreen extends ConsumerStatefulWidget {
  final String tripId;
  const SuppliesScreen({super.key, required this.tripId});

  @override
  ConsumerState<SuppliesScreen> createState() => _SuppliesScreenState();
}

class _SuppliesScreenState extends ConsumerState<SuppliesScreen> {
  final Map<String, bool> _collapsed = {};
  String? _pendingClaimName;

  void _showAddSheet(List<SupplyItem> supplies) {
    final existingNames = supplies.map((s) => s.name.toLowerCase()).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddSupplySheet(
        existingNames: existingNames,
        onSave: (name, category, quantity) {
          final uid = ref.read(currentUidProvider) ?? '';
          ref.read(tripRepositoryProvider).addSupplyItem(
                widget.tripId, name, category, quantity, addedByUid: uid);
          Navigator.pop(context);
        },
        onSaveAndClaim: (name, category, quantity) {
          final uid = ref.read(currentUidProvider) ?? '';
          ref.read(tripRepositoryProvider).addSupplyItem(
                widget.tripId, name, category, quantity, addedByUid: uid);
          setState(() => _pendingClaimName = name);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDetailSheet(SupplyItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ItemDetailSheet(
        tripId: widget.tripId,
        itemId: item.id,
        onBillToGroup: () {
          Navigator.pop(ctx);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showBillToGroupSheet(item.id, item.name);
          });
        },
      ),
    );
  }

  void _showBillToGroupSheet(String itemId, String itemName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BillToGroupSheet(
        initialDescription: itemName,
        onSubmit: (description, amount, splitMethod) {
          final profile = ref.read(userProfileProvider).valueOrNull;
          final uid = ref.read(currentUidProvider) ?? '';
          ref.read(tripRepositoryProvider).submitExpense(
                widget.tripId,
                description: description,
                amount: amount,
                splitMethod: splitMethod,
                submittedByUid: uid,
                submittedByName: profile?.displayName ?? '',
                category: 'supply',
                linkedSupplyId: itemId,
              );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteDialog(SupplyItem item) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delete Item'),
          content: Text('Remove "${item.name}" from the supplies list?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                ref.read(tripRepositoryProvider).deleteSupplyItem(widget.tripId, item.id);
                Navigator.pop(ctx);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Remove "${item.name}" from the supplies list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(tripRepositoryProvider).deleteSupplyItem(widget.tripId, item.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliesAsync = ref.watch(tripSuppliesProvider(widget.tripId));
    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));
    final uid = ref.watch(currentUidProvider);

    // Watch for newly-added item so we can auto-open the detail sheet
    ref.listen(tripSuppliesProvider(widget.tripId), (_, next) {
      if (_pendingClaimName == null) return;
      next.whenData((supplies) {
        final found = supplies
            .where((s) =>
                s.name.toLowerCase() == _pendingClaimName!.toLowerCase())
            .firstOrNull;
        if (found != null) {
          setState(() => _pendingClaimName = null);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showDetailSheet(found);
          });
        }
      });
    });

    final supplies = suppliesAsync.valueOrNull ?? [];
    final isAdmin = uid == tripAsync.valueOrNull?.ownerId;

    final existingNames = supplies.map((s) => s.name.toLowerCase()).toSet();
    final availableQuickAdds = _quickAddItems
        .where((qa) => !existingNames.contains(qa.$1.toLowerCase()))
        .toList();

    final grouped = <String, List<SupplyItem>>{};
    for (final cat in _categories) {
      final items = supplies.where((s) => s.category == cat).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (items.isNotEmpty) grouped[cat] = items;
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(supplies),
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        children: [
          if (availableQuickAdds.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'QUICK ADD',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: availableQuickAdds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final qa = availableQuickAdds[i];
                  return ActionChip(
                    avatar: Icon(Icons.add,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary),
                    label: Text(qa.$1),
                    onPressed: () {
                      final uid = ref.read(currentUidProvider) ?? '';
                      ref.read(tripRepositoryProvider).addSupplyItem(
                            widget.tripId, qa.$1, qa.$2, '', addedByUid: uid);
                      setState(() => _pendingClaimName = qa.$1);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (supplies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No supplies yet — tap + or quick-add above!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ),
          for (final cat in _categories)
            if (grouped[cat] != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _CategoryCard(
                  category: cat,
                  accentIndex: _categories.indexOf(cat),
                  items: grouped[cat]!,
                  isCollapsed: _collapsed[cat] ?? true,
                  isAdmin: isAdmin,
                  currentUid: uid,
                  onToggle: () => setState(
                      () => _collapsed[cat] = !(_collapsed[cat] ?? true)),
                  onItemTap: _showDetailSheet,
                  onDelete: _showDeleteDialog,
                ),
              ),
        ],
      ),
    );
  }
}

// â”€â”€ Category Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CategoryCard extends StatelessWidget {
  final String category;
  final int accentIndex;
  final List<SupplyItem> items;
  final bool isCollapsed;
  final bool isAdmin;
  final String? currentUid;
  final VoidCallback onToggle;
  final ValueChanged<SupplyItem> onItemTap;
  final ValueChanged<SupplyItem> onDelete;

  const _CategoryCard({
    required this.category,
    required this.accentIndex,
    required this.items,
    required this.isCollapsed,
    required this.isAdmin,
    required this.currentUid,
    required this.onToggle,
    required this.onItemTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final claimedCount = items.where((i) => i.isClaimed).length;
    final progress = items.isEmpty ? 0.0 : claimedCount / items.length;

    return VividCard(
      accentIndex: accentIndex,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: isCollapsed
                ? BorderRadius.circular(12)
                : const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(_categoryIcon(category),
                          size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          category,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$claimedCount/${items.length} claimed',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: isCollapsed ? -0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: cs.outline.withValues(alpha: 0.15),
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _SupplyItemRow(
                    item: items[i],
                    isAdmin: isAdmin,
                    currentUid: currentUid,
                    onTap: () => onItemTap(items[i]),
                    onDelete: () => onDelete(items[i]),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

// â”€â”€ Supply Item Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SupplyItemRow extends StatelessWidget {
  final SupplyItem item;
  final bool isAdmin;
  final String? currentUid;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SupplyItemRow({
    required this.item,
    required this.isAdmin,
    required this.currentUid,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final names = item.claimedNames;

    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: Theme.of(context).textTheme.bodyLarge),
                  if (item.isClaimed)
                    ...item.claimEntries.entries.map((e) => Text(
                          e.value.isNotEmpty ? '${e.key}: ${e.value}' : e.key,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ))
                  else if (item.quantity.isNotEmpty)
                    Text(
                      item.quantity,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                ],
              ),
            ),
            if (names.isNotEmpty)
              ActionChip(
                label: Text(names.length == 1
                    ? names.first
                    : '${names.length} claimed'),
                onPressed: onTap,
              )
            else
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Claim'),
              ),
          ],
        ),
      ),
    );

    final canDelete = isAdmin ||
        (currentUid != null && currentUid!.isNotEmpty && item.addedByUid == currentUid);
    if (!canDelete) return row;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete,
            color: Theme.of(context).colorScheme.onError),
      ),
      child: row,
    );
  }
}

// â”€â”€ Item Detail Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ItemDetailSheet extends ConsumerStatefulWidget {
  final String tripId;
  final String itemId;
  final VoidCallback onBillToGroup;

  const _ItemDetailSheet({
    required this.tripId,
    required this.itemId,
    required this.onBillToGroup,
  });

  @override
  ConsumerState<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<_ItemDetailSheet> {
  bool _showClaimPicker = false;
  String _quantity = '';

  @override
  Widget build(BuildContext context) {
    final item = ref
        .watch(tripSuppliesProvider(widget.tripId))
        .valueOrNull
        ?.where((s) => s.id == widget.itemId)
        .firstOrNull;

    if (item == null) {
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));
    }

    final expenses = ref
            .watch(tripExpensesProvider(widget.tripId))
            .valueOrNull ??
        [];
    final members = ref
            .watch(tripMembersProvider(widget.tripId))
            .valueOrNull ??
        [];
    final uid = ref.watch(currentUidProvider);
    final currentMember = members.where((m) => m.uid == uid).firstOrNull;
    final linkedExpense =
        expenses.where((e) => e.linkedSupplyId == item.id).firstOrNull;
    final isAdmin =
        uid == ref.watch(tripStreamProvider(widget.tripId)).valueOrNull?.ownerId;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: _showClaimPicker
            ? _buildClaimPicker(context, item, currentMember)
            : _buildDetail(
                context, item, members, currentMember, linkedExpense, uid, isAdmin),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    SupplyItem item,
    List<TripMember> members,
    TripMember? currentMember,
    SharedExpense? linkedExpense,
    String? uid,
    bool isAdmin,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(_categoryIcon(item.category), size: 28, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    item.category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        if (item.isClaimed) ...[
          Text(
            'CLAIMED BY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 12),
          ...item.claimEntries.entries.map((e) {
            final member =
                members.where((m) => m.displayName == e.key).firstOrNull;
            final isMe = member?.uid == uid;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isMe
                      ? cs.primaryContainer.withValues(alpha: 0.4)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? '${e.key} (you)' : e.key,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: isMe
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                            ),
                            if (e.value.isNotEmpty)
                              Text(
                                e.value,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.6),
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (isMe || isAdmin)
                      TextButton(
                        onPressed: () {
                          ref.read(tripRepositoryProvider).unclaimSupplyItem(
                                widget.tripId,
                                item,
                                member?.uid ?? '',
                                e.key,
                              );
                        },
                        child: Text('Remove',
                            style: TextStyle(color: cs.error)),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ] else ...[
          Text(
            'No one has claimed this item yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 20),
        ],

        if (item.isClaimed) ...[
          const Divider(),
          const SizedBox(height: 12),
          if (linkedExpense != null)
            _BilledToGroupRow(expense: linkedExpense)
          else
            OutlinedButton.icon(
              onPressed: widget.onBillToGroup,
              icon: const Icon(Icons.receipt, size: 18),
              label: const Text('Bill to Group'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          const SizedBox(height: 16),
        ],

        if (currentMember == null)
          Center(
            child: Text(
              'You need to be a trip member to claim items.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.error),
            ),
          )
        else
          FilledButton.icon(
            onPressed: () => setState(() => _showClaimPicker = true),
            icon: const Icon(Icons.add, size: 18),
            label: Text(item.isClaimed ? 'Add My Claim' : 'Claim This Item'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: const StadiumBorder(),
            ),
          ),
      ],
    );
  }

  Widget _buildClaimPicker(
      BuildContext context, SupplyItem item, TripMember? currentMember) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claim ${item.name}',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'How much are you bringing?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 24),
        _QuantityField(
          value: _quantity,
          onChanged: (v) => setState(() => _quantity = v),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _showClaimPicker = false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: currentMember == null
                    ? null
                    : () {
                        ref.read(tripRepositoryProvider).claimSupplyItem(
                              widget.tripId,
                              item,
                              currentMember.uid,
                              currentMember.displayName,
                              _quantity.trim(),
                            );
                        setState(() => _showClaimPicker = false);
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Confirm Claim'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BilledToGroupRow extends StatelessWidget {
  final SharedExpense expense;
  const _BilledToGroupRow({required this.expense});

  @override
  Widget build(BuildContext context) {
    final approved = expense.approved;
    final statusColor =
        approved ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final bgColor =
        approved ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Billed to Group',
                  style: Theme.of(context).textTheme.labelMedium),
              Text(
                '\$${expense.amount.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            approved ? 'APPROVED' : 'PENDING',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Add Supply Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AddSupplySheet extends StatefulWidget {
  final Set<String> existingNames;
  final void Function(String name, String category, String quantity) onSave;
  final void Function(String name, String category, String quantity)
      onSaveAndClaim;

  const _AddSupplySheet({
    required this.existingNames,
    required this.onSave,
    required this.onSaveAndClaim,
  });

  @override
  State<_AddSupplySheet> createState() => _AddSupplySheetState();
}

class _AddSupplySheetState extends State<_AddSupplySheet> {
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  String _category = _categories.first;
  String _quantity = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nameFocus.requestFocus());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _isDuplicate =>
      widget.existingNames.contains(_nameCtrl.text.trim().toLowerCase());

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && !_isDuplicate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Supply Item',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: const OutlineInputBorder(),
                errorText: _isDuplicate
                    ? '"${_nameCtrl.text.trim()}" is already on the list'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text('Category',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cat in _categories)
                  FilterChip(
                    label: Text(cat),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _QuantityField(
              value: _quantity,
              onChanged: (v) => setState(() => _quantity = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _canSave
                      ? () => widget.onSave(
                            _nameCtrl.text.trim(),
                            _category,
                            _quantity.trim(),
                          )
                      : null,
                  child: const Text('Save'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _canSave
                      ? () => widget.onSaveAndClaim(
                            _nameCtrl.text.trim(),
                            _category,
                            _quantity.trim(),
                          )
                      : null,
                  child: const Text('Save & Claim'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Bill To Group Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BillToGroupSheet extends StatefulWidget {
  final String initialDescription;
  final void Function(String description, double amount, String splitMethod)
      onSubmit;

  const _BillToGroupSheet({
    required this.initialDescription,
    required this.onSubmit,
  });

  @override
  State<_BillToGroupSheet> createState() => _BillToGroupSheetState();
}

class _BillToGroupSheetState extends State<_BillToGroupSheet> {
  late final TextEditingController _descCtrl;
  final _amountCtrl = TextEditingController();
  String _splitMethod = 'even';

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountCtrl.text.trim());
  bool get _canSubmit =>
      _descCtrl.text.trim().isNotEmpty && (_amount ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill to Group',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Submit an expense for the group to split',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Split Method',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Split per Person'),
                  selected: _splitMethod == 'even',
                  onSelected: (_) => setState(() => _splitMethod = 'even'),
                ),
                FilterChip(
                  label: const Text('Split by Nights'),
                  selected: _splitMethod == 'byNights',
                  onSelected: (_) =>
                      setState(() => _splitMethod = 'byNights'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSubmit
                  ? () => widget.onSubmit(
                        _descCtrl.text.trim(),
                        _amount!,
                        _splitMethod,
                      )
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: const StadiumBorder(),
              ),
              child: const Text('Submit Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Quantity Field â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _QuantityField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _QuantityField({required this.value, required this.onChanged});

  @override
  State<_QuantityField> createState() => _QuantityFieldState();
}

class _QuantityFieldState extends State<_QuantityField> {
  bool _useCustom = false;
  int _count = 1;
  int _unitIndex = 0;
  final _customCtrl = TextEditingController();

  String get _pickerValue {
    final unit = _units[_unitIndex];
    return unit.isEmpty ? '$_count' : '$_count $unit';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_useCustom && mounted) widget.onChanged(_pickerValue);
    });
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        if (!_useCustom) ...[
          Row(
            children: [
              IconButton.outlined(
                onPressed: _count > 1
                    ? () {
                        setState(() => _count--);
                        widget.onChanged(_pickerValue);
                      }
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  _pickerValue,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                ),
              ),
              IconButton.outlined(
                onPressed: _count < 99
                    ? () {
                        setState(() => _count++);
                        widget.onChanged(_pickerValue);
                      }
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _unitIndex,
                isDense: true,
                isExpanded: true,
                onChanged: (i) {
                  if (i == null) return;
                  setState(() => _unitIndex = i);
                  widget.onChanged(_pickerValue);
                },
                items: [
                  for (int i = 0; i < _units.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                          _units[i].isEmpty ? '(none)' : _units[i]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _useCustom = true;
                  _customCtrl.text = '';
                });
                widget.onChanged('');
              },
              child: const Text('Type custom amount'),
            ),
          ),
        ] else ...[
          TextField(
            controller: _customCtrl,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              hintText: 'e.g. enough, a couple, big ole box',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.onChanged,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _useCustom = false;
                  _count = 1;
                  _unitIndex = 0;
                });
                widget.onChanged(_pickerValue);
              },
              child: const Text('Use picker'),
            ),
          ),
        ],
      ],
    );
  }
}
