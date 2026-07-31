// lib/widgets/notification_center.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';

class NotificationCenter extends StatelessWidget {
  const NotificationCenter({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final notifications = provider.notifications;

    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    if (notifications.any((n) => !n.isRead))
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFFA1A1AA)),
                ),
              ],
            ),
            const Divider(color: Color(0xFF27272A), height: 24),
            
            // Notifications List
            Expanded(
              child: NotificationCenterList(provider: provider),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationCenterList extends StatelessWidget {
  final FASTProvider? provider;
  const NotificationCenterList({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    final activeProvider = provider ?? Provider.of<FASTProvider>(context);
    final notifications = activeProvider.notifications;

    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                size: 48,
                color: Color(0xFF27272A),
              ),
              const SizedBox(height: 12),
              const Text(
                'Vous êtes à jour !',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFFA1A1AA),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Les notifications sur le statut de vos commandes apparaîtront ici.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF71717A),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF27272A),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getIconColor(notif.type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIcon(notif.type),
                        color: _getIconColor(notif.type),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                notif.timestamp,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif.body,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFA1A1AA),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(color: Color(0xFF27272A), height: 24),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              activeProvider.clearNotifications();
            },
            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
            label: const Text(
              'Tout effacer',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline;
      case 'status':
        return Icons.restaurant_menu_outlined;
      case 'rating':
        return Icons.star_border_outlined;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'success':
        return const Color(0xFF10B981); // Emerald 500
      case 'status':
        return const Color(0xFFF59E0B); // Amber 500
      case 'rating':
        return const Color(0xFF3B82F6); // Blue 500
      case 'info':
      default:
        return const Color(0xFFA1A1AA); // Muted grey
    }
  }
}
