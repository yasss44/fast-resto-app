import 'package:flutter/material.dart';

class RestoSpotlightTutorial extends StatelessWidget {
  final Rect? targetRect;
  final String title;
  final String description;
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const RestoSpotlightTutorial({
    super.key,
    required this.targetRect,
    required this.title,
    required this.description,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final target =
        targetRect ??
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 56,
          height: 56,
        );
    final showBelow = target.center.dy < size.height * 0.46;
    final horizontalInset = 16.0;
    final cardWidth = (size.width - horizontalInset * 2).clamp(0.0, 420.0);

    final card = Semantics(
      liveRegion: true,
      namesRoute: true,
      label: 'Tutoriel étape ${step + 1} sur $totalSteps. $title. $description',
      child: Material(
        color: const Color(0xFF18181B),
        elevation: 18,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${step + 1} / $totalSteps',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: const Color(0xFFA1A1AA),
                    ),
                    child: const Text('Passer'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFFD4D4D8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (step + 1) / totalSteps,
                        minHeight: 5,
                        backgroundColor: const Color(0xFF3F3F46),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(112, 48),
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF09090B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      step == totalSteps - 1 ? 'Terminer' : 'Suivant',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SpotlightPainter(target)),
            ),
            Positioned(
              left: (size.width - cardWidth) / 2,
              top: showBelow
                  ? (target.bottom + 18).clamp(
                      safePadding.top + 12,
                      size.height - 300,
                    )
                  : null,
              bottom: showBelow
                  ? null
                  : (size.height - target.top + 18).clamp(
                      safePadding.bottom + 12,
                      size.height - 300,
                    ),
              child: card,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect target;

  _SpotlightPainter(this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final expanded = target.inflate(8);
    final radius = Radius.circular(expanded.height > 70 ? 16 : 12);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(expanded, radius));

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(expanded, radius),
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}
