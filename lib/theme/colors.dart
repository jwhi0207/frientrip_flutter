import 'package:flutter/material.dart';

// ── Vivid Pulse accents ──────────────────────────────────────────────────────
const Color kNeonPurple   = Color(0xFFCE00E0);
const Color kVividPink    = Color(0xFFFF206E);
const Color kElectricLime = Color(0xFFE1FF00);
const Color kNeonGreen    = Color(0xFF0EFB22);
const Color kElectricCyan = Color(0xFF00BBF9);
const Color kMintGreen    = Color(0xFF00F5D4);

const List<Color> kVividAccents = [
  kElectricCyan,
  kVividPink,
  kNeonGreen,
  kNeonPurple,
  kElectricLime,
  kMintGreen,
];

// ── Avatar colors (10, matches Android AVATAR_COLORS exactly) ────────────────
const List<Color> kAvatarColors = [
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

// ── Semantic status colors ────────────────────────────────────────────────────
const Color kStatusPaidDark      = kNeonGreen;
const Color kStatusPaidBgDark    = Color(0xFF0A2E0D);
const Color kStatusPaidLight     = Color(0xFF059212);
const Color kStatusPaidBgLight   = Color(0xFFE8FBE9);

const Color kStatusDueDark       = kVividPink;
const Color kStatusDueBgDark     = Color(0xFF2E0A18);
const Color kStatusDueLight      = Color(0xFFD41654);
const Color kStatusDueBgLight    = Color(0xFFFFE8EF);

const Color kStatusPendingDark   = kElectricCyan;
const Color kStatusPendingBgDark = Color(0xFF0A1E2E);
const Color kStatusPendingLight  = Color(0xFF0090C0);
const Color kStatusPendingBgLight = Color(0xFFE3F6FD);

// ── Light scheme ─────────────────────────────────────────────────────────────
const Color kLightSurface        = Color(0xFFFFFFFF);
const Color kLightBackground     = Color(0xFFFFFFFF);
const Color kLightSurfaceVariant = Color(0xFFF8FAFC);
const Color kLightOnSurface      = Color(0xFF0F172A);
const Color kLightOnSurfaceVar   = Color(0xFF475569);
const Color kLightOutline        = Color(0xFF94A3B8);
const Color kLightOutlineVariant = Color(0xFFE2E8F0);
const Color kLightError          = Color(0xFFBA1A1A);
const Color kLightErrorContainer = Color(0xFFFFDAD6);

// ── Dark scheme ───────────────────────────────────────────────────────────────
const Color kDarkSurface        = Color(0xFF05070A);
const Color kDarkBackground     = Color(0xFF05070A);
const Color kDarkCardSurface    = Color(0xFF121826);
const Color kDarkSurfaceVariant = Color(0xFF121826);
const Color kDarkOnSurface      = Color(0xFFE2E8F0);
const Color kDarkOnSurfaceVar   = Color(0xFFA0AEC0);
const Color kDarkOutline        = Color(0xFF4A5568);
const Color kDarkOutlineVariant = Color(0xFF2D3748);
const Color kDarkError          = Color(0xFFFFB4AB);
const Color kDarkErrorContainer = Color(0xFF93000A);
