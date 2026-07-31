import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../models.dart';
import '../../services/order_service.dart';

class RestoOrdersScreen extends StatefulWidget {
  const RestoOrdersScreen({super.key});

  @override
  State<RestoOrdersScreen> createState() => _RestoOrdersScreenState();
}

class _RestoOrdersScreenState extends State<RestoOrdersScreen> {
  Timer? _uiTimer;
  final _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    // Refresh UI every second for countdown timers
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _acceptOrder(Order order, RestoProvider rProv) async {
    try {
      await _orderService.updateOrderStatus(order.id, 'PREPARING');
      order.status = OrderStatus.preparing;
      order.prepStartedAt = DateTime.now().toIso8601String();
      final prepTimeMin = rProv.isRushMode
        ? (rProv.settings?.rushPrepTime ?? 25)
        : (rProv.settings?.normalPrepTime ?? 15);
      order.prepTimerSeconds = prepTimeMin * 60;
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'acceptation')),
        );
      }
    }
  }

  Future<void> _markReady(Order order) async {
    try {
      await _orderService.updateOrderStatus(order.id, 'READY_FOR_PICKUP');
      order.status = OrderStatus.readyForPickup;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _refuseOrder(Order order) async {
    try {
      await _orderService.updateOrderStatus(order.id, 'CANCELLED');
      order.status = OrderStatus.cancelled;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _cancelOrder(Order order, bool billAnyway) async {
    try {
      await _orderService.updateOrderStatus(order.id, 'CANCELLED');
      order.status = OrderStatus.cancelled;
      order.isBilledAnyway = billAnyway;
      setState(() {});
    } catch (_) {}
  }

  void _showQrScanDialog(Order order) {
    final controller = MobileScannerController();
    var handled = false;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Scanner QR client', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          height: 280,
          width: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) async {
                if (handled) return;
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code == null || code.isEmpty) return;
                handled = true;
                Navigator.pop(dialogContext);
                await _verifyPickup(order, code);
                controller.dispose();
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Annuler', style: TextStyle(color: Color(0xFFA1A1AA))),
          ),
        ],
      ),
    ).whenComplete(() => controller.dispose());
  }

  Future<void> _verifyPickup(Order order, String token) async {
    try {
      final updated = await _orderService.verifyPickup(
        orderId: order.id,
        pickupToken: token,
      );
      order.status = updated.status;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remise confirmée ✓')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR invalide ou erreur de vérification')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rProv = Provider.of<RestoProvider>(context);

    final activeOrders = rProv.restoOrders.where((o) => o.status == OrderStatus.placed || o.status == OrderStatus.preparing || o.status == OrderStatus.readyForPickup).toList();
    final billedCancelledOrders = rProv.restoOrders.where((o) => o.status == OrderStatus.cancelled && o.isBilledAnyway).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Commandes en cours', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('En direct', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activeOrders.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Aucune commande active', style: TextStyle(color: Color(0xFFA1A1AA))),
            )),
          ...activeOrders.map((o) => _buildOrderCard(o, rProv)),

          if (billedCancelledOrders.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Divider(color: Color(0xFF27272A)),
            const SizedBox(height: 16),
            const Text('Annulées (Facturées)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...billedCancelledOrders.map((o) => _buildCancelledCard(o)),
          ]
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, RestoProvider rProv) {
    String timerText = '--:--';
    if (order.status == OrderStatus.preparing && order.prepStartedAt != null) {
      final start = DateTime.parse(order.prepStartedAt!);
      final elapsed = DateTime.now().difference(start).inSeconds;
      final remaining = order.prepTimerSeconds - elapsed;
      if (remaining > 0) {
        final m = (remaining / 60).floor().toString().padLeft(2, '0');
        final s = (remaining % 60).toString().padLeft(2, '0');
        timerText = '$m:$s';
      } else {
        timerText = 'EN RETARD';
      }
    }

    Color statusColor = const Color(0xFF3F3F46);
    if (order.status == OrderStatus.placed) statusColor = const Color(0xFF10B981);
    if (order.status == OrderStatus.preparing) statusColor = const Color(0xFFF59E0B);
    if (order.status == OrderStatus.readyForPickup) statusColor = const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('#${order.id.split('-').last}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    if (order.groupCode != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.groupCode!,
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(order.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.quantity}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.menuItem.name, style: const TextStyle(color: Colors.white)),
                            if (item.selectedOptions.isNotEmpty)
                              Text(item.selectedOptions.join(', '), style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                            if (item.allergyNotes.isNotEmpty)
                              Text('Note: ${item.allergyNotes}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(color: Color(0xFF27272A), height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total: €${order.total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (order.status == OrderStatus.preparing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF09090B), borderRadius: BorderRadius.circular(8)),
                        child: Text(timerText, style: const TextStyle(color: Color(0xFFF59E0B), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (order.status == OrderStatus.placed)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptOrder(order, rProv),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                          child: const Text('Accepter'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _refuseOrder(order),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444))),
                        child: const Text('Refuser'),
                      ),
                    ],
                  ),
                
                if (order.status == OrderStatus.preparing)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _markReady(order),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                          child: const Text('Prêt à servir'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _cancelOrder(order, true),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444))),
                        child: const Text('Annuler (Facturé)'),
                      ),
                    ],
                  ),

                if (order.status == OrderStatus.readyForPickup)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_walk, color: Color(0xFF3B82F6), size: 16),
                            SizedBox(width: 6),
                            Text('Client en route — attendez le scan', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showQrScanDialog(order),
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          label: const Text('Scanner le QR du client', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('#${order.id.split('-').last}', style: const TextStyle(color: Color(0xFFA1A1AA))),
          Text('€${order.total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
