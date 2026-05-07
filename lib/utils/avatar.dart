import 'package:flutter/material.dart';

const avatarSeeds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

const avatarColors = [
  Color(0xFFB347EA), // NeonPurple
  Color(0xFF00F5FF), // ElectricCyan
  Color(0xFF00FF88), // MintGreen
  Color(0xFF39FF14), // NeonGreen
  Color(0xFFCCFF00), // ElectricLime
  Color(0xFFFF1493), // VividPink
  Color(0xFFFFB3C6), // Light Pink
  Color(0xFFD4AAFF), // Light Purple
  Color(0xFF9B59B6), // Mid Purple
  Color(0xFF795548), // Brown
];

String avatarUrl(int seed) =>
    'https://api.dicebear.com/9.x/pixel-art/png?seed=$seed&size=128';

Color avatarBackgroundColor(int colorIndex) {
  if (colorIndex < 0 || colorIndex >= avatarColors.length) return avatarColors[0];
  return avatarColors[colorIndex];
}
