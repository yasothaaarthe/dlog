import 'package:flutter/material.dart';

import 'dlog_colors.dart';

class DLogTextStyles {
  DLogTextStyles._();

  static const TextStyle display = TextStyle(
    color: DLogColors.white,
    fontSize: 38,
    fontWeight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -0.8,
  );

  static const TextStyle heading = TextStyle(
    color: DLogColors.white,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.4,
  );

  static const TextStyle subheading = TextStyle(
    color: DLogColors.silverLight,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    color: DLogColors.silver,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMuted = TextStyle(
    color: DLogColors.grey,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle button = TextStyle(
    color: DLogColors.black,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static const TextStyle label = TextStyle(
    color: DLogColors.grey,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  static const TextStyle accent = TextStyle(
    color: DLogColors.burgundyBright,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}
