import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../utils/pickers.dart';

class LodgingScreen extends ConsumerStatefulWidget {
  final String tripId;
  const LodgingScreen({super.key, required this.tripId});

  @override
  ConsumerState<LodgingScreen> createState() => _LodgingScreenState();
}

class _LodgingScreenState extends ConsumerState<LodgingScreen> {
  final _urlCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nightsCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  int _checkInMillis = 0;
  int _checkOutMillis = 0;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _addressCtrl.dispose();
    _nightsCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  int? get _validNights {
    final v = int.tryParse(_nightsCtrl.text.trim());
    return (v != null && v >= 0) ? v : null;
  }

  double? get _validCost {
    final v = double.tryParse(_costCtrl.text.trim());
    return (v != null && v >= 0.01) ? v : null;
  }

  bool get _canSave => _validNights != null && _validCost != null && !_saving;

  Future<void> _save() async {
    final nights = _validNights;
    final cost = _validCost;
    if (nights == null || cost == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(tripRepositoryProvider).updateHouseDetails(
            tripId: widget.tripId,
            houseURL: _urlCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            totalNights: nights,
            totalCost: cost,
            checkInMillis: _checkInMillis,
            checkOutMillis: _checkOutMillis,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(bool isCheckIn) async {
    final existing = isCheckIn ? _checkInMillis : _checkOutMillis;
    final initialDate = existing > 0
        ? DateTime.fromMillisecondsSinceEpoch(existing)
        : DateTime.now();

    final picked = await showPlatformDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isCheckIn) {
        _checkInMillis = _mergeDateTime(picked, _checkInMillis);
      } else {
        _checkOutMillis = _mergeDateTime(picked, _checkOutMillis);
      }
    });
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final existing = isCheckIn ? _checkInMillis : _checkOutMillis;
    final existingDt = existing > 0
        ? DateTime.fromMillisecondsSinceEpoch(existing)
        : DateTime.now();

    final picked = await showPlatformTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: existingDt.hour, minute: existingDt.minute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isCheckIn) {
        _checkInMillis = _mergeTime(_checkInMillis, picked.hour, picked.minute);
      } else {
        _checkOutMillis =
            _mergeTime(_checkOutMillis, picked.hour, picked.minute);
      }
    });
  }

  // Keep existing time, replace date portion
  int _mergeDateTime(DateTime newDate, int existingMillis) {
    final existing = existingMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(existingMillis)
        : newDate;
    return DateTime(newDate.year, newDate.month, newDate.day, existing.hour,
            existing.minute)
        .millisecondsSinceEpoch;
  }

  // Keep existing date, replace time portion
  int _mergeTime(int existingMillis, int hour, int minute) {
    final base = existingMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(existingMillis)
        : DateTime.now();
    return DateTime(base.year, base.month, base.day, hour, minute)
        .millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));
    final uid = ref.watch(currentUidProvider);
    final trip = tripAsync.valueOrNull;
    final isAdmin = trip?.ownerId == uid;

    // One-time initialization
    if (!_initialized && trip != null) {
      _initialized = true;
      _urlCtrl.text = trip.houseURL;
      _addressCtrl.text = trip.address;
      _nightsCtrl.text = trip.totalNights > 0 ? '${trip.totalNights}' : '';
      _costCtrl.text =
          trip.totalCost > 0 ? trip.totalCost.toStringAsFixed(2) : '';
      _checkInMillis = trip.checkInMillis;
      _checkOutMillis = trip.checkOutMillis;
    }

    if (tripAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Lodging'),
      ),
      body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero image ────────────────────────────────────────────────
          _HeroImage(
            thumbnailURL: trip?.thumbnailURL,
            houseURL: trip?.houseURL ?? '',
            tripName: trip?.name ?? '',
          ),
          const SizedBox(height: 20),

          // ── Admin banner ──────────────────────────────────────────────
          if (isAdmin) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings,
                      color: Theme.of(context).colorScheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Only',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          'You have editing permissions for this travel house.',
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
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── House URL (admin only) ────────────────────────────────────
          if (isAdmin) ...[
            _fieldLabel(context, 'House URL'),
            const SizedBox(height: 4),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://rentals.com/villa-123',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: 'Paste',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && mounted) {
                      setState(() => _urlCtrl.text = data!.text!);
                    }
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_urlCtrl.text.trim().isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: const Text('Open in Browser'),
                  onPressed: () => launchUrl(
                    Uri.parse(_urlCtrl.text.trim()),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            const SizedBox(height: 12),
          ],

          // ── Address ───────────────────────────────────────────────────
          _fieldLabel(context, 'Address'),
          const SizedBox(height: 4),
          TextField(
            controller: _addressCtrl,
            enabled: isAdmin,
            decoration: const InputDecoration(
              hintText: '123 Beach Rd, Malibu, CA 90265',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.location_on, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          // ── Nights + Cost ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, 'Total Nights'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nightsCtrl,
                      enabled: isAdmin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        hintText: '5',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.nightlight_round, size: 18),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, 'Total Cost'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _costCtrl,
                      enabled: isAdmin,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        hintText: '1,200',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Arrival ───────────────────────────────────────────────────
          _sectionLabel(context, 'ARRIVAL'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateTimeField(
                  label: 'Check-in Date',
                  value: _checkInMillis > 0
                      ? DateFormat('MM/dd/yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(_checkInMillis))
                      : '',
                  hint: 'mm/dd/yyyy',
                  icon: Icons.calendar_month,
                  enabled: isAdmin,
                  onTap: isAdmin ? () => _pickDate(true) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateTimeField(
                  label: 'Check-in Time',
                  value: _checkInMillis > 0
                      ? DateFormat('hh:mm a').format(
                          DateTime.fromMillisecondsSinceEpoch(_checkInMillis))
                      : '',
                  hint: '03:00 PM',
                  icon: Icons.schedule,
                  enabled: isAdmin,
                  onTap: isAdmin ? () => _pickTime(true) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Departure ─────────────────────────────────────────────────
          _sectionLabel(context, 'DEPARTURE'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateTimeField(
                  label: 'Check-out Date',
                  value: _checkOutMillis > 0
                      ? DateFormat('MM/dd/yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(_checkOutMillis))
                      : '',
                  hint: 'mm/dd/yyyy',
                  icon: Icons.calendar_month,
                  enabled: isAdmin,
                  onTap: isAdmin ? () => _pickDate(false) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateTimeField(
                  label: 'Check-out Time',
                  value: _checkOutMillis > 0
                      ? DateFormat('hh:mm a').format(
                          DateTime.fromMillisecondsSinceEpoch(_checkOutMillis))
                      : '',
                  hint: '11:00 AM',
                  icon: Icons.schedule,
                  enabled: isAdmin,
                  onTap: isAdmin ? () => _pickTime(false) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Save button ───────────────────────────────────────────────
          if (isAdmin)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

  Widget _fieldLabel(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      );

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
      );
}

// ── Hero image ────────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  final String? thumbnailURL;
  final String houseURL;
  final String tripName;

  const _HeroImage({
    required this.thumbnailURL,
    required this.houseURL,
    required this.tripName,
  });

  @override
  Widget build(BuildContext context) {
    final hasThumb = thumbnailURL != null && thumbnailURL!.isNotEmpty;
    final hasURL = houseURL.isNotEmpty;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: hasURL
              ? () => launchUrl(Uri.parse(houseURL),
                  mode: LaunchMode.externalApplication)
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasThumb)
                CachedNetworkImage(
                  imageUrl: thumbnailURL!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _gradient(context),
                )
              else
                _gradient(context),
              // Bottom scrim
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.67),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              // Trip name label
              Positioned(
                left: 12,
                bottom: 12,
                child: Text(
                  tripName.isNotEmpty ? '$tripName Main View' : 'House Photo',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.white),
                ),
              ),
              // View listing badge
              if (hasURL)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.73),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_browser,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          'View Listing',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradient(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

// ── Read-only date/time field ─────────────────────────────────────────────────

class _DateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _DateTimeField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixIcon: Icon(icon, size: 18),
              enabled: enabled,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            child: Text(
              value.isEmpty ? hint : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: value.isEmpty
                        ? Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4)
                        : null,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
