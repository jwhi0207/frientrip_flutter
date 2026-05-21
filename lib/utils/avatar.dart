import 'package:flutter/material.dart';
import '../theme/colors.dart';

const avatarSeeds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

const avatarColors = kAvatarColors;

String avatarUrl(int seed) =>
    'https://api.dicebear.com/9.x/pixel-art/png?seed=$seed&size=128';

Color avatarBackgroundColor(int colorIndex) {
  if (colorIndex < 0 || colorIndex >= avatarColors.length) return avatarColors[0];
  return avatarColors[colorIndex];
}
