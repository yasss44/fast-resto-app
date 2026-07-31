import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';

class RestoProfileScreen extends StatelessWidget {
  const RestoProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RestoProvider>(context);
    final settings = provider.settings;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: false,
            backgroundColor: const Color(0xFF18181B),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  settings?.image != null && settings!.image.isNotEmpty
                      ? (settings.image.startsWith('http')
                          ? Image.network(settings.image, fit: BoxFit.cover)
                          : Image.memory(base64Decode(settings.image.split(',').last), fit: BoxFit.cover))
                      : Container(
                          color: const Color(0xFF18181B),
                          alignment: Alignment.center,
                          child: const Icon(Icons.restaurant, color: Color(0xFF71717A), size: 72),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, const Color(0xFF09090B).withValues(alpha: 0.95)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text(settings?.cuisineType.toUpperCase() ?? 'CUISINE', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              settings?.name ?? 'Mon Restaurant',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Color(0xFFF59E0B), size: 24),
                            SizedBox(width: 8),
                            Text('4.8', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFA1A1AA), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${settings?.city ?? 'Ville'} • À 2.4 km',
                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  const Text('Aperçu public', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility, color: Color(0xFF3B82F6), size: 32),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Ceci est un aperçu de la vitrine que vos clients voient sur l\'application FAST. Modifiez ces informations depuis l\'onglet Paramètres.', 
                            style: TextStyle(color: Color(0xFFA1A1AA), height: 1.5)
                          ),
                        ),
                      ],
                    ),
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
