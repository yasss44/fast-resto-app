// lib/screens/driver_account_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/delivery_service.dart';

class DriverAccountScreen extends StatefulWidget {
  const DriverAccountScreen({super.key});

  @override
  State<DriverAccountScreen> createState() => _DriverAccountScreenState();
}

class _DriverAccountScreenState extends State<DriverAccountScreen> {
  final _deliveryService = DeliveryService();
  bool _loading = true;
  double _earningsPlaceholder = 0;
  List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _deliveryService.getDriverProfile();
      if (!mounted) return;
      setState(() {
        _earningsPlaceholder = (profile['totalEarnings'] as num?)?.toDouble() ?? 0;
        _schedules = (profile['schedules'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final initial = (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'L';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Compte livreur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF09090B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Livreur',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (user?.email.isNotEmpty ?? false)
                            Text(
                              user!.email,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: Color(0xFFF59E0B), size: 28),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_earningsPlaceholder.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'Gains (aperçu)',
                            style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_month_outlined, color: Color(0xFF10B981)),
                        title: const Text('Mon planning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          _schedules.isEmpty
                              ? 'Aucun créneau configuré'
                              : '${_schedules.length} créneau(x) enregistré(s)',
                          style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                        ),
                        trailing: const Icon(Icons.open_in_new, color: Color(0xFF71717A), size: 18),
                        onTap: () => launchUrl(
                          Uri.parse('https://fast-resto.app/livreur/planning'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF27272A)),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                        title: const Text(
                          'Se déconnecter',
                          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                        ),
                        onTap: () => _logout(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'FAST Livreur · Livraison à domicile',
                    style: TextStyle(color: Color(0xFF52525B), fontSize: 11),
                  ),
                ),
              ],
            ),
    );
  }
}
