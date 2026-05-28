import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/pickers.dart';

class CreateTripSheet extends ConsumerStatefulWidget {
  const CreateTripSheet({super.key});

  @override
  ConsumerState<CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends ConsumerState<CreateTripSheet> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String _selectedEmoji = '';
  int _checkInMillis = 0;
  int _checkOutMillis = 0;
  final List<String> _inviteEmails = [];
  bool _showDetails = false;
  bool _loading = false;
  String? _error;

  static const _emojis = [
    '🏖️', '🏔️', '🏂', '⛺', '✈️', '🏠',
    '🌴', '🎉', '☀️', '❄️', '🏢', '🚗',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _addressCtrl.dispose();
    _costCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(int millis) => millis > 0
      ? DateFormat('MMM d, y')
          .format(DateTime.fromMillisecondsSinceEpoch(millis))
      : '';

  Future<void> _pickDate(bool isCheckIn) async {
    final current = isCheckIn ? _checkInMillis : _checkOutMillis;
    final initial = current > 0
        ? DateTime.fromMillisecondsSinceEpoch(current)
        : DateTime.now();
    final picked = await showPlatformDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isCheckIn) {
        _checkInMillis = picked.millisecondsSinceEpoch;
      } else {
        _checkOutMillis = picked.millisecondsSinceEpoch;
      }
    });
  }

  void _addEmail() {
    final email = _emailCtrl.text.trim();
    if (email.contains('@') && !_inviteEmails.contains(email)) {
      setState(() {
        _inviteEmails.add(email);
        _emailCtrl.clear();
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = ref.read(currentUidProvider);
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (uid == null || profile == null) {
        setState(() {
          _loading = false;
          _error = 'Not signed in.';
        });
        return;
      }

      await ref.read(tripRepositoryProvider).createTrip(
            name: name,
            ownerId: uid,
            displayName: profile.displayName,
            email: profile.email,
            avatarSeed: profile.avatarSeed,
            avatarColor: profile.avatarColor,
            emoji: _selectedEmoji,
            description: _descCtrl.text.trim(),
            pendingEmails: List.from(_inviteEmails),
            checkInMillis: _checkInMillis,
            checkOutMillis: _checkOutMillis,
            address: _addressCtrl.text.trim(),
            houseURL: _urlCtrl.text.trim(),
            totalCost: double.tryParse(
                    _costCtrl.text.trim().replaceAll(',', '')) ??
                0.0,
          );

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Failed to create trip. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('New Trip', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),

                  // Trip name
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Trip name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Toggle details
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
                    icon: Icon(_showDetails
                        ? Icons.expand_less
                        : Icons.expand_more),
                    label: Text(_showDetails
                        ? 'Hide details'
                        : 'Add more details'),
                  ),

                  if (_showDetails) ...[
                    // Emoji picker
                    Text('Vibe', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _emojis.map((e) {
                        final sel = _selectedEmoji == e;
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _selectedEmoji = sel ? '' : e),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: sel
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: sel
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 2)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(e,
                                style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Dates
                    Row(
                      children: [
                        Expanded(
                            child: _DateField(
                          label: 'Check-in',
                          value: _fmtDate(_checkInMillis),
                          onTap: () => _pickDate(true),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _DateField(
                          label: 'Check-out',
                          value: _fmtDate(_checkOutMillis),
                          onTap: () => _pickDate(false),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'House URL',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Total cost',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Invite friends
                    Text('Invite friends',
                        style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addEmail(),
                            decoration: const InputDecoration(
                              hintText: 'Email address',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addEmail,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    if (_inviteEmails.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _inviteEmails
                            .map((e) => InputChip(
                                  label: Text(e),
                                  onDeleted: () => setState(
                                      () => _inviteEmails.remove(e)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),

                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Text('Create Trip'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month, size: 20),
        ),
        child: Text(
          value.isEmpty ? 'Select' : value,
          style: TextStyle(
            color: value.isEmpty
                ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                : null,
          ),
        ),
      ),
    );
  }
}
