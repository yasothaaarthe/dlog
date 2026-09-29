import 'package:flutter/material.dart';

import '../../theme/dlog_colors.dart';
import '../../theme/dlog_text_styles.dart';
import '../../widgets/dlog_background.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DLogBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Hero car image
              Positioned(
                left: 0,
                right: 0,
                bottom: 120,
                height: 470,
                child: Image.asset(
                  'assets/images/dlog_hero_car.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
              ),

              // Dark gradient over the car so the text stays readable
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          DLogColors.black.withValues(alpha: 0.15),
                          DLogColors.black.withValues(alpha: 0.45),
                          DLogColors.black.withValues(alpha: 0.92),
                          DLogColors.black,
                        ],
                        stops: const [
                          0.0,
                          0.38,
                          0.72,
                          1.0,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),

                    const Text(
                      'DLOG',
                      style: TextStyle(
                        color: DLogColors.silverLight,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'YOUR CAR.\nYOUR LOGBOOK.',
                      style: DLogTextStyles.display,
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Keep your vehicle maintenance organised, '
                      'understood and always within reach.',
                      style: DLogTextStyles.bodyMuted,
                    ),

                    const SizedBox(height: 30),

                    // GET STARTED
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('GET STARTED'),
                            SizedBox(width: 10),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // LOG IN
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Already have an account?  Log in',
                          style: TextStyle(
                            color: DLogColors.silver,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}