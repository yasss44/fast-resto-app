// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'models.dart';
import 'provider.dart';
import 'resto_provider.dart';
import 'api/api_client.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/commandes_screen.dart';
import 'screens/account_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/resto/onboarding_screen.dart' as resto_onboarding;
import 'screens/group_screen.dart';
import 'screens/livreur_screen.dart';
import 'screens/driver_account_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF121212),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Set up 401 auto-logout handler
  ApiClient.onUnauthorized = () {
    // This will be connected to AuthProvider after providers are created
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => FASTProvider()),
        ChangeNotifierProvider(create: (context) => RestoProvider()),
      ],
      child: const FASTApp(),
    ),
  );
}

class FASTApp extends StatefulWidget {
  const FASTApp({super.key});

  @override
  State<FASTApp> createState() => _FASTAppState();
}

class _FASTAppState extends State<FASTApp> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _onboardingDone = false;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  static ThemeData _darkTheme() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090B),
        cardColor: const Color(0xFF18181B),
        dividerColor: const Color(0xFF27272A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFD97706),
          surface: Color(0xFF18181B),
          error: Color(0xFFEF4444),
          onPrimary: Color(0xFF09090B),
          onSecondary: Colors.white,
          onSurface: Color(0xFFF4F4F5),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white),
          titleMedium: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
          bodyLarge: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFFE4E4E7)),
          bodyMedium: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFFA1A1AA)),
          labelSmall: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0, color: Color(0xFF71717A)),
        ),
      );

  static ThemeData _lightTheme() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE4E4E7),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFD97706),
          surface: Colors.white,
          error: Color(0xFFEF4444),
          onPrimary: Color(0xFF09090B),
          onSecondary: Colors.white,
          onSurface: Color(0xFF18181B),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF18181B)),
          titleMedium: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF18181B)),
          bodyLarge: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF3F3F46)),
          bodyMedium: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF71717A)),
          labelSmall: TextStyle(fontFamily: 'sans-serif', fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0, color: Color(0xFFA1A1AA)),
        ),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleStripeReturn();
    }
  }

  Future<void> _initDeepLinks() async {
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _processStripeUri(uri);
    });
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _processStripeUri(initial);
    } catch (_) {}
  }

  void _processStripeUri(Uri uri) {
    if (uri.scheme != 'fast' || uri.host != 'checkout') return;
    final sessionId = uri.queryParameters['session_id'] ??
        uri.queryParameters['sessionId'];
    if (sessionId != null && sessionId.isNotEmpty) {
      _confirmStripeSession(sessionId);
    }
  }

  Future<void> _handleStripeReturn() async {
    final pending = await FASTProvider.loadPendingStripeSession();
    if (pending != null && pending.isNotEmpty) {
      await _confirmStripeSession(pending);
    }
  }

  Future<void> _confirmStripeSession(String sessionId) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.isRestaurant || auth.isLivreur) return;
    final fastProv = context.read<FASTProvider>();
    final ok = await fastProv.confirmStripeCheckout(sessionId);
    if (ok && mounted) {
      fastProv.navigateToScreen('commandes');
    }
  }

  Future<void> _initApp() async {
    final startTime = DateTime.now();
    try {
      final auth = context.read<AuthProvider>();
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Prefs timeout'),
      );
      _onboardingDone = prefs.getBool('fast_onboarding_done') ?? false;

      if (!mounted) return;

      // Sync theme dark pref for legacy reads
      final fastProv = context.read<FASTProvider>();
      if (prefs.containsKey('fast_theme_dark')) {
        final isDark = prefs.getBool('fast_theme_dark') ?? true;
        await fastProv.setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
      }

      // Connect 401 handler to trigger logout
      ApiClient.onUnauthorized = () {
        auth.logout();
      };

      // Attempt auto-login with timeout
      await auth.autoLogin().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );

      // Sync user data from AuthProvider to FASTProvider on cold start
      if (auth.isLoggedIn && mounted) {
        final user = auth.user;
        if (user != null) {
          fastProv.syncFromAuth(
            id: user.id,
            name: user.name,
            email: user.email,
            phone: user.phone,
            points: user.points,
          );
        }
        // Load API data asynchronously (non-blocking)
        fastProv.loadFromApi();
      }

      if (mounted) {
        await _handleStripeReturn().timeout(
          const Duration(seconds: 1),
          onTimeout: () {},
        );
      }
    } catch (_) {
      // Gracefully continue to login/role selection on error
    } finally {
      // Ensure at least 600ms of branded splash for smooth UX
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 600) {
        await Future.delayed(Duration(milliseconds: 600 - elapsed));
      }
      if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<FASTProvider>().themeMode;
    return MaterialApp(
      title: 'FAST - Click & Collect',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_initialized) {
      return const _SplashScreen();
    }

    // Show onboarding on first install
    if (!_onboardingDone) {
      return OnboardingScreen(
        onDone: () {
          setState(() {
            _onboardingDone = true;
          });
        },
      );
    }

    final auth = context.watch<AuthProvider>();
    if (auth.isLoggedIn) {
      if (auth.isRestaurant) {
        return const resto_onboarding.OnboardingScreen();
      }
      if (auth.isLivreur) {
        return const DriverShell();
      }
      return const MainShell();
    }

    return const RoleSelectionScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo Badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 48,
                color: Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 20),
            // App Title
            Text(
              'FAST',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: 2.0,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            // Tagline
            const Text(
              'Chaque minute compte',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF59E0B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            // Subtle progress indicator
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFF59E0B).withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late AnimationController _toastController;
  late Animation<Offset> _toastSlide;
  String _toastTitle = '';
  String _toastBody = '';
  bool _toastVisible = false;

  @override
  void initState() {
    super.initState();
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _toastSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toastController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _toastController.dispose();
    super.dispose();
  }

  void _showTopToast(String title, String body) {
    setState(() {
      _toastTitle = title;
      _toastBody = body;
      _toastVisible = true;
    });
    _toastController.forward(from: 0);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _toastController.reverse().then((_) {
        if (mounted) setState(() => _toastVisible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);

    // Top toast trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.toast != null) {
        _showTopToast(provider.toast!['title']!, provider.toast!['body']!);
        provider.dismissToast();
      }
    });

    Widget activeBody;
    switch (provider.currentScreen) {
      case 'restaurant':
        activeBody = const RestaurantScreen();
        break;
      case 'cart':
        activeBody = const CartScreen();
        break;
      case 'commandes':
        activeBody = const CommandesScreen();
        break;
      case 'group':
        activeBody = const GroupScreen();
        break;
      case 'home':
      default:
        activeBody = const HomeScreen();
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF09090B).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        title: GestureDetector(
          onTap: () {
            provider.selectRestaurant(null);
            provider.navigateToScreen('home');
          },
          child: Row(
            children: [
              // Logo image - Programmatically cropped to hide white outer border
              Container(
                width: 32,
                height: 32,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Transform.scale(
                  scale: 1.35, // Zooms in to crop out the white frame/border
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FAST',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFF59E0B),
                        size: 11,
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        'Paris, France',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountScreen()),
              );
            },
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                provider.userInitial.isNotEmpty ? provider.userInitial : 'D',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF09090B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Screen content
          Positioned.fill(
            child: activeBody,
          ),

          // Top iOS-style toast overlay
          if (_toastVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SlideTransition(
                    position: _toastSlide,
                    child: GestureDetector(
                      onTap: () {
                        _toastController.reverse().then((_) {
                          if (mounted) setState(() => _toastVisible = false);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3F3F46)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _toastTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  if (_toastBody.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _toastBody,
                                      style: const TextStyle(
                                        color: Color(0xFFA1A1AA),
                                        fontSize: 10,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Persistent Floating Basket summary (when on home screen and cart count > 0)
          if (provider.currentScreen == 'home' && provider.cartCount > 0 && provider.selectedRestaurant != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 84,
              child: GestureDetector(
                onTap: () => provider.navigateToScreen('cart'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${provider.cartCount}',
                              style: const TextStyle(
                                color: Color(0xFF09090B),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Voir le panier',
                                style: TextStyle(
                                  color: Color(0xFF09090B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Chez : ${provider.selectedRestaurant!.name}',
                                style: TextStyle(
                                  color: const Color(0xFF09090B).withValues(alpha: 0.7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '€${provider.cartTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF09090B),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF09090B),
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121214) : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.storefront_rounded,
                  label: 'Restaurants',
                  isActive: _getBottomNavIndex(provider.currentScreen) == 0,
                  onTap: () => provider.navigateToScreen('home'),
                ),
                _NavItem(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Panier',
                  isActive: _getBottomNavIndex(provider.currentScreen) == 1,
                  badge: provider.cartCount > 0 ? '${provider.cartCount}' : null,
                  onTap: () => provider.navigateToScreen('cart'),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Commandes',
                  isActive: _getBottomNavIndex(provider.currentScreen) == 2,
                  hasDot: provider.orders.any((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled),
                  onTap: () => provider.navigateToScreen('commandes'),
                ),
                _NavItem(
                  icon: Icons.group_rounded,
                  label: 'Groupe',
                  isActive: _getBottomNavIndex(provider.currentScreen) == 3,
                  onTap: () => provider.navigateToScreen('group'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getBottomNavIndex(String currentScreen) {
    switch (currentScreen) {
      case 'home':
      case 'restaurant':
        return 0;
      case 'cart':
        return 1;
      case 'commandes':
        return 2;
      case 'group':
        return 3;
      default:
        return 0;
    }
  }


}

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          LivreurScreen(),
          DriverAccountScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF121214),
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: const Color(0xFF71717A),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.delivery_dining), label: 'Courses'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Compte'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final String? badge;
  final bool hasDot;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
    this.hasDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? const Color(0xFF71717A) : const Color(0xFF64748B);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isActive ? const Color(0xFFF59E0B) : unselectedColor,
                  ),
                  if (badge != null)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  if (hasDot && badge == null)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? const Color(0xFFF59E0B) : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
