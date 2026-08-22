import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const OnboardingScreen({super.key, this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: Icons.shopping_bag_outlined,
      title: 'Click & Collect\nen 3 étapes',
      description:
          '1. Commandez depuis votre restaurant préféré\n'
          '2. Marchez jusqu\'au restaurant\n'
          '3. Récupérez votre commande sans faire la queue',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
    _OnboardingSlide(
      icon: Icons.map_outlined,
      title: 'Suivi GPS\nen temps réel',
      description:
          'Suivez votre commande à la trace grâce au GPS.\n'
          'Sachez exactement quand partir pour que tout\n'
          'soit prêt à votre arrivée.',
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    _OnboardingSlide(
      icon: Icons.emoji_events_outlined,
      title: 'Gagnez des\nrécompenses FAST',
      description:
          'Cumulez des points à chaque commande.\n'
          'Débloquez le statut FAST Gold et\n'
          'bénéficiez d\'avantages exclusifs !',
      gradientColors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_onboarding_done', true);
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: const Text(
                      'Passer',
                      style: TextStyle(
                        color: Color(0xFF71717A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index]);
                },
              ),
            ),

            // Bottom section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                children: [
                  // Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _slides[_currentPage].gradientColors.first
                              : const Color(0xFF27272A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _slides.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finishOnboarding();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _slides[_currentPage].gradientColors.first,
                        foregroundColor: const Color(0xFF09090B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < _slides.length - 1
                            ? 'Suivant'
                            : 'Commencer !',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
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
    );
  }

  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container with gradient
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: slide.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: slide.gradientColors.first.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: 56,
              color: const Color(0xFF09090B),
            ),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFA1A1AA),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}
