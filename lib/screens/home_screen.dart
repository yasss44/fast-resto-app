// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    
    // Sync text controller with search state
    if (provider.searchKeyword != _searchController.text && !_isFocusingSearch) {
      _searchController.text = provider.searchKeyword;
    }

    final filteredRest = provider.getFilteredRestaurants();
    final suggCategories = provider.getAutocompleteCategories();
    final isSearching = provider.searchKeyword.isNotEmpty;

    return Stack(
      children: [
        Column(
          children: [
            // Search Bar (full width — no ASAP pill)
            Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                color: isDark ? const Color(0xFF09090B) : Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Search field — full width
                        Expanded(
                          child: Focus(
                            onFocusChange: (focus) {
                              setState(() {
                                _isFocusingSearch = focus;
                              });
                            },
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => provider.setKeyword(val),
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Rechercher des cuisines, des plats, des spécialités...',
                                hintStyle: const TextStyle(color: Color(0xFF71717A)),
                                prefixIcon: const Icon(Icons.search, color: Color(0xFF71717A), size: 18),
                                suffixIcon: provider.searchKeyword.isNotEmpty
                                    ? IconButton(
                                        onPressed: () {
                                          provider.setKeyword('');
                                          _searchController.clear();
                                        },
                                        icon: const Icon(Icons.close, color: Color(0xFF71717A), size: 16),
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            // Autocomplete Suggestions Panel OR Main Page Content
            Expanded(
              child: isSearching
                  ? _buildSuggestionsPanel(context, provider, suggCategories)
                  : _buildMainContent(context, provider, filteredRest),
            ),
          ],
        ),

        // Slot Machine Selection Overlay
        if (provider.isSurpriseMeRolling)
          _buildSlotsOverlay(context, provider),
      ],
    );
  }

  bool _isFocusingSearch = false;

  // Split suggestion layout
  Widget _buildSuggestionsPanel(
      BuildContext context, FASTProvider provider, List<CategoryItem> suggCategories) {
    final kw = provider.searchKeyword.toLowerCase();
    
    // Find matching dishes
    final List<Map<String, dynamic>> matchingDishes = [];
    final List<Restaurant> matchingRestaurants = [];

    for (var r in provider.restaurants) {
      bool matchedRest = r.name.toLowerCase().contains(kw) || r.description.toLowerCase().contains(kw);
      if (matchedRest) {
        matchingRestaurants.add(r);
      }
      for (var d in r.menu) {
        if (d.name.toLowerCase().contains(kw) || d.description.toLowerCase().contains(kw)) {
          matchingDishes.add({'restaurant': r, 'item': d});
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA);
    final chipBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final chipBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);

    return Container(
      color: panelBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Categories Autocomplete Suggestions
          if (suggCategories.isNotEmpty) ...[
            Text(
              'CATÉGORIES CORRESPONDANTES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: subColor,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: suggCategories.length,
                itemBuilder: (context, index) {
                  final cat = suggCategories[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: chipBg,
                      side: BorderSide(color: chipBorder),
                      avatar: Text(cat.icon),
                      label: Text(
                        cat.name,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        provider.setCategory(cat.id);
                        provider.setKeyword(''); // Clear search to reveal category list
                        _searchController.clear();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section 2: Matching Kitchens & Dishes List
          Text(
            'CUISINES & PLATS CORRESPONDANTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: subColor,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: (matchingRestaurants.isEmpty && matchingDishes.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '🥙',
                          style: TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun article trouvé',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Essayez de rechercher burger, pizza, wrap, salade, etc.',
                          style: TextStyle(
                            fontSize: 10,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      // Restaurants results
                      if (matchingRestaurants.isNotEmpty) ...[
                        ...matchingRestaurants.map((r) => ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: r.image.isNotEmpty
                                    ? Image.network(
                                        r.image,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          color: const Color(0xFFF59E0B),
                                          width: 40,
                                          height: 40,
                                          alignment: Alignment.center,
                                          child: Text(_categoryEmoji(r.category, r.name), style: const TextStyle(fontSize: 18)),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFF59E0B),
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        child: Text(_categoryEmoji(r.category, r.name), style: const TextStyle(fontSize: 18)),
                                      ),
                              ),
                              title: Text(
                                r.name,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                              ),
                              subtitle: Text(
                                '${r.pickupPrepTime} min prép • ${provider.getRealDistance(r).toStringAsFixed(1)} km',
                                style: TextStyle(fontSize: 11, color: subColor),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF71717A)),
                              onTap: () {
                                provider.selectRestaurant(r.id);
                                provider.navigateToScreen('restaurant');
                              },
                            )),
                      ],
                      // Dishes results
                      if (matchingDishes.isNotEmpty) ...[
                        ...matchingDishes.map((data) {
                          final Restaurant r = data['restaurant'];
                          final MenuItem item = data['item'];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.image.isNotEmpty
                                  ? Image.network(
                                      item.image,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        color: const Color(0xFFF59E0B),
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.restaurant, size: 20, color: Color(0xFF09090B)),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFF59E0B),
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.restaurant, size: 20, color: Color(0xFF09090B)),
                                    ),
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                            ),
                            subtitle: Text(
                              'De : ${r.name} • ${item.price.toStringAsFixed(2)} €',
                              style: TextStyle(fontSize: 11, color: subColor),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Commander',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            onTap: () {
                              provider.selectRestaurant(r.id);
                              provider.navigateToScreen('restaurant');
                            },
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Normal landing page contents
  Widget _buildMainContent(
      BuildContext context, FASTProvider provider, List<Restaurant> filteredRest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final countColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Bento/Actionable Carousel Banners
        _buildActionableBanners(context, provider),
        
        const SizedBox(height: 16),
        
        // Category Browsing Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Catégories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: sectionTitleColor,
                ),
              ),
              if (provider.selectedCategory != 'all')
                GestureDetector(
                  onTap: () => provider.resetFilters(),
                  child: const Text(
                    'Effacer le filtre',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCategoryGrid(context, provider),

        const SizedBox(height: 20),

        // Kitchen list section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Restaurants',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: sectionTitleColor,
                ),
              ),
              Text(
                '${filteredRest.length} établissements disponibles',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: countColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // List of Restaurants
        filteredRest.isEmpty
            ? _buildNoKitchens(context, provider)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredRest.length,
                  itemBuilder: (context, index) {
                    final rest = filteredRest[index];
                    return _buildRestaurantCard(context, provider, rest);
                  },
                ),
              ),
        
        const SizedBox(height: 80), // bottom offset for basket
      ],
    );
  }

  // Actionable Banners
  Widget _buildActionableBanners(BuildContext context, FASTProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Banner 1: Coupon deal
          GestureDetector(
            onTap: () {
              provider.setKeyword('burger');
              provider.setCategory('burger');
            },
            child: Container(
              width: 280,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Opacity(
                      opacity: 0.15,
                      child: const Text(
                        '🍔',
                        style: TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF09090B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OFFRE EXPRESS',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Envie de burgers ? Économisez 5 € !',
                        style: TextStyle(
                          color: Color(0xFF09090B),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Code : VELVET5',
                            style: TextStyle(
                              color: Color(0xFF09090B),
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF09090B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'Profiter',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Banner 2: Surprise Me Action
          GestureDetector(
            onTap: () => provider.triggerSurpriseMe(context),
            child: Container(
              width: 280,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Opacity(
                      opacity: 0.1,
                      child: const Text(
                        '🎯',
                        style: TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AIDE À LA DÉCISION',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Indécis ? Laissez-nous choisir votre repas.',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Découverte aléatoire',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF71717A) : const Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'Surprenez-moi',
                                  style: TextStyle(
                                    color: Color(0xFF09090B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.shuffle, size: 12, color: Color(0xFF09090B)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Banner 3: Quick timing guarantee
          GestureDetector(
            onTap: () {
              provider.setKeyword('sushi');
            },
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C1D1A) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E3A34) : const Color(0xFFD1FAE5),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Opacity(
                      opacity: 0.1,
                      child: const Text(
                        '🍣',
                        style: TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VITESSE VÉRIFIÉE',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Retrait sous 15 minutes garanti.',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Découvrez les sushis locaux',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F2937) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'Explorer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Categories Grid
  Widget _buildCategoryGrid(BuildContext context, FASTProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final inactiveBorder = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0);
    final inactiveTextColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF475569);

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.categories.length,
        itemBuilder: (context, index) {
          final cat = provider.categories[index];
          final isActive = provider.selectedCategory == cat.id;
          return GestureDetector(
            onTap: () => provider.setCategory(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFF59E0B) : inactiveBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? const Color(0xFFF59E0B) : inactiveBorder,
                  width: 1,
                ),
                boxShadow: (!isActive && !isDark)
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? const Color(0xFF09090B) : inactiveTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Category-colored banner placeholder — used when restaurant has no banner image
  Widget _buildBannerPlaceholder(Restaurant rest) {
    final colors = _categoryColors(rest.category, rest.name);
    return Container(
      height: 180,
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
          style: const TextStyle(fontSize: 56),
        ),
      ),
    );
  }

  // Letter-based logo placeholder — amber circle with first letter
  Widget _buildLogoPlaceholder(String name) {
    return Container(
      color: const Color(0xFFF59E0B),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'R',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
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

  // Restaurant card widget
  Widget _buildRestaurantCard(BuildContext context, FASTProvider provider, Restaurant rest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF64748B);
    final badgeBg = isDark ? const Color(0xFF09090B) : const Color(0xFFF1F5F9);
    final tagBorder = isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1);

    return GestureDetector(
      onTap: () {
        provider.selectRestaurant(rest.id);
        provider.navigateToScreen('restaurant');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image — taller
            Stack(
              children: [
                rest.image.isNotEmpty
                    ? Image.network(
                        rest.image,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildBannerPlaceholder(rest),
                      )
                    : _buildBannerPlaceholder(rest),
                // Bottom gradient fade into card color
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Rating badge — top right
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 13),
                        const SizedBox(width: 3),
                        Text(
                          '${rest.rating}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Time + distance — bottom left
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF09090B) : Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, color: Color(0xFFF59E0B), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${rest.pickupPrepTime} min',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_rounded, color: Color(0xFFA1A1AA), size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${provider.getRealDistance(rest).toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFA1A1AA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Text info row with Restaurant Logo Avatar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Logo Avatar
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rest.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rest.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: subColor,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rest.dietaryOptions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 5,
                            children: rest.dietaryOptions.take(3).map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: tagBorder),
                                ),
                                child: Text(
                                  tag.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: subColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Quick order CTA arrow
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Color(0xFF09090B),
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

  Widget _buildNoKitchens(BuildContext context, FASTProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Text('🥙', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Aucune cuisine trouvée',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Essayez de supprimer les restrictions alimentaires ou de modifier les filtres.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.resetFilters(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF09090B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Réinitialiser les filtres', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Slots Reveal animation modal overlay
  Widget _buildSlotsOverlay(BuildContext context, FASTProvider provider) {
    final randRest = provider.surpriseMeRolledRestaurant;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎯',
                style: TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 12),
              const Text(
                'CHOIX DE VOTRE REPAS',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lancement de la machine à sous...',
                style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
              ),
              const SizedBox(height: 24),
              // Surprise-me revolving screen card
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: randRest == null
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              randRest.image,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: Colors.grey, width: 80, height: 80),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            randRest.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
