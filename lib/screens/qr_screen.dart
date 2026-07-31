// lib/screens/qr_screen.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models.dart';

/// Shown as a full-screen modal: client shows QR to staff for verification.
class QRVerificationScreen extends StatefulWidget {
  final Order order;
  const QRVerificationScreen({super.key, required this.order});

  @override
  State<QRVerificationScreen> createState() => _QRVerificationScreenState();
}

class _QRVerificationScreenState extends State<QRVerificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final qrData = order.pickupToken ?? order.id;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFFE4E4E7)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Vérification du staff',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Présentez ce QR code au membre du staff au comptoir Click & Collect.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA1A1AA),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF09090B),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF09090B),
                            ),
                          ),
                        ),
                        Positioned(
                          top: (_scanController.value * 220).clamp(0.0, 220.0),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF59E0B).withValues(alpha: 0.0),
                                  const Color(0xFFF59E0B).withValues(alpha: 0.8),
                                  const Color(0xFFF59E0B).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              order.id.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF59E0B),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Valable chez : ${order.restaurantName}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFA1A1AA),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                children: [
                  _summaryRow('Restaurant', order.restaurantName),
                  const SizedBox(height: 8),
                  _summaryRow('Articles', '${order.items.length} article(s)'),
                  const SizedBox(height: 8),
                  _summaryRow('Total', '${order.total.toStringAsFixed(2)} €'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildStatusSection(order.status),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStatusSection(OrderStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case OrderStatus.placed:
        color = Colors.blue;
        label = 'Commandé — Cuisine notifiée';
        icon = Icons.receipt_long;
        break;
      case OrderStatus.preparing:
        color = const Color(0xFFF59E0B);
        label = 'En préparation — Venez !';
        icon = Icons.restaurant_menu;
        break;
      case OrderStatus.readyForPickup:
        color = const Color(0xFF10B981);
        label = 'Prêt — Récupérez maintenant !';
        icon = Icons.check_circle;
        break;
      case OrderStatus.completed:
        color = const Color(0xFF71717A);
        label = 'Récupéré — Bon appétit !';
        icon = Icons.handshake;
        break;
      case OrderStatus.cancelled:
        color = const Color(0xFFEF4444);
        label = 'Annulé';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
