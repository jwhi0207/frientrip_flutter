import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

// Matches Android AVATAR_COLORS (10 colors)
const _avatarColors = [
  Color(0xFFCE00E0), // NeonPurple
  Color(0xFF00BBF9), // ElectricCyan
  Color(0xFF00F5D4), // MintGreen
  Color(0xFF0EFB22), // NeonGreen
  Color(0xFFE1FF00), // ElectricLime
  Color(0xFFFF206E), // VividPink
  Color(0xFFFF4D6A), // Light Pink
  Color(0xFFE040FB), // Light Purple
  Color(0xFFD050F0), // Mid Purple
  Color(0xFF8D6E63), // Brown
];

// Matches Android AVATAR_SEEDS (1–12)
const _avatarSeeds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  int _selectedSeed = 1;
  int _selectedColor = 0;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile() {
    if (_initialized) return;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;
    _nameCtrl.text = profile.displayName;
    _selectedSeed = _avatarSeeds.contains(profile.avatarSeed)
        ? profile.avatarSeed
        : _avatarSeeds.first;
    _selectedColor = profile.avatarColor.clamp(0, _avatarColors.length - 1);
    _initialized = true;
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(
            uid,
            name,
            _selectedSeed,
            _selectedColor,
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize local state from profile on first load
    ref.listen(userProfileProvider, (_, __) {
      if (!_initialized) {
        setState(() => _initFromProfile());
      }
    });
    _initFromProfile();

    final cs = Theme.of(context).colorScheme;
    final canSave = _nameCtrl.text.trim().isNotEmpty && !_isSaving;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: canSave ? _save : null,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text('Save'),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar preview ──────────────────────────────────────────
            _AvatarPreview(
              seed: _selectedSeed,
              colorIndex: _selectedColor,
              name: _nameCtrl.text,
              size: 96,
            ),

            const SizedBox(height: 28),

            // ── Avatar picker ───────────────────────────────────────────
            Align(
              alignment: Alignment.center,
              child: Text(
                'Choose your avatar',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ),
            const SizedBox(height: 10),
            // 3 rows of 4
            for (int row = 0; row < 3; row++) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int col = 0; col < 4; col++) ...[
                    if (col > 0) const SizedBox(width: 12),
                    _AvatarOption(
                      seed: _avatarSeeds[row * 4 + col],
                      colorIndex: _selectedColor,
                      selected: _selectedSeed == _avatarSeeds[row * 4 + col],
                      onTap: () => setState(
                          () => _selectedSeed = _avatarSeeds[row * 4 + col]),
                    ),
                  ],
                ],
              ),
              if (row < 2) const SizedBox(height: 12),
            ],

            const SizedBox(height: 28),

            // ── Color picker ────────────────────────────────────────────
            Align(
              alignment: Alignment.center,
              child: Text(
                'Choose a color',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (int i = 0; i < _avatarColors.length; i++)
                  _ColorSwatch(
                    color: _avatarColors[i],
                    selected: _selectedColor == i,
                    onTap: () => setState(() => _selectedColor = i),
                  ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Display name ────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Display Name',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Your name',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 40),

            // ── Sign out ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Sign Out',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar Preview ─────────────────────────────────────────────────────────

class _AvatarPreview extends StatelessWidget {
  final int seed;
  final int colorIndex;
  final String name;
  final double size;

  const _AvatarPreview({
    required this.seed,
    required this.colorIndex,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _avatarColors[colorIndex.clamp(0, _avatarColors.length - 1)];
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.42,
            ),
          ),
          Image.network(
            'https://api.dicebear.com/9.x/pixel-art/png?seed=$seed&size=128',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Avatar Option (picker cell) ────────────────────────────────────────────

class _AvatarOption extends StatelessWidget {
  final int seed;
  final int colorIndex;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarOption({
    required this.seed,
    required this.colorIndex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _avatarColors[colorIndex.clamp(0, _avatarColors.length - 1)];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 3)
              : Border.all(color: Colors.transparent, width: 3),
        ),
        child: Container(
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            'https://api.dicebear.com/9.x/pixel-art/png?seed=$seed&size=128',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

// ── Color Swatch ───────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
