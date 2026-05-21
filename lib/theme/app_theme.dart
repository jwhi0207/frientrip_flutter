import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';

const _lightScheme = ColorScheme(
  brightness: Brightness.light,

  primary:            Color(0xFF0090C0),
  onPrimary:          Colors.white,
  primaryContainer:   Color(0xFFD6F2FF),
  onPrimaryContainer: Color(0xFF001D2B),

  secondary:             Color(0xFFAA00BB),
  onSecondary:           Colors.white,
  secondaryContainer:    Color(0xFFF5D0FF),
  onSecondaryContainer:  Color(0xFF2E0036),

  tertiary:             Color(0xFFD41654),
  onTertiary:           Colors.white,
  tertiaryContainer:    Color(0xFFFFD9E4),
  onTertiaryContainer:  Color(0xFF3F001D),

  surface:            kLightSurface,
  onSurface:          kLightOnSurface,
  surfaceContainerHighest: kLightSurfaceVariant,
  onSurfaceVariant:   kLightOnSurfaceVar,
  outline:            kLightOutline,
  outlineVariant:     kLightOutlineVariant,

  error:              kLightError,
  onError:            Colors.white,
  errorContainer:     kLightErrorContainer,
  onErrorContainer:   Color(0xFF410002),

  inverseSurface:     Color(0xFF2F3033),
  onInverseSurface:   Color(0xFFF1F0F4),
  inversePrimary:     kElectricCyan,
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,

  primary:            kElectricCyan,
  onPrimary:          Color(0xFF003544),
  primaryContainer:   Color(0xFF004D65),
  onPrimaryContainer: Color(0xFFB8EAFF),

  secondary:             kNeonPurple,
  onSecondary:           Color(0xFF3F0044),
  secondaryContainer:    Color(0xFF5A0062),
  onSecondaryContainer:  Color(0xFFF5D0FF),

  tertiary:             kVividPink,
  onTertiary:           Color(0xFF44001D),
  tertiaryContainer:    Color(0xFF66002E),
  onTertiaryContainer:  Color(0xFFFFD9E4),

  surface:            kDarkSurface,
  onSurface:          kDarkOnSurface,
  surfaceContainerHighest: kDarkSurfaceVariant,
  onSurfaceVariant:   kDarkOnSurfaceVar,
  outline:            kDarkOutline,
  outlineVariant:     kDarkOutlineVariant,

  error:              kDarkError,
  onError:            Color(0xFF690005),
  errorContainer:     kDarkErrorContainer,
  onErrorContainer:   Color(0xFFFFDAD6),

  inverseSurface:     kDarkOnSurface,
  onInverseSurface:   kDarkSurface,
  inversePrimary:     Color(0xFF0090C0),
);

ThemeData buildLightTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: _lightScheme,
  textTheme: kAppTypography,
  appBarTheme: const AppBarTheme(
    backgroundColor: kLightBackground,
    foregroundColor: kLightOnSurface,
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  ),
  scaffoldBackgroundColor: kLightBackground,
  cardTheme: const CardThemeData(
    color: kLightSurface,
    surfaceTintColor: Colors.transparent,
  ),
);

ThemeData buildDarkTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: _darkScheme,
  textTheme: kAppTypography,
  appBarTheme: const AppBarTheme(
    backgroundColor: kDarkBackground,
    foregroundColor: kDarkOnSurface,
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  ),
  scaffoldBackgroundColor: kDarkBackground,
  cardTheme: const CardThemeData(
    color: kDarkCardSurface,
    surfaceTintColor: Colors.transparent,
  ),
);
