import 'package:flutter/material.dart';
import 'auth_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Logo
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Transform.scale(
                    scale: 1.35,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Bienvenue sur FAST',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez votre profil pour continuer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 64),

              // Client Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(initialRole: 'CLIENT'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cardBg,
                  foregroundColor: titleColor,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor),
                  ),
                  elevation: 0,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.person_outline, size: 36, color: Color(0xFFF59E0B)),
                    const SizedBox(height: 16),
                    Text(
                      'Je suis un Client',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Commander à manger',
                      style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Resto Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(initialRole: 'RESTAURANT'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF09090B),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Column(
                  children: [
                    Icon(Icons.restaurant, size: 36),
                    SizedBox(height: 16),
                    Text(
                      'Je suis un Restaurant',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gérer mes commandes',
                      style: TextStyle(fontSize: 12, color: Color(0xCC09090B), fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Driver Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(initialRole: 'LIVREUR'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cardBg,
                  foregroundColor: titleColor,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor),
                  ),
                  elevation: 0,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.delivery_dining_outlined, size: 34, color: Color(0xFF10B981)),
                    const SizedBox(height: 12),
                    Text(
                      'Je suis un Livreur',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Occasionnel ou permanent',
                      style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.normal),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Livraison à domicile',
                      style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
