import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Zobrazí se při fázi [JudgingPhase.roundEnded].
///
/// Oslavná "Hotovo" obrazovka pro porotce s výrazným gradientním stylem.
class RoundEndedView extends StatelessWidget {
  const RoundEndedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 32.0),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF702AE1), Color(0xFF9055FF)], // Primary gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF702AE1).withOpacity(0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Kolo dokončeno',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Vaše hodnocení bylo úspěšně uloženo a přeneseno k organizátorovi soutěže.\n\nMůžete si odpočinout.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Malá dekorace dole
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(Colors.white),
                  const SizedBox(width: 8),
                  _buildDot(Colors.white.withOpacity(0.4)),
                  const SizedBox(width: 8),
                  _buildDot(Colors.white.withOpacity(0.2)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
