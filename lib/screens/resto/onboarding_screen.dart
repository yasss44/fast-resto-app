import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../models.dart';
import '../../providers/auth_provider.dart';
import '../../api/api_client.dart';
import '../../api/api_config.dart';
import '../../api/api_exceptions.dart';
import 'resto_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // 0: RGPD, 1: Tutorial, 2: Splash, 3: Form
  int _currentStep = -1; // -1 = checking
  bool _checkingBackend = true;
  String? _formError;
  bool _formLoading = false;

  final _formKey = GlobalKey<FormState>();
  String _managerFirstName = '';
  // ignore: prefer_final_fields
  String _managerPhone = '';
  String _restoName = '';
  String _cuisineType = 'Burger';
  String _city = '';
  double _normalPrepTime = 15;
  double _rushPrepTime = 25;

  final List<String> _cuisines = [
    'Burger', 'Pizza', 'Sushi', 'Italien', 'Kebab', 'Bols/Healthy', 'Autre'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final prov = context.read<RestoProvider>();

    // Primary check: does user already have a restaurant on the backend?
    final hasRestaurantOnBackend = await _checkBackendRestaurant(auth, prov);
    if (!mounted) return;

    if (hasRestaurantOnBackend) {
      // Already set up — go straight to dashboard
      _finishOnboarding();
      return;
    }

    // Otherwise run local onboarding steps
    setState(() {
      _checkingBackend = false;
      if (!prov.isRgpdAccepted) {
        _currentStep = 0;
      } else if (!prov.isTutorialDone) {
        _currentStep = 1;
      } else if (!prov.skipSplash) {
        _currentStep = 2;
      } else {
        _currentStep = 3;
      }
    });
  }

  /// Returns true if a restaurant already exists for this user on the backend.
  Future<bool> _checkBackendRestaurant(
      AuthProvider auth, RestoProvider prov) async {
    // 1. Fast path: auth user object already has restaurant data
    if (auth.user?.restaurant != null) {
      final restoId = auth.user!.restaurant!['id'] as String?;
      if (restoId != null) {
        prov.loadFromApi(restaurantId: restoId);
        return true;
      }
    }

    // 2. Try fetching from backend
    try {
      final data = await ApiClient().get(ApiConfig.myRestaurant);
      if (data != null) {
        final restoId = (data as Map<String, dynamic>)['id'] as String?;
        if (restoId != null) {
          prov.loadFromApi(restaurantId: restoId);
          return true;
        }
      }
    } catch (e) {
      // 404 = no restaurant yet, anything else is a network issue but we'll
      // still show the form rather than blocking the user forever.
      if (e is! NotFoundException) {
        // Not a 404 — could be offline; check local settings as fallback
        if (prov.settings != null) return true;
      }
    }
    return false;
  }

  void _nextStep() {
    final prov = context.read<RestoProvider>();
    if (_currentStep == 0) {
      prov.acceptRgpd();
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      prov.completeTutorial();
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      prov.skipSplashLogic();
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      _submitForm();
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() { _formLoading = true; _formError = null; });

    try {
      final data = await ApiClient().post(ApiConfig.restaurants, body: {
        'name': _restoName,
        'description': '',
        'category': _cuisineType,
        'address': _city,
        'normalPrepTime': _normalPrepTime.toInt(),
        'rushPrepTime': _rushPrepTime.toInt(),
      });

      final restoId = (data as Map<String, dynamic>)['id'] as String?;

      // Save local settings too (for offline fallback)
      final settings = RestaurantSettings(
        managerFirstName: _managerFirstName,
        managerPhone: _managerPhone,
        name: _restoName,
        cuisineType: _cuisineType,
        city: _city,
        normalPrepTime: _normalPrepTime.toInt(),
        rushPrepTime: _rushPrepTime.toInt(),
      );
      if (mounted) {
        final prov = context.read<RestoProvider>();
        await prov.updateSettings(settings);
        prov.loadFromApi(restaurantId: restoId);
        _finishOnboarding();
      }
    } catch (e) {
      String msg = 'Erreur lors de la création du restaurant';
      if (e is ApiException) msg = e.message;
      if (e is ValidationException) msg = e.message;
      if (mounted) setState(() { _formError = msg; _formLoading = false; });
    }
  }

  void _finishOnboarding() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RestoMainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingBackend) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );
    }

    Widget content;
    switch (_currentStep) {
      case 0:
        content = _buildRgpd();
        break;
      case 1:
        content = _buildTutorial();
        break;
      case 2:
        content = _buildSplash();
        break;
      case 3:
        content = _buildForm();
        break;
      default:
        content = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(child: Center(child: content)),
    );
  }

  Widget _buildRgpd() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.privacy_tip, size: 64, color: Color(0xFFF59E0B)),
        const SizedBox(height: 24),
        const Text('Confidentialité & CGU',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            'En continuant, vous acceptez nos conditions générales d\'utilisation et notre politique de confidentialité (RGPD).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFA1A1AA)),
          ),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black),
          child: const Text('Accepter et Continuer'),
        ),
      ],
    );
  }

  Widget _buildTutorial() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.swipe, size: 64, color: Color(0xFF10B981)),
        const SizedBox(height: 24),
        const Text('Tutoriel FAST',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            'Gérez vos commandes en temps réel, activez le Mode Rush, et suivez vos statistiques via votre espace dédié.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFA1A1AA)),
          ),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black),
          child: const Text('J\'ai compris'),
        ),
      ],
    );
  }

  Widget _buildSplash() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Transform.scale(
              scale: 1.35,
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover)),
        ),
        const SizedBox(height: 32),
        const Text(
          'Faites grandir votre\nrestaurant avec FAST',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          ),
          child: const Text('Créer mon espace',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('Configuration',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 24),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: 'Prénom du gérant',
                labelStyle: TextStyle(color: Color(0xFFA1A1AA))),
            onSaved: (val) => _managerFirstName = val ?? '',
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: 'Nom du Restaurant *',
                labelStyle: TextStyle(color: Color(0xFFA1A1AA))),
            validator: (val) =>
                val == null || val.isEmpty ? 'Requis' : null,
            onSaved: (val) => _restoName = val ?? '',
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: 'Ville',
                labelStyle: TextStyle(color: Color(0xFFA1A1AA))),
            onSaved: (val) => _city = val ?? '',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _cuisineType,
            dropdownColor: const Color(0xFF18181B),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: 'Type de cuisine',
                labelStyle: TextStyle(color: Color(0xFFA1A1AA))),
            items: _cuisines
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (val) => setState(() => _cuisineType = val!),
          ),
          const SizedBox(height: 32),
          _buildTimeSlider(
            'Temps de préparation normal',
            _normalPrepTime,
            5, 60,
            const Color(0xFFF59E0B),
            (val) => setState(() => _normalPrepTime = val),
          ),
          const SizedBox(height: 24),
          _buildTimeSlider(
            'Temps en Mode Rush',
            _rushPrepTime,
            10, 90,
            const Color(0xFFEF4444),
            (val) => setState(() => _rushPrepTime = val),
          ),
          const SizedBox(height: 24),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_formError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFEF4444), fontSize: 13)),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _formLoading ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _formLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('Enregistrer et accéder au Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlider(String title, double value, double min, double max,
      Color color, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            Text('${value.round()} min',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text('${min.round()}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 11)),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6.0,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 14.0),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 28.0),
                  activeTrackColor: color,
                  inactiveTrackColor: const Color(0xFF27272A),
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.15),
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
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text('${max.round()}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }
}
