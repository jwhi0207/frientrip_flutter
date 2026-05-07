import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/trip_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/invite_code.dart';

class JoinTripDialog extends ConsumerStatefulWidget {
  const JoinTripDialog({super.key});

  @override
  ConsumerState<JoinTripDialog> createState() => _JoinTripDialogState();
}

class _JoinTripDialogState extends ConsumerState<JoinTripDialog> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  bool get _canJoin {
    final clean =
        _codeCtrl.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return clean.length == 8 && !_loading;
  }

  Future<void> _join() async {
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (uid == null || profile == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final code = normalizeInviteCode(_codeCtrl.text);
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.findTripByInviteCode(code);

      if (trip == null) {
        setState(() {
          _loading = false;
          _error = 'Trip not found or code is disabled.';
        });
        return;
      }
      if (trip.memberIds.contains(uid)) {
        setState(() {
          _loading = false;
          _error = "You're already a member of this trip.";
        });
        return;
      }

      final member = TripMember(
        uid: uid,
        displayName: profile.displayName,
        email: profile.email,
        avatarSeed: profile.avatarSeed,
        avatarColor: profile.avatarColor,
      );
      await repo.joinTripByCode(trip.id, member);

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join with Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) {
              if (_canJoin) _join();
            },
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canJoin ? _join : null,
          child: const Text('Join'),
        ),
      ],
    );
  }
}
