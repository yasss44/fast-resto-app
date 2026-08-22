// lib/screens/restaurant_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre/maplibre.dart';
import 'package:url_launcher/url_launcher.dart';
import '../provider.dart';
import '../models.dart';
import '../services/map_helper.dart';

class RestaurantScreen extends StatelessWidget {
  const RestaurantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final rest = provider.selectedRestaurant;

    if (rest == null) {
      return const Center(child: Text('Aucun restaurant sélectionné.'));
    }

    return ListView(
      children: [
        // Restaurant Banner Header
        Stack(
          children: [
              rest.image.isNotEmpty
                ? Image.network(
                    rest.image,
                    height: 220,
                    width: double.infinity,
                    cacheWidth: 500,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildBannerPlaceholder(rest),
                  )
                : _buildBannerPlaceholder(rest),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Back Button
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B).withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    provider.selectRestaurant(null);
                    provider.navigateToScreen('home');
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            // Title & Info
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '⚡ CLICK & COLLECT',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF09090B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: rest.logo.isNotEmpty
                            ? Image.network(
                                rest.logo,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildLogoPlaceholder(rest.name),
                              )
                            : _buildLogoPlaceholder(rest.name),
                      ),
                      Expanded(
                        child: Text(
                          rest.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
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

        // Restaurant Meta Info Section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meta chips
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${rest.rating} (${rest.reviewsCount} avis)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.access_time_filled,
                    color: Color(0xFFA1A1AA),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${rest.pickupPrepTime} min de prép',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFA1A1AA),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${rest.distance} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                rest.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFA1A1AA),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.map, color: Color(0xFF71717A), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rest.address,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF71717A),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mini Map (MapLibre GL + OpenFreeMap)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 130,
                  child: MapLibreMap(
                    options: MapOptions(
                      initStyle: openFreeMapStyle,
                      initCenter: geo(rest.latitude, rest.longitude),
                      initZoom: 15.0,
                      gestures: const MapGestures.none(),
                    ),
                    onEvent: (event) async {
                      if (event case MapEventStyleLoaded()) {
                        await registerMapMarkers(event.style);
                      }
                    },
                    layers: [
                      MarkerLayer(
                        points: [
                          Feature(
                            geometry: Point(geo(rest.latitude, rest.longitude)),
                          ),
                        ],
                        iconImage: 'marker_restaurant',
                        iconSize: 0.2,
                        iconAnchor: IconAnchor.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Ouvrir l’itinéraire à pied dans Google Maps',
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoogleMapsDirections(context, rest),
                    icon: const Icon(Icons.directions_walk, size: 20),
                    label: const Text('ITINÉRAIRE À PIED · GOOGLE MAPS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF09090B),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(color: Color(0xFF27272A), height: 1),

        // Menu title
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'ARTICLES DU MENU',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Color(0xFF71717A),
            ),
          ),
        ),

        // Menu list items
        if (rest.menu.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Aucun article disponible au menu.',
                style: TextStyle(color: Color(0xFF71717A)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rest.menu.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Color(0xFF27272A), height: 1),
            itemBuilder: (context, index) {
              final item = rest.menu[index];
              return _buildMenuItemTile(context, provider, item);
            },
          ),
        const SizedBox(height: 120),
      ],
    );
  }

  Future<void> _openGoogleMapsDirections(
    BuildContext context,
    Restaurant restaurant,
  ) async {
    final latitude = restaurant.latitude;
    final longitude = restaurant.longitude;
    final hasValidCoordinates =
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    final address = restaurant.address.trim();

    if (!hasValidCoordinates && address.isEmpty) {
      _showDirectionsError(
        context,
        'Impossible de calculer l’itinéraire : les coordonnées et l’adresse du restaurant sont indisponibles.',
      );
      return;
    }

    final destination = hasValidCoordinates ? '$latitude,$longitude' : address;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'walking',
    });

    try {
      final didLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!didLaunch && context.mounted) {
        _showDirectionsError(
          context,
          'Impossible d’ouvrir Google Maps. Vérifiez qu’une application de navigation est disponible.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showDirectionsError(
          context,
          'Impossible d’ouvrir Google Maps. Réessayez dans quelques instants.',
        );
      }
    }
  }

  void _showDirectionsError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF27272A),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildMenuItemTile(
    BuildContext context,
    FASTProvider provider,
    MenuItem item,
  ) {
    return InkWell(
      onTap: () => _showAddToCartDialog(context, provider, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF71717A),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '€${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      if (item.supplements.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Extras dispo.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF71717A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Right: image with add button
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.image,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant, color: Color(0xFF3F3F46), size: 28),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -8,
                  right: -8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, color: Color(0xFF09090B), size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Cart customization popup dialog
  void _showAddToCartDialog(
    BuildContext context,
    FASTProvider provider,
    MenuItem item,
  ) {
    final textController = TextEditingController();

    // Free options — no extra charge
    const List<String> freeOptions = [
      'Sans oignons',
      'Sans fromage',
      'Pain sans gluten',
      'Extra épicé',
      'Bien cuit',
      'Peu cuit',
    ];
    final List<String> selectedFree = [];

    // Paid extras from the menu item's supplements (set by restaurant owner)
    final List<String> selectedPaid = [];

    int qty = 1; // quantity counter declared outside builder to persist state

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 8,
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Item Name & Description
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFA1A1AA),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFF27272A), height: 1),
                          const SizedBox(height: 16),

                          // Free options — no extra charge
                          const Text(
                            'Options',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: freeOptions
                                .map(
                                  (option) => FilterChip(
                                    label: Text(
                                      option,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                    selected: selectedFree.contains(option),
                                    onSelected: (val) {
                                      setModalState(() {
                                        if (val) {
                                          selectedFree.add(option);
                                        } else {
                                          selectedFree.remove(option);
                                        }
                                      });
                                    },
                                    backgroundColor: const Color(0xFF09090B),
                                    side: BorderSide(
                                      color: selectedFree.contains(option)
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF3F3F46),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),

                          // Paid supplements — from item.supplements
                          if (item.supplements.isNotEmpty) ...[
                            const Text(
                              'Suppléments',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: item.supplements
                                  .map(
                                    (s) => FilterChip(
                                      label: Text(
                                        '${s.name} (+${s.price.toStringAsFixed(2)}€)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                      selected: selectedPaid.contains(s.id),
                                      onSelected: (val) {
                                        setModalState(() {
                                          if (val) {
                                            selectedPaid.add(s.id);
                                          } else {
                                            selectedPaid.remove(s.id);
                                          }
                                        });
                                      },
                                      backgroundColor: const Color(0xFF09090B),
                                      side: BorderSide(
                                        color: selectedPaid.contains(s.id)
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF3F3F46),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Allergy notes multiline field
                          const Text(
                            'ALLERGIES / NOTES',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Color(0xFF71717A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: textController,
                            maxLines: 3,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'ex. Allergie aux noix, sans lactose...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF09090B),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantity picker & Add Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Qty Counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF09090B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (qty > 1) {
                                  setModalState(() {
                                    qty--;
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove, size: 16),
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setModalState(() {
                                  qty++;
                                });
                              },
                              icon: const Icon(Icons.add, size: 16),
                            ),
                          ],
                        ),
                      ),
                      // Add Button
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Builder(
                            builder: (ctx) {
                              final extrasTotal = selectedPaid.fold(0.0, (
                                sum,
                                id,
                              ) {
                                final s = item.supplements.firstWhere(
                                  (s) => s.id == id,
                                  orElse: () => MenuItemSupplement(
                                    id: '',
                                    name: '',
                                    price: 0,
                                  ),
                                );
                                return sum + s.price;
                              });
                              final total = (item.price + extrasTotal) * qty;
                              final allSelected = [
                                ...selectedFree,
                                ...selectedPaid,
                              ];
                              return ElevatedButton(
                                onPressed: () {
                                  provider.addToCart(
                                    item,
                                    qty,
                                    allSelected,
                                    textController.text.trim(),
                                  );
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: const Color(0xFF09090B),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Ajouter au panier • ${total.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBannerPlaceholder(Restaurant rest) {
    final colors = _categoryColors(rest.category);
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _categoryEmoji(rest.category),
          style: const TextStyle(fontSize: 72),
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(String name) {
    return Container(
      color: const Color(0xFFF59E0B),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'R',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Color(0xFF09090B),
          ),
        ),
      ),
    );
  }

  List<Color> _categoryColors(String category) {
    final c = category.toLowerCase();
    if (c.contains('burger')) return [const Color(0xFF7C2D12), const Color(0xFF92400E)];
    if (c.contains('pizza')) return [const Color(0xFF7F1D1D), const Color(0xFF991B1B)];
    if (c.contains('sushi')) return [const Color(0xFF0C4A6E), const Color(0xFF075985)];
    if (c.contains('taco') || c.contains('mexic')) return [const Color(0xFF365314), const Color(0xFF3F6212)];
    if (c.contains('salad') || c.contains('health')) return [const Color(0xFF14532D), const Color(0xFF166534)];
    if (c.contains('bistro') || c.contains('french')) return [const Color(0xFF1E3A5F), const Color(0xFF1E40AF)];
    return [const Color(0xFF18181B), const Color(0xFF27272A)];
  }

  String _categoryEmoji(String category) {
    final c = category.toLowerCase();
    if (c.contains('burger')) return '🍔';
    if (c.contains('pizza')) return '🍕';
    if (c.contains('sushi')) return '🍣';
    if (c.contains('taco') || c.contains('mexic')) return '🌮';
    if (c.contains('salad') || c.contains('health')) return '🥗';
    if (c.contains('bistro') || c.contains('french')) return '🥘';
    return '🍽️';
  }
}
