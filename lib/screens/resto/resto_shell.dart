import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/resto_spotlight_tutorial.dart';
import 'kitchen_screen.dart';
import 'resto_orders_screen.dart';
import 'resto_menu_screen.dart';
import 'resto_stats_screen.dart';
import 'resto_settings_screen.dart';
import 'resto_profile_screen.dart';

class RestoMainShell extends StatefulWidget {
  const RestoMainShell({super.key});

  @override
  State<RestoMainShell> createState() => _RestoMainShellState();
}

class _RestoMainShellState extends State<RestoMainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  int _tutorialStep = 0;
  bool _showTutorial = false;

  final _ordersKey = GlobalKey();
  final _kitchenKey = GlobalKey();
  final _menuKey = GlobalKey();
  final _statsKey = GlobalKey();
  final _settingsKey = GlobalKey();
  final _profileKey = GlobalKey();

  final List<Widget> _pages = [
    const RestoOrdersScreen(),
    const RestoMenuScreen(),
    const RestoStatsScreen(),
    const RestoSettingsScreen(),
    const RestoProfileScreen(),
  ];

  late final List<_TutorialStep> _tutorialSteps = [
    _TutorialStep(
      key: _ordersKey,
      navigationIndex: 0,
      title: 'Pilotez vos commandes',
      description:
          'Les nouvelles commandes payées arrivent ici. Faites-les passer de reçue à en préparation, puis prête et récupérée.',
    ),
    _TutorialStep(
      key: _kitchenKey,
      navigationIndex: 0,
      title: 'Ouvrez le mode Cuisine',
      description:
          'Affichez une vue opérationnelle pensée pour la préparation et gardez les commandes prioritaires sous les yeux.',
    ),
    _TutorialStep(
      key: _menuKey,
      navigationIndex: 1,
      title: 'Construisez votre menu',
      description:
          'Ajoutez vos plats, prix et photos, puis rendez un article indisponible en un geste lorsqu’il est en rupture.',
    ),
    _TutorialStep(
      key: _statsKey,
      navigationIndex: 2,
      title: 'Suivez vos performances',
      description:
          'Consultez les ventes, les commandes et les plats populaires pour prendre de meilleures décisions.',
    ),
    _TutorialStep(
      key: _settingsKey,
      navigationIndex: 3,
      title: 'Configurez votre restaurant',
      description:
          'Complétez votre identité, vos horaires de préparation, vos coordonnées et vos options alimentaires.',
    ),
    _TutorialStep(
      key: _profileKey,
      navigationIndex: 4,
      title: 'Vérifiez votre vitrine',
      description:
          'Prévisualisez exactement ce que les clients voient. Vous êtes prêt à recevoir vos premières commandes.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showTutorialIfNeeded(),
    );
  }

  String? get _tutorialPreferenceKey {
    final userId = context.read<AuthProvider>().user?.id;
    return userId == null ? null : 'fast_resto_spotlight_v1_$userId';
  }

  Future<void> _showTutorialIfNeeded() async {
    final key = _tutorialPreferenceKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(key) ?? false)) return;
    _startTutorial();
  }

  void _startTutorial() {
    _scaffoldKey.currentState?.closeDrawer();
    setState(() {
      _tutorialStep = 0;
      _currentIndex = _tutorialSteps.first.navigationIndex;
      _showTutorial = true;
    });
  }

  Future<void> _finishTutorial() async {
    final key = _tutorialPreferenceKey;
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    }
    if (!mounted) return;
    setState(() {
      _showTutorial = false;
      _currentIndex = 0;
    });
  }

  void _nextTutorialStep() {
    if (_tutorialStep == _tutorialSteps.length - 1) {
      _finishTutorial();
      return;
    }
    final nextStep = _tutorialStep + 1;
    setState(() {
      _tutorialStep = nextStep;
      _currentIndex = _tutorialSteps[nextStep].navigationIndex;
    });
  }

  Rect? _targetRect(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RestoProvider>(context);
    final tutorial = _tutorialSteps[_tutorialStep];

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFF09090B),
          appBar: AppBar(
            backgroundColor: const Color(0xFF18181B),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 16,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Transform.scale(
                    scale: 1.35,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'FAST Resto',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Green live dot
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                key: _kitchenKey,
                onPressed: () {
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Kitchen',
                    pageBuilder: (context, anim1, anim2) =>
                        const KitchenScreen(),
                  );
                },
                icon: const Icon(Icons.soup_kitchen, size: 18),
                label: const Text(
                  'Cuisine',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27272A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          drawer: Drawer(
            backgroundColor: const Color(0xFF18181B),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF09090B)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'FAST',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        provider.settings?.name ?? 'Mon Restaurant',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Mode Rush',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Augmente les temps de prépa',
                    style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                  ),
                  activeThumbColor: const Color(0xFFEF4444),
                  value: provider.isRushMode,
                  onChanged: (val) => provider.toggleRushMode(),
                  secondary: const Icon(
                    Icons.local_fire_department,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const Divider(color: Color(0xFF27272A)),
                ListTile(
                  leading: const Icon(
                    Icons.help_outline,
                    color: Color(0xFFF59E0B),
                  ),
                  title: const Text(
                    'Revoir le tutoriel',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Redécouvrir les fonctions principales',
                    style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                  ),
                  onTap: _startTutorial,
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              if (provider.isRushMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFFEF4444),
                  child: const Text(
                    '🔥 MODE RUSH ACTIF - Temps de préparation augmentés',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              Expanded(child: _pages[_currentIndex]),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: const Color(0xFF18181B),
            selectedItemColor: const Color(0xFFF59E0B),
            unselectedItemColor: const Color(0xFF71717A),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: KeyedSubtree(
                  key: _ordersKey,
                  child: const Icon(Icons.receipt_long),
                ),
                label: 'Commandes',
              ),
              BottomNavigationBarItem(
                icon: KeyedSubtree(
                  key: _menuKey,
                  child: const Icon(Icons.restaurant_menu),
                ),
                label: 'Menu',
              ),
              BottomNavigationBarItem(
                icon: KeyedSubtree(
                  key: _statsKey,
                  child: const Icon(Icons.bar_chart),
                ),
                label: 'Stats',
              ),
              BottomNavigationBarItem(
                icon: KeyedSubtree(
                  key: _settingsKey,
                  child: const Icon(Icons.settings),
                ),
                label: 'Paramètres',
              ),
              BottomNavigationBarItem(
                icon: KeyedSubtree(
                  key: _profileKey,
                  child: const Icon(Icons.storefront),
                ),
                label: 'Profil',
              ),
            ],
          ),
        ),
        if (_showTutorial)
          RestoSpotlightTutorial(
            targetRect: _targetRect(tutorial.key),
            title: tutorial.title,
            description: tutorial.description,
            step: _tutorialStep,
            totalSteps: _tutorialSteps.length,
            onNext: _nextTutorialStep,
            onSkip: _finishTutorial,
          ),
      ],
    );
  }
}

class _TutorialStep {
  final GlobalKey key;
  final int navigationIndex;
  final String title;
  final String description;

  const _TutorialStep({
    required this.key,
    required this.navigationIndex,
    required this.title,
    required this.description,
  });
}
