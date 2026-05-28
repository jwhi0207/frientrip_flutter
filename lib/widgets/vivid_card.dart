import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A card with a cycling vivid neon accent border, matching the Android VividCard.
///
/// - Dark mode: 2dp neon border on [kDarkCardSurface], 1dp elevation.
/// - Light mode: 2dp border at 30% opacity on #F8FAFC, 6dp elevation.
///
/// [accentIndex] selects from [kVividAccents] via modulo.
class VividCard extends StatelessWidget {
  final int accentIndex;
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Clip clipBehavior;

  const VividCard({
    super.key,
    this.accentIndex = 0,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = kVividAccents[accentIndex.abs() % kVividAccents.length];
    final borderColor = isDark ? accent : accent.withValues(alpha: 0.30);
    final bgColor = isDark ? kDarkCardSurface : const Color(0xFFF8FAFC);
    final elevation = isDark ? 1.0 : 6.0;

    return Card(
      elevation: elevation,
      color: bgColor,
      margin: EdgeInsets.zero,
      clipBehavior: clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: onTap != null
          ? InkWell(borderRadius: borderRadius, onTap: onTap, child: child)
          : child,
    );
  }
}

enum VividStatus { paid, due, pending }

/// Theme-aware status pill using the Vivid Pulse semantic colors.
class VividStatusBadge extends StatelessWidget {
  final String label;
  final VividStatus status;

  const VividStatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor;
    final Color bgColor;

    switch (status) {
      case VividStatus.paid:
        textColor = isDark ? kStatusPaidDark : kStatusPaidLight;
        bgColor   = isDark ? kStatusPaidBgDark : kStatusPaidBgLight;
      case VividStatus.due:
        textColor = isDark ? kStatusDueDark : kStatusDueLight;
        bgColor   = isDark ? kStatusDueBgDark : kStatusDueBgLight;
      case VividStatus.pending:
        textColor = isDark ? kStatusPendingDark : kStatusPendingLight;
        bgColor   = isDark ? kStatusPendingBgDark : kStatusPendingBgLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
