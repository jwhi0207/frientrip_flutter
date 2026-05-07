import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/avatar.dart';

class AvatarWidget extends StatelessWidget {
  final int seed;
  final int colorIndex;
  final double size;

  const AvatarWidget({
    super.key,
    required this.seed,
    required this.colorIndex,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatarBackgroundColor(colorIndex),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl(seed),
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.6),
        ),
      ),
    );
  }
}
