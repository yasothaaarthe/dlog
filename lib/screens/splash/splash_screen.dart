import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // Controls the entire splash animation.
    // 5 seconds gives the user enough time to appreciate the branding.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _controller.forward();

    // Move to Welcome Screen after splash finishes.
    Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WelcomeScreen(),
          transitionDuration: const Duration(milliseconds: 900),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [

              // ==========================================================
              // OFF IMAGE
              // ==========================================================
              Image.asset(
                'assets/images/dlog_splash_car_off.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),

              // ==========================================================
              // ON IMAGE
              //
              // This fades over the OFF image.
              // The custom curve below creates the "headlights waking up"
              // effect instead of an instant switch.
              // ==========================================================
              Opacity(
                opacity: _headlightOpacity(_controller.value),
                child: Image.asset(
                  'assets/images/dlog_splash_car_on.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),

              // ==========================================================
              // LOADING BAR
              // ==========================================================
              Positioned(
                left: 68,
                right: 68,
                bottom: 105,
                child: _LoadingBar(
                  progress: _controller.value,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================================================================
  // HEADLIGHT ANIMATION
  //
  // 0.00 - 0.35 : completely OFF
  // 0.35 - 0.60 : slowly illuminates
  // 0.60 - 0.70 : tiny flicker
  // 0.70 - 0.82 : settles brighter
  // 0.82 - 1.00 : fully ON
  // ================================================================
  double _headlightOpacity(double progress) {
    if (progress < 0.35) {
      return 0.0;
    }

    if (progress < 0.60) {
      final t = (progress - 0.35) / 0.25;

      // Smooth acceleration.
      return Curves.easeInOut.transform(t) * 0.72;
    }

    if (progress < 0.64) {
      // Tiny dip — creates the subtle electrical flicker.
      final t = (progress - 0.60) / 0.04;
      return 0.72 - (0.18 * t);
    }

    if (progress < 0.68) {
      // Quickly recover from the flicker.
      final t = (progress - 0.64) / 0.04;
      return 0.54 + (0.34 * Curves.easeOut.transform(t));
    }

    if (progress < 0.76) {
      // Slowly reach full brightness.
      final t = (progress - 0.68) / 0.08;
      return 0.88 + (0.12 * Curves.easeInOut.transform(t));
    }

    return 1.0;
  }
}


// ============================================================================
// LOADING BAR
// ============================================================================

class _LoadingBar extends StatelessWidget {
  final double progress;

  const _LoadingBar({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: Stack(
        children: [

          // ----------------------------------------------------------
          // Background track
          // ----------------------------------------------------------
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          // ----------------------------------------------------------
          // Glowing progress
          // ----------------------------------------------------------
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),

                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFB8C0),
                    Color(0xFFFF3150),
                    Color(0xFFFF6375),
                  ],
                ),

                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFFF3150),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Color(0xFFFF3150),
                    blurRadius: 25,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}