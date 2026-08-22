// lib/screens/account_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';
import '../providers/auth_provider.dart';
import '../widgets/notification_center.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA);
    final surface = isDark ? const Color(0xFF18181B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconColor = isDark ? const Color(0xFFE4E4E7) : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: iconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Mon compte',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Profile header
          _buildProfileHeader(provider),

          // Stats row
          _buildStatsRow(provider),

          const SizedBox(height: 4),

          // Tabs
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF27272A))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFF59E0B),
              indicatorWeight: 2,
              labelColor: const Color(0xFFF59E0B),
              unselectedLabelColor: const Color(0xFF71717A),
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Profil'),
                Tab(icon: Icon(Icons.bolt, size: 18), text: 'Points'),
                Tab(icon: Icon(Icons.location_on_outlined, size: 18), text: 'Adresses'),
                Tab(icon: Icon(Icons.notifications_none, size: 18), text: 'Notifs'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfilTab(provider),
                _buildPointsTab(provider),
                _buildAdressesTab(),
                _buildNotifsTab(provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Profile Header ──────────────────────────────────────────────────────────
  Widget _buildProfileHeader(FASTProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              provider.userInitial,
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
                  provider.userName.isNotEmpty ? provider.userName : 'Votre nom',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (provider.userEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    provider.userEmail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.userPoints} PTS · ${provider.membershipLevel}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────────────────────
  Widget _buildStatsRow(FASTProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          _statCell('📦', '${provider.orders.length}', 'Commandes'),
          Container(width: 1, height: 48, color: const Color(0xFF27272A)),
          _statCell('❤️', '0', 'Favoris'),
          Container(width: 1, height: 48, color: const Color(0xFF27272A)),
          _statCell('⚡', '${provider.userPoints}', 'Points'),
        ],
      ),
    );
  }

  Widget _statCell(String icon, String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF71717A)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Profil Tab ──────────────────────────────────────────────────────────────
  Widget _buildProfilTab(FASTProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal info section
          _sectionLabel('INFORMATIONS PERSONNELLES'),
          const SizedBox(height: 4),
          const Text(
            'Commandez en Click & Collect ou en livraison à domicile.',
            style: TextStyle(fontSize: 11, color: Color(0xFF71717A), height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              children: [
                _editableField(
                  label: 'NOM COMPLET',
                  value: provider.userName,
                  hint: 'Non renseigné',
                  onEdit: () => _showEditDialog(
                    context,
                    'Nom complet',
                    provider.userName,
                    (val) => provider.updateProfile(name: val),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF27272A)),
                _editableField(
                  label: 'TÉLÉPHONE',
                  value: provider.userPhone,
                  hint: 'Non renseigné',
                  onEdit: () => _showEditDialog(
                    context,
                    'Téléphone',
                    provider.userPhone,
                    (val) => provider.updateProfile(phone: val),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF27272A)),
                _editableField(
                  label: 'EMAIL',
                  value: provider.userEmail,
                  hint: 'Non renseigné',
                  onEdit: () => _showEditDialog(
                    context,
                    'Email',
                    provider.userEmail,
                    (val) => provider.updateProfile(email: val),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Appearance section
          _sectionLabel('APPARENCE'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.palette_outlined, color: Colors.redAccent, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Thème de l'interface",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Clair, sombre ou selon l\'appareil',
                          style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _themeOption(provider, ThemeMode.system, Icons.phone_android, 'Auto'),
                    const SizedBox(width: 8),
                    _themeOption(provider, ThemeMode.light, Icons.wb_sunny_outlined, 'Clair'),
                    const SizedBox(width: 8),
                    _themeOption(provider, ThemeMode.dark, Icons.nightlight_outlined, 'Sombre'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Session
          _sectionLabel('SESSION'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: ListTile(
              onTap: () => context.read<AuthProvider>().logout(),
              leading: const Icon(Icons.logout, color: Color(0xFFF59E0B), size: 20),
              title: const Text(
                'Se déconnecter',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Danger zone
          _sectionLabel('ZONE DE DANGER'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: ListTile(
              onTap: () => _showDeleteConfirm(context, provider),
              leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
              title: const Text(
                'Supprimer mon compte',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'FAST Client v1.0 · Fait avec ',
                  style: TextStyle(fontSize: 11, color: Color(0xFF52525B)),
                ),
                Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 14),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: Color(0xFF71717A),
      ),
    );
  }

  Widget _editableField({
    required String label,
    required String value,
    required String hint,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF71717A)),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : hint,
                  style: TextStyle(
                    fontSize: 14,
                    color: value.isNotEmpty ? Colors.white : const Color(0xFF52525B),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(Icons.edit_outlined, color: Color(0xFF71717A), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(FASTProvider provider, ThemeMode mode, IconData icon, String label) {
    final selected = provider.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF10B981) : const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : const Color(0xFFA1A1AA), size: 16),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : const Color(0xFFA1A1AA),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String fieldName,
    String currentValue,
    Function(String) onSave, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: Text(
          'Modifier $fieldName',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: fieldName,
            hintStyle: const TextStyle(color: Color(0xFF52525B)),
            filled: true,
            fillColor: const Color(0xFF09090B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF71717A))),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await onSave(controller.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Erreur lors de l\'enregistrement')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF09090B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, FASTProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        title: const Text(
          'Supprimer le compte ?',
          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
        ),
        content: const Text(
          'Toutes vos données (commandes, profil, notifications) seront supprimées. Cette action est irréversible.',
          style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF71717A))),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteAccount();
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Points Tab ──────────────────────────────────────────────────────────────
  Widget _buildPointsTab(FASTProvider provider) {
    final completedOrders = provider.orders
        .where((o) => o.status == OrderStatus.completed)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points balance card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${provider.userPoints} points',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      provider.membershipLevel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Progress to next level
          _buildLevelProgress(provider.userPoints),

          const SizedBox(height: 20),

          _sectionLabel('HISTORIQUE DES POINTS'),
          const SizedBox(height: 8),

          if (completedOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Center(
                child: Text(
                  'Aucun point encore.\nComplétez votre première commande pour gagner des points !',
                  style: TextStyle(fontSize: 12, color: Color(0xFF71717A), height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                children: completedOrders.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final order = entry.value;
                  return Column(
                    children: [
                      if (idx > 0)
                        const Divider(height: 1, color: Color(0xFF27272A)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 14),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.restaurantName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Commande récupérée · ${order.id}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF71717A)),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              '+10 pts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLevelProgress(int pts) {
    int nextThreshold;
    String nextLevel;
    int prevThreshold;

    if (pts < 80) {
      prevThreshold = 0;
      nextThreshold = 80;
      nextLevel = 'FAST Member';
    } else if (pts < 200) {
      prevThreshold = 80;
      nextThreshold = 200;
      nextLevel = 'FAST Gold';
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text(
              'Niveau maximum atteint — FAST Gold !',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFF59E0B)),
            ),
          ],
        ),
      );
    }

    final progress = ((pts - prevThreshold) / (nextThreshold - prevThreshold)).clamp(0.0, 1.0);
    final remaining = nextThreshold - pts;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vers $nextLevel',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '$remaining pts restants',
                style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF27272A),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Adresses Tab ────────────────────────────────────────────────────────────
  Widget _buildAdressesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.location_on_outlined, size: 40, color: Color(0xFF3F3F46)),
                  SizedBox(height: 12),
                  Text(
                    'Aucune adresse enregistrée',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Vos adresses de livraison favorites seront enregistrées ici.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF71717A), height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Notifs Tab ──────────────────────────────────────────────────────────────
  Widget _buildNotifsTab(FASTProvider provider) {
    return NotificationCenterList(provider: provider);
  }
}
