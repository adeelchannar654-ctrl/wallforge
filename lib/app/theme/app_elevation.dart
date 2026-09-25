import 'package:flutter/material.dart';

/// Elevation and glow tokens from Stitch `DESIGN.md` §Elevation & Depth.
class AppElevation {
  const AppElevation._();

  // --- Glow rings (Level 4) -------------------------------------------------

  /// P1 glow: `0 0 12px rgba(0, 229, 255, 0.5)`.
  static List<BoxShadow> get p1Glow => const [
    BoxShadow(color: Color(0x8000E5FF), blurRadius: 12),
  ];

  /// P2 glow: `0 0 12px rgba(255, 75, 110, 0.5)`.
  static List<BoxShadow> get p2Glow => const [
    BoxShadow(color: Color(0x80FF4B6E), blurRadius: 12),
  ];

  // --- HUD shadow (Level 2) -------------------------------------------------

  /// HUD card shadow: `0 8px 24px rgba(0, 0, 0, 0.45)`.
  static List<BoxShadow> get hudShadow => const [
    BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // --- Board recess (Level 1) -----------------------------------------------

  /// Board ambient shadow: `0 16px 40px rgba(0, 0, 0, 0.85)`.
  static List<BoxShadow> get boardShadow => const [
    BoxShadow(color: Color(0xD9000000), blurRadius: 40, offset: Offset(0, 16)),
  ];

  // --- Pawn shadows (Level 3) -----------------------------------------------

  /// P1 pawn shadow: `0 4px 12px rgba(0, 218, 243, 0.7)`.
  static List<BoxShadow> get pawnP1Shadow => const [
    BoxShadow(color: Color(0xB300DAF3), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// P2 pawn shadow: `0 4px 10px rgba(230, 0, 76, 0.6)`.
  static List<BoxShadow> get pawnP2Shadow => const [
    BoxShadow(color: Color(0x99E6004C), blurRadius: 10, offset: Offset(0, 4)),
  ];

  // --- Wall shadows (Level 3) -----------------------------------------------

  /// P1 wall shadow: `0 2px 8px rgba(0, 218, 243, 0.8)`.
  static List<BoxShadow> get wallP1Shadow => const [
    BoxShadow(color: Color(0xCC00DAF3), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// P2 wall shadow: `0 2px 8px rgba(176, 0, 58, 0.8)`.
  static List<BoxShadow> get wallP2Shadow => const [
    BoxShadow(color: Color(0xCCB0003A), blurRadius: 8, offset: Offset(0, 2)),
  ];

  // --- Goal glow (Level 1) --------------------------------------------------

  /// Goal strip glow: `0 0 12px rgba(91, 233, 173, 0.5)`.
  static List<BoxShadow> get goalGlow => const [
    BoxShadow(color: Color(0x805BE9AD), blurRadius: 12),
  ];

  // --- Ambient underglow (Level 0-1) ----------------------------------------

  /// Board ambient underglow: `blur-3xl w-64 h-24 tertiary-container/10`.
  /// Used as a blurred rectangle behind the board, not a box-shadow.
  /// Declared here as a colour constant for the blur paint.
  static const Color ambientUnderglow = Color(0x1A5BE9AD);
}
