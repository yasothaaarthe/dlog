import 'package:flutter/material.dart';

import '../theme/dlog_colors.dart';

class DLogBackground extends StatelessWidget {
  final Widget child;

  const DLogBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main black background
        Container(
          color: DLogColors.black,
        ),

        // Large, soft burgundy glow
        Positioned(
          top: -180,
          right: -120,
          child: _Glow(
            size: 430,
            color: DLogColors.burgundy,
            opacity: 0.20,
          ),
        ),

        // Lower atmospheric glow
        Positioned(
          bottom: -220,
          left: -140,
          child: _Glow(
            size: 480,
            color: DLogColors.burgundyDark,
            opacity: 0.16,
          ),
        ),

        // Very subtle central red atmosphere
        Positioned(
          top: 260,
          right: -180,
          child: _Glow(
            size: 360,
            color: DLogColors.burgundyBright,
            opacity: 0.07,
          ),
        ),

        // Content
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _Glow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}