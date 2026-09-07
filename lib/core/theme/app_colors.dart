import 'package:flutter/material.dart';

/// Design tokens and semantic colors for Movistar AFR 5G Field Technician app.
class AppColors {
  // Brand colors
  static const Color primary = Color(0xFF00A9E0);          // Movistar Cyan Blue
  static const Color primaryDark = Color(0xFF0B2742);      // Deep Movistar Navy
  static const Color primaryContainer = Color(0xFF003254); // Surface container blue
  static const Color onPrimary = Color(0xFFFFFFFF);

  // OLED Contrast Theme
  static const Color background = Color(0xFF080C14);       // Ultra-dark background
  static const Color surface = Color(0xFF111827);          // Card/dialog surface
  static const Color surfaceVariant = Color(0xFF1F2937);   // Secondary elements
  static const Color surfaceHighlight = Color(0xFF283548); // Focused/hover cards
  static const Color onBackground = Color(0xFFF3F4F6);
  static const Color onSurface = Color(0xFFE5E7EB);
  static const Color onSurfaceVariant = Color(0xFF9CA3AF);
  static const Color outline = Color(0xFF374151);

  // Network & Technology Semantics
  static const Color accent5G = Color(0xFF00E676);         // 5G n78 3.5 GHz (optimal AFR 5G)
  static const Color accent5GLow = Color(0xFF00B0FF);      // 5G n28 700 MHz (rural coverage)
  static const Color accent4G = Color(0xFFFFB300);         // 4G LTE
  static const Color accent3G = Color(0xFFFF6D00);         // 3G UMTS (orange)
  static const Color accent2G = Color(0xFFAB47BC);         // 2G GSM (purple)
  static const Color accentOther = Color(0xFF78909C);       // Other operator

  // Status & Alignment HUD
  static const Color alignedGreen = Color(0xFF00E676);     // Within ±2° target
  static const Color closeOrange = Color(0xFFFF9100);      // Within ±10° target
  static const Color farRed = Color(0xFFFF5252);           // > 10° deviation
  static const Color laserBeam = Color(0xFF00E676);        // Line of sight
  static const Color accentSuccess = Color(0xFF00E676);
  static const Color accentWarning = Color(0xFFFF9100);
  static const Color accentError = Color(0xFFFF5252);
  static const Color compassDial = Color(0xFF1F2937);
  static const Color compassTick = Color(0xFF4B5563);
}
