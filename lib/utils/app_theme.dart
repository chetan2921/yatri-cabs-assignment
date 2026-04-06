import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF38B000);
  static const Color background = Color(0xFF212728);
  static const Color white = Color(0xFFFFFFFF);
  static const Color fieldBg = Color(0xFFD5F2C8);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFF6D6D6D);
  static const Color textDark = Color(0xFF000000);
  static const Color navBg = Color(0xFF38B000);
  static const Color redIcon = Color(0xFFE61E14);
  static const double mapMarkerHue = 101.0;
}

class AppTextStyles {
  static TextStyle heading = GoogleFonts.poppins(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.5,
    color: AppColors.white,
  );

  static TextStyle fieldLabel = GoogleFonts.poppins(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors.primary,
  );

  static TextStyle fieldHint = GoogleFonts.poppins(
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors.textGrey,
  );

  static TextStyle tabLabel = GoogleFonts.poppins(
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors.textDark,
  );

  static TextStyle tabLabelActive = GoogleFonts.poppins(
    fontWeight: FontWeight.w700,
    fontSize: 12,
    color: AppColors.white,
  );

  static TextStyle toggleActive = GoogleFonts.poppins(
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: AppColors.white,
  );

  static TextStyle toggleInactive = GoogleFonts.poppins(
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: AppColors.primary,
  );

  static TextStyle exploreCabs = GoogleFonts.poppins(
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: AppColors.white,
  );

  static TextStyle navItem = GoogleFonts.poppins(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors.white,
  );

  static TextStyle navItemActive = GoogleFonts.poppins(
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: AppColors.textDark,
  );
}
