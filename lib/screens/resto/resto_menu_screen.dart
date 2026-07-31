import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../models.dart';
import 'menu_ai_scanner_screen.dart';
import 'menu_item_edit_screen.dart';

class RestoMenuScreen extends StatefulWidget {
  const RestoMenuScreen({super.key});

  @override
  State<RestoMenuScreen> createState() => _RestoMenuScreenState();
}

class _RestoMenuScreenState extends State<RestoMenuScreen> {
  String _filter = 'all';

  void _openEdit(BuildContext context, {MenuItem? item}) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MenuItemEditScreen(item: item)),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ajouter un plat',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy,
                      color: Color(0xFF8B5CF6), size: 20),
                ),
                title: const Text('Scanner un menu (IA)',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Import automatique via photo',
                    style: TextStyle(
                        color: Color(0xFFA1A1AA), fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MenuAiScannerScreen()));
                },
              ),
              const Divider(color: Color(0xFF27272A), height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: Color(0xFFF59E0B), size: 20),
                ),
                title: const Text('Ajout manuel',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Créer un plat de zéro',
                    style: TextStyle(
                        color: Color(0xFFA1A1AA), fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _openEdit(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RestoProvider>(
      builder: (context, prov, _) {
        final allItems = prov.menu;
        final categories = ['all', ...{for (final m in allItems) m.category}];
        final filtered = _filter == 'all'
            ? allItems
            : allItems.where((m) => m.category == _filter).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddOptions(context),
            backgroundColor: const Color(0xFFF59E0B),
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text('Ajouter',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          body: prov.menuLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFF59E0B)))
              : allItems.isEmpty
                  ? _buildEmpty(context)
                  : _buildList(context, prov, categories, filtered),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu,
              color: Color(0xFF3F3F46), size: 56),
          const SizedBox(height: 16),
          const Text('Aucun plat dans le menu',
              style: TextStyle(
                  color: Color(0xFFA1A1AA),
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Ajoutez votre premier plat',
              style: TextStyle(color: Color(0xFF71717A), fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openEdit(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF09090B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un plat',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    RestoProvider prov,
    List<String> categories,
    List<MenuItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category filter tabs
        if (categories.length > 2)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final active = cat == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat == 'all' ? 'Tout' : cat,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF09090B)
                            : const Color(0xFFE4E4E7),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Item count
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${items.length} plat${items.length == 1 ? '' : 's'}',
            style: const TextStyle(
                color: Color(0xFF71717A), fontSize: 12),
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildCard(context, prov, items[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
      BuildContext context, RestoProvider prov, MenuItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.available
              ? const Color(0xFF27272A)
              : const Color(0xFF3F3F46),
        ),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              bottomLeft: Radius.circular(10),
            ),
            child: item.image.isNotEmpty
                ? Image.network(
                    item.image,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),

          // Info
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: item.available
                                ? Colors.white
                                : const Color(0xFF71717A),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.available)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF3F3F46),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Indispo',
                              style: TextStyle(
                                  color: Color(0xFF71717A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category,
                    style: const TextStyle(
                        color: Color(0xFF71717A), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '€${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Column(
            children: [
              Switch(
                value: item.available,
                onChanged: (v) =>
                    prov.toggleMenuItemAvailability(item.id, v),
                activeThumbColor: const Color(0xFF10B981),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFFF59E0B), size: 20),
                onPressed: () => _openEdit(context, item: item),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 4),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFF27272A),
      child: const Icon(Icons.restaurant,
          color: Color(0xFF3F3F46), size: 28),
    );
  }
}
