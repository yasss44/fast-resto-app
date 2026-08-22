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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
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
                child: InkWell(
                  onTap: () => _openGoogleMapsDirections(context, rest),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.directions_walk,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Itinéraire à pied (Google Maps)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new,
                          size: 12,
                          color: Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Menu Section
        ...rest.menu.map((m) => m.category.isNotEmpty ? m.category : 'Menu').toSet().map((category) {
          final items = rest.menu
              .where((item) => (item.category.isNotEmpty ? item.category : 'Menu') == category)
              .toList();

          if (items.isEmpty) return const SizedBox.shrink();

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final categoryTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final dividerColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  category,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: categoryTitleColor,
                  ),
                ),
              ),
              ...items.map(
                (item) => _buildMenuItemTile(context, provider, item),
              ),
              Divider(
                color: dividerColor,
                height: 24,
                indent: 16,
                endIndent: 16,
              ),
            ],
          );
        }),

        const SizedBox(height: 100),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF64748B);

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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: titleColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: subColor,
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
                        Text(
                          'Extras dispo.',
                          style: TextStyle(
                            fontSize: 10,
                            color: subColor,
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
                  child: item.image.isNotEmpty
                      ? Image.network(
                          item.image,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.restaurant, color: Color(0xFFF59E0B), size: 28),
                          ),
                        )
                      : Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.restaurant, color: Color(0xFFF59E0B), size: 28),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
    final chipBg = isDark ? const Color(0xFF09090B) : const Color(0xFFF1F5F9);
    final chipBorder = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0);
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: sheetBg,
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: subColor,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 16),

                          // Free options — no extra charge
                          Text(
                            'Options',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: selectedFree.contains(option)
                                            ? const Color(0xFF09090B)
                                            : titleColor,
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
                                    selectedColor: const Color(0xFFF59E0B),
                                    backgroundColor: chipBg,
                                    side: BorderSide(
                                      color: selectedFree.contains(option)
                                          ? const Color(0xFFF59E0B)
                                          : chipBorder,
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
                            Text(
                              'SUPPLÉMENTS & EXTRAS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: subColor,
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
                                        '+${s.name} (+${s.price.toStringAsFixed(2)} €)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: selectedPaid.contains(s.id)
                                              ? const Color(0xFFF59E0B)
                                              : titleColor,
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
                                      backgroundColor: chipBg,
                                      side: BorderSide(
                                        color: selectedPaid.contains(s.id)
                                            ? const Color(0xFFF59E0B)
                                            : chipBorder,
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
                          Text(
                            'ALLERGIES / NOTES',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: subColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: textController,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: 12,
                              color: titleColor,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'ex. Allergie aux noix, sans lactose...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: chipBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: borderColor,
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
                          color: chipBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
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
                              icon: const Icon(
                                Icons.remove,
                                size: 16,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            Text(
                              '$qty',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: titleColor,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setModalState(() {
                                  qty++;
                                });
                              },
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Add Button
                      Expanded(
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
    final colors = _categoryColors(rest.category, rest.name);
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
          _categoryEmoji(rest.category, rest.name),
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

  List<Color> _categoryColors(String category, [String name = '']) {
    final s = '${category.toLowerCase()} ${name.toLowerCase()}';
    if (s.contains('burger')) return [const Color(0xFF9A3412), const Color(0xFFD97706)];
    if (s.contains('pizza') || s.contains('italien')) return [const Color(0xFF991B1B), const Color(0xFFDC2626)];
    if (s.contains('sushi') || s.contains('asiat') || s.contains('japan') || s.contains('chine')) return [const Color(0xFF0369A1), const Color(0xFF0284C7)];
    if (s.contains('taco') || s.contains('mexic')) return [const Color(0xFF4D7C0F), const Color(0xFF65A30D)];
    if (s.contains('salad') || s.contains('health') || s.contains('vegan')) return [const Color(0xFF15803D), const Color(0xFF16A34A)];
    if (s.contains('bistro') || s.contains('french') || s.contains('petite')) return [const Color(0xFF1E40AF), const Color(0xFF3B82F6)];
    if (s.contains('dessert') || s.contains('patiss') || s.contains('sucr') || s.contains('crepe')) return [const Color(0xFF9333EA), const Color(0xFFA855F7)];
    return [const Color(0xFF374151), const Color(0xFF4B5563)];
  }

  String _categoryEmoji(String category, [String name = '']) {
    final s = '${category.toLowerCase()} ${name.toLowerCase()}';
    if (s.contains('burger')) return '🍔';
    if (s.contains('pizza') || s.contains('italien')) return '🍕';
    if (s.contains('sushi') || s.contains('asiat') || s.contains('japan') || s.contains('chine')) return '🍣';
    if (s.contains('taco') || s.contains('mexic')) return '🌮';
    if (s.contains('salad') || s.contains('health') || s.contains('vegan')) return '🥗';
    if (s.contains('bistro') || s.contains('french') || s.contains('petite')) return '🥘';
    if (s.contains('dessert') || s.contains('patiss') || s.contains('sucr') || s.contains('crepe')) return '🍰';
    return '🍽️';
  }
}
