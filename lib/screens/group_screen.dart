import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../api/api_exceptions.dart';
import '../provider.dart';
import '../providers/auth_provider.dart';
import '../services/group_service.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _service = GroupService();
  final _codeController = TextEditingController();
  Map<String, dynamic>? _group;
  Timer? _refreshTimer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreActiveGroup();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _restoreActiveGroup() async {
    try {
      final provider = context.read<FASTProvider>();
      if (provider.activeGroupId != null) {
        final g = await _service.getGroup(provider.activeGroupId!);
        final status = g['status'] as String? ?? '';
        if (status == 'OPEN' || status == 'LOCKED') {
          await _setGroup(g);
          return;
        } else {
          provider.clearActiveGroup();
        }
      }
      final groups = await _service.getMyGroups();
      final active = groups.firstWhere(
        (g) => g['status'] == 'OPEN' || g['status'] == 'LOCKED',
        orElse: () => <String, dynamic>{},
      );
      if (active.isNotEmpty) {
        await _setGroup(Map<String, dynamic>.from(active));
      }
    } catch (_) {
      // No active group is a valid empty state.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      final id = _group?['id'] as String?;
      if (id != null) _refresh(id, quiet: true);
    });
  }

  Future<void> _setGroup(Map<String, dynamic> data) async {
    if (!mounted) return;
    final previousStatus = _group?['status'] as String?;
    setState(() {
      _group = data;
      _loading = false;
      _error = null;
    });
    context.read<FASTProvider>().setActiveGroup(
      id: data['id'] as String?,
      code: data['code'] as String?,
      restaurantId: data['restaurantId'] as String?,
    );
    _startPolling();
    final status = data['status'] as String? ?? 'OPEN';
    if (status == 'SUBMITTED' && previousStatus != 'SUBMITTED') {
      context.read<FASTProvider>().navigateToScreen('commandes');
    }
  }

  Future<void> _refresh(String id, {bool quiet = false}) async {
    if (!quiet && mounted) setState(() => _loading = true);
    try {
      await _setGroup(await _service.getGroup(id));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (!quiet) _error = _message(e);
        });
      }
    }
  }

  Future<void> _create() async {
    final provider = context.read<FASTProvider>();
    if (provider.restaurants.isEmpty) {
      setState(() => _error = 'Aucun restaurant disponible.');
      return;
    }
    String restaurantId = provider.selectedRestaurant?.id ?? provider.restaurants.first.id;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choisir le restaurant', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Tous les membres commanderont dans ce même restaurant.', style: TextStyle(color: Color(0xFFA1A1AA))),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: restaurantId,
                  dropdownColor: const Color(0xFF27272A),
                  decoration: const InputDecoration(labelText: 'Restaurant', border: OutlineInputBorder()),
                  items: provider.restaurants.map((restaurant) => DropdownMenuItem(
                    value: restaurant.id,
                    child: Text(restaurant.name),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) setSheetState(() => restaurantId = value);
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext, restaurantId),
                    child: const Text('Créer le groupe'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _loading = true);
    try {
      await _setGroup(await _service.createGroup(restaurantId: selected));
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = _message(e); });
    }
  }

  Future<void> _join() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await _setGroup(await _service.joinGroup(_codeController.text.trim().toUpperCase()));
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = _message(e); });
    }
  }

  Future<void> _action(Future<Map<String, dynamic>> Function() callback) async {
    setState(() { _loading = true; _error = null; });
    try {
      await _setGroup(await callback());
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = _message(e); });
    }
  }

  Future<void> _leave() async {
    final id = _group?['id'] as String?;
    if (id == null) return;
    try {
      await _service.leaveGroup(id);
      _refreshTimer?.cancel();
      if (!mounted) return;
      context.read<FASTProvider>().clearActiveGroup();
      setState(() { _group = null; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  void _orderMyPart() {
    final restaurantId = _group?['restaurantId'] as String?;
    if (restaurantId == null) return;
    final provider = context.read<FASTProvider>();
    provider.setActiveGroup(
      id: _group!['id'] as String,
      code: _group!['code'] as String?,
      restaurantId: restaurantId,
    );
    provider.navigateToScreen('restaurant');
  }

  Future<void> _copyInvite() async {
    final code = _group?['code'] as String? ?? '';
    final message = 'Rejoins ma commande FAST Click & Collect avec le code $code sur l\'app FAST !';
    try {
      await Share.share(message, subject: 'Invitation groupe FAST');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation copiée dans le presse-papiers.')),
      );
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Une erreur est survenue. Réessayez.';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA);
    final surface = isDark ? const Color(0xFF18181B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
    }
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Commande en groupe', style: TextStyle(fontWeight: FontWeight.w900, color: titleColor)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final id = _group?['id'] as String?;
          if (id != null) await _refresh(id, quiet: true);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (_error != null) _errorBanner(),
            if (_group == null) _welcome() else _dashboard(),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF7F1D1D).withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFEF4444)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFFCA5A5)),
      const SizedBox(width: 10),
      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5)))),
    ]),
  );

  Widget _welcome() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.groups_2_outlined, color: Color(0xFFF59E0B), size: 36),
            SizedBox(height: 16),
            Text('Un retrait commun, chacun paie sa part', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
            SizedBox(height: 10),
            Text('1. Choisissez un restaurant\n2. Partagez le code\n3. Chacun compose et paie sa part\n4. L’hôte envoie les parts payées ensemble', style: TextStyle(color: Color(0xFFA1A1AA), height: 1.7)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Créer un groupe', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 28),
      const Text('REJOINDRE AVEC UN CODE', style: TextStyle(color: Color(0xFFA1A1AA), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      TextField(
        controller: _codeController,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: 'FAST-XXXXXXXX',
          prefixIcon: const Icon(Icons.key_outlined),
          suffixIcon: IconButton(
            tooltip: 'Rejoindre',
            onPressed: _join,
            icon: const Icon(Icons.arrow_forward),
          ),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _join(),
      ),
    ],
  );

  Widget _dashboard() {
    final group = _group!;
    final members = (group['members'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final authUserId = context.read<AuthProvider>().user?.id;
    final isHost = group['isHost'] as bool? ??
        ((group['hostUserId'] as String?) == authUserId);
    final status = group['status'] as String? ?? 'OPEN';
    final paidCount = members.where((member) => member['paymentStatus'] == 'PAID').length;
    final total = members.fold<double>(0, (sum, member) => sum + ((member['total'] as num?)?.toDouble() ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CODE DU GROUPE', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(group['code'] as String? ?? '', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Copier l’invitation',
              onPressed: _copyInvite,
              icon: const Icon(Icons.share_outlined),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _leave, child: const Text('Quitter')),
          ],
        ),
        const SizedBox(height: 16),
        _progress(status),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF27272A))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summary('Membres', '${members.length}', Icons.people_outline),
              _summary('Parts payées', '$paidCount/${members.length}', Icons.verified_outlined),
              _summary('Total', '${total.toStringAsFixed(2)} €', Icons.receipt_long_outlined),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('PARTICIPANTS', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        ...members.map(_memberCard),
        const SizedBox(height: 20),
        if (status == 'OPEN')
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _orderMyPart,
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Composer et payer ma part'),
            ),
          ),
        if (isHost && status == 'OPEN') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _action(() => _service.lockGroup(group['id'] as String)),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Fermer les invitations'),
          ),
        ],
        if (isHost && status == 'LOCKED') ...[
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: paidCount == 0 ? null : () => _action(() => _service.submitGroup(group['id'] as String)),
              icon: const Icon(Icons.send_outlined),
              label: Text(paidCount == 0 ? 'En attente d’un paiement' : 'Envoyer les $paidCount parts payées'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Les membres non payés ne seront pas envoyés au restaurant.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
        ],
        if (status == 'SUBMITTED')
          const _SubmittedCard(),
      ],
    );
  }

  Widget _progress(String status) {
    const steps = ['OPEN', 'LOCKED', 'SUBMITTED'];
    final current = steps.indexOf(status).clamp(0, 2);
    const labels = ['Invitations', 'Paiements', 'Envoyé'];
    return Row(
      children: List.generate(3, (index) => Expanded(
        child: Column(
          children: [
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index <= current ? const Color(0xFFF59E0B) : const Color(0xFF3F3F46),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Text(labels[index], style: TextStyle(color: index <= current ? Colors.white : const Color(0xFF71717A), fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      )),
    );
  }

  Widget _summary(String label, String value, IconData icon) => Column(children: [
    Icon(icon, color: const Color(0xFFF59E0B), size: 20),
    const SizedBox(height: 6),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 10)),
  ]);

  Widget _memberCard(Map<String, dynamic> member) {
    final user = member['user'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? 'Participant';
    final paymentStatus = member['paymentStatus'] as String? ?? 'DRAFT';
    final paid = paymentStatus == 'PAID';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: paid ? const Color(0xFF10B981).withValues(alpha: 0.18) : const Color(0xFF3F3F46),
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(color: paid ? const Color(0xFF10B981) : Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(
                paid ? 'Part payée' : paymentStatus == 'READY' ? 'Paiement en cours' : 'Compose sa part',
                style: TextStyle(color: paid ? const Color(0xFF10B981) : const Color(0xFFA1A1AA), fontSize: 11),
              ),
            ]),
          ),
          Text('${((member['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} €', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Icon(paid ? Icons.check_circle : Icons.hourglass_empty, color: paid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class _SubmittedCard extends StatelessWidget {
  const _SubmittedCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF064E3B).withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF10B981)),
    ),
    child: const Column(children: [
      Icon(Icons.task_alt, color: Color(0xFF10B981), size: 36),
      SizedBox(height: 10),
      Text('Commande envoyée ensemble', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
      SizedBox(height: 6),
      Text('Le restaurant prépare toutes les parts payées pour un retrait commun.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFA1A1AA), height: 1.4)),
    ]),
  );
}
