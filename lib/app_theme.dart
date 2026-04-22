import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Cool / Night-sky palette ──────────────────────────────────────────
const kBg         = Color(0xFF080E1A);
const kSheet      = Color(0xFF0A1220);
const kCardBg     = Color(0x0DF0F6FF);
const kCardBorder = Color(0x1AFFFFFF);
const kPill       = Color(0xB8080E1A);
const kPillBorder = Color(0x38FFFFFF);
const kCream      = Color(0xFFF0F6FF);
const kCreamDim   = Color(0x73F0F6FF);
const kCreamFaint = Color(0x26F0F6FF);
const kGold       = Color(0xFF6DB8F2);   // accent blue
const kGoldGlow   = Color(0x596DB8F2);
const kConfGreen  = Color(0xFF4ECB7E);
const kConfOrange = Color(0xFFF09040);
const kConfRed    = Color(0xFFE05555);

// Sky gradient
const kSky0      = Color(0xFF0C1828);
const kSky1      = Color(0xFF152033);
const kSky2      = Color(0xFF1E2D42);
const kWarmEdge  = Color(0xFF2D4A6E);

// ── Text style helpers ────────────────────────────────────────────────
TextStyle kSans({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = kCream,
  double? letterSpacing,
  double height = 1.4,
}) =>
    GoogleFonts.nunito(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

TextStyle kMono({
  double size = 14,
  Color color = kCream,
  double? letterSpacing,
}) =>
    GoogleFonts.spaceMono(
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
    );

TextStyle kSerif({
  double size = 24,
  Color color = kCream,
}) =>
    GoogleFonts.dmSerifDisplay(fontSize: size, color: color);
