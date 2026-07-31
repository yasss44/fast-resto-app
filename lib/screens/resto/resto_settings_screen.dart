import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../resto_provider.dart';
import '../../models.dart';
import '../../services/restaurant_service.dart';
import '../../services/payment_service.dart';

class RestoSettingsScreen extends StatefulWidget {
  const RestoSettingsScreen({super.key});

  @override
  State<RestoSettingsScreen> createState() => _RestoSettingsScreenState();
}

class _RestoSettingsScreenState extends State<RestoSettingsScreen> {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String _imageBase64 = '';

  double _normalPrepTime = 15;
  double _rushPrepTime = 25;
  List<String> _selectedDietary = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _restaurantId;

  final _paymentService = PaymentService();
  Map<String, dynamic>? _connectStatus;
  bool _connectLoading = false;

  static const _dietaryAll = [
    'VEGAN', 'VEGETARIAN', 'GLUTEN_FREE', 'HALAL', 'KETO', 'DAIRY_FREE',
  ];
  static const _dietaryLabels = {
    'VEGAN': 'Végétalien',
    'VEGETARIAN': 'Végétarien',
    'GLUTEN_FREE': 'Sans Gluten',
    'HALAL': 'Halal',
    'KETO': 'Céto',
    'DAIRY_FREE': 'Sans Lactose',
  };

  static const _categories = [
    'Burgers', 'Pizza', 'Sushi', 'Tacos', 'Sandwichs',
    'Salades', 'Pâtes', 'Poulet', 'Végétarien', 'Desserts',
  ];

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _loadConnectStatus();
  }

  Future<void> _loadConnectStatus() async {
    setState(() => _connectLoading = true);
    try {
      final status = await _paymentService.getConnectStatus();
      if (mounted) setState(() => _connectStatus = status);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  Future<void> _configureStripeConnect() async {
    setState(() => _connectLoading = true);
    try {
      final link = await _paymentService.createConnectAccountLink();
      final url = link['url'] as String?;
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      await _loadConnectStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stripe Connect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  Future<void> _loadFromBackend() async {
    try {
      final svc = RestaurantService();
      final data = await svc.getMyRestaurant();
      if (!mounted) return;
      setState(() {
        _restaurantId = data['id'] as String?;
        _nameCtrl.text = data['name'] as String? ?? '';
        _descCtrl.text = data['description'] as String? ?? '';
        _cuisineCtrl.text = data['cuisineType'] as String? ?? '';
        _categoryCtrl.text = data['category'] as String? ?? '';
        _cityCtrl.text = data['city'] as String? ?? '';
        _addressCtrl.text = data['address'] as String? ?? '';
        _ibanCtrl.text = data['managerIban'] as String? ?? '';
        _imageBase64 = data['image'] as String? ?? '';
        _normalPrepTime = ((data['normalPrepTime'] as num?)?.toDouble()) ?? 15;
        _rushPrepTime = ((data['rushPrepTime'] as num?)?.toDouble()) ?? 25;
        final opts = data['dietaryOptions'] as List<dynamic>? ?? [];
        _selectedDietary = opts.map((e) {
          if (e is String) return e;
          if (e is Map<String, dynamic>) return e['option'] as String? ?? '';
          return '';
        }).where((s) => s.isNotEmpty).toList();
        _loading = false;
      });
    } catch (e) {
      // Fall back to locally cached settings
      if (!mounted) return;
      final cached = Provider.of<RestoProvider>(context, listen: false).settings;
      setState(() {
        _restaurantId = cached?.id;
        _nameCtrl.text = cached?.name ?? '';
        _descCtrl.text = cached?.description ?? '';
        _cuisineCtrl.text = cached?.cuisineType ?? '';
        _categoryCtrl.text = cached?.category ?? '';
        _cityCtrl.text = cached?.city ?? '';
        _addressCtrl.text = cached?.address ?? '';
        _ibanCtrl.text = cached?.managerIban ?? '';
        _imageBase64 = cached?.image ?? '';
        _normalPrepTime = (cached?.normalPrepTime ?? 15).toDouble();
        _rushPrepTime = (cached?.rushPrepTime ?? 25).toDouble();
        _selectedDietary = cached?.dietaryOptions ?? [];
        _loading = false;
        _error = 'Impossible de charger depuis le serveur. Données locales affichées.';
      });
    }
  }

  Future<void> _save() async {
    if (_restaurantId == null) {
      setState(() => _error = 'Aucun restaurant trouvé.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'cuisineType': _cuisineCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'managerIban': _ibanCtrl.text.trim(),
      if (_imageBase64.isNotEmpty) 'image': _imageBase64,
      'normalPrepTime': _normalPrepTime.round(),
      'rushPrepTime': _rushPrepTime.round(),
      'dietaryOptions': _selectedDietary,
    };

    try {
      final svc = RestaurantService();
      await svc.updateRestaurant(_restaurantId!, body);

      // Update local cache
      if (!mounted) return;
      final provider = Provider.of<RestoProvider>(context, listen: false);
      await provider.updateSettings(RestaurantSettings(
        id: _restaurantId,
        managerFirstName: provider.settings?.managerFirstName ?? '',
        managerPhone: provider.settings?.managerPhone ?? '',
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        cuisineType: _cuisineCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        managerIban: _ibanCtrl.text.trim(),
        image: _imageBase64,
        normalPrepTime: _normalPrepTime.round(),
        rushPrepTime: _rushPrepTime.round(),
        dietaryOptions: _selectedDietary,
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: const Text('Profil mis à jour ✓',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ));
    } catch (e) {
      setState(() => _error = 'Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cuisineCtrl.dispose();
    _categoryCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        const Text('Profil Restaurant',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Ces informations sont visibles par vos clients.',
            style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
            ),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          ),
        ],

        const SizedBox(height: 24),
        _section('Paiements Stripe Connect'),
        _buildStripeConnectBanner(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _connectLoading ? null : _configureStripeConnect,
          icon: const Icon(Icons.account_balance),
          label: const Text('Configurer Stripe Connect'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF59E0B),
            side: const BorderSide(color: Color(0xFFF59E0B)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: 24),
        _section('Image de couverture'),
        _buildImagePicker(),

        const SizedBox(height: 24),
        _section('Identité'),
        _field('Nom du restaurant *', _nameCtrl),
        _field('Description', _descCtrl, maxLines: 3,
            hint: 'Décrivez votre restaurant, votre spécialité...'),

        const SizedBox(height: 24),
        _section('Coordonnées & Banque'),
        _field('Ville', _cityCtrl),
        _field('Adresse complète', _addressCtrl, hint: '12 rue des Lilas, 75001 Paris'),
        _field('IBAN', _ibanCtrl, hint: 'FR76 **** **** **** **** 1234'),

        const SizedBox(height: 24),
        _section('Cuisine & Catégorie'),
        _field('Type de cuisine', _cuisineCtrl, hint: 'ex: Française, Japonaise, Italienne'),
        const SizedBox(height: 8),
        _dropdownField('Catégorie', _categoryCtrl, _categories),

        const SizedBox(height: 24),
        _section('Options alimentaires'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dietaryAll.map((key) {
            final selected = _selectedDietary.contains(key);
            return FilterChip(
              label: Text(_dietaryLabels[key] ?? key,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? const Color(0xFF09090B) : const Color(0xFFA1A1AA),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  )),
              selected: selected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedDietary = [..._selectedDietary, key];
                  } else {
                    _selectedDietary = _selectedDietary.where((k) => k != key).toList();
                  }
                });
              },
              selectedColor: const Color(0xFFF59E0B),
              backgroundColor: const Color(0xFF18181B),
              checkmarkColor: const Color(0xFF09090B),
              side: BorderSide(
                color: selected ? const Color(0xFFF59E0B) : const Color(0xFF3F3F46),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        _section('Temps de Préparation'),
        _timeSlider('Temps Normal', _normalPrepTime, 5, 60,
            const Color(0xFFF59E0B), (v) => setState(() => _normalPrepTime = v)),
        const SizedBox(height: 20),
        _timeSlider('Temps Mode Rush', _rushPrepTime, 10, 90,
            const Color(0xFFEF4444), (v) => setState(() => _rushPrepTime = v)),

        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),

        const SizedBox(height: 32),
        const Divider(color: Color(0xFF27272A)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Provider.of<RestoProvider>(context, listen: false).clearAllSettingsAndRestart(),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Déconnexion & Reset'),
        ),
      ],
    );
  }

  Widget _buildStripeConnectBanner() {
    if (_connectLoading && _connectStatus == null) {
      return const LinearProgressIndicator(color: Color(0xFFF59E0B));
    }
    final connected = _connectStatus?['connected'] as bool? ?? false;
    final chargesEnabled = _connectStatus?['chargesEnabled'] as bool? ?? false;
    final ok = connected && chargesEnabled;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.info_outline,
            color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ok
                  ? 'Stripe Connect actif — paiements activés'
                  : connected
                      ? 'Compte connecté — finalisez l’activation des paiements'
                      : 'Stripe Connect non configuré — requis pour recevoir les paiements',
              style: TextStyle(
                color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      );

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () async {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          });
        }
      },
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3F3F46)),
          image: _imageBase64.isNotEmpty
              ? DecorationImage(
                  image: _imageBase64.startsWith('http')
                      ? NetworkImage(_imageBase64)
                      : MemoryImage(base64Decode(_imageBase64.split(',').last)) as ImageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _imageBase64.isEmpty
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: Color(0xFFA1A1AA), size: 40),
                  SizedBox(height: 12),
                  Text('Ajouter une photo', style: TextStyle(color: Color(0xFFA1A1AA))),
                ],
              )
            : Container(
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => setState(() => _imageBase64 = ''),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
          hintStyle: const TextStyle(color: Color(0xFF52525B), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF18181B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3F3F46)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3F3F46)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF59E0B)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _dropdownField(String label, TextEditingController ctrl, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(ctrl.text) ? ctrl.text : null,
        hint: Text('Sélectionner', style: const TextStyle(color: Color(0xFF52525B), fontSize: 13)),
        dropdownColor: const Color(0xFF18181B),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF18181B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3F3F46)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3F3F46)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF59E0B)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        items: options
            .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(o, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ))
            .toList(),
        onChanged: (v) => setState(() => ctrl.text = v ?? ''),
      ),
    );
  }

  Widget _timeSlider(String title, double value, double min, double max,
      Color color, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${value.round()} min',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
            activeTrackColor: color,
            inactiveTrackColor: const Color(0xFF27272A),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / 5).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
