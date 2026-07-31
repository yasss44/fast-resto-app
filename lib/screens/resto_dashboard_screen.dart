import 'package:flutter/material.dart';

class RestoDashboardScreen extends StatelessWidget {
  const RestoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text(
          'Dashboard Restaurant',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF18181B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            const Text(
              'Espace Restaurant en construction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les fonctionnalités définies dans votre cahier des charges\n(Commandes, Menu, Stats...) arriveront bientôt.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA1A1AA), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
