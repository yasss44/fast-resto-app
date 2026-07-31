# Graph Report - .  (2026-07-03)

## Corpus Check
- 176 files · ~91,928 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1342 nodes · 1911 edges · 76 communities (71 shown, 5 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 19 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Customer App State & Cart Management|Customer App State & Cart Management]]
- [[_COMMUNITY_Data Models & Serializers|Data Models & Serializers]]
- [[_COMMUNITY_Windows Native Runner Platform|Windows Native Runner Platform]]
- [[_COMMUNITY_macOS & iOS Native Platform Runner|macOS & iOS Native Platform Runner]]
- [[_COMMUNITY_Order Tracker & History UI|Order Tracker & History UI]]
- [[_COMMUNITY_Livreur Delivery Dispatch Panel|Livreur Delivery Dispatch Panel]]
- [[_COMMUNITY_Express Rest API Backend|Express Rest API Backend]]
- [[_COMMUNITY_React Web App Boilerplate|React Web App Boilerplate]]
- [[_COMMUNITY_Restaurant Provider State|Restaurant Provider State]]
- [[_COMMUNITY_REST API Client Configuration|REST API Client Configuration]]
- [[_COMMUNITY_React Web App Package Config|React Web App Package Config]]
- [[_COMMUNITY_App Entrypoint & Navigation Shell|App Entrypoint & Navigation Shell]]
- [[_COMMUNITY_Group Dining & Bill Splitting UI|Group Dining & Bill Splitting UI]]
- [[_COMMUNITY_Linux Native Runner Platform|Linux Native Runner Platform]]
- [[_COMMUNITY_Auth Forms UI|Auth Forms UI]]
- [[_COMMUNITY_Module Onboarding (C15)|Module Onboarding (C15)]]
- [[_COMMUNITY_Module Menu (C16)|Module Menu (C16)]]
- [[_COMMUNITY_Module Cart (C17)|Module Cart (C17)]]
- [[_COMMUNITY_Module Onboarding (C18)|Module Onboarding (C18)]]
- [[_COMMUNITY_Module Menu (C19)|Module Menu (C19)]]
- [[_COMMUNITY_Module Middleware (C20)|Module Middleware (C20)]]
- [[_COMMUNITY_Module Backend (C21)|Module Backend (C21)]]
- [[_COMMUNITY_Module Onboarding (C22)|Module Onboarding (C22)]]
- [[_COMMUNITY_Module Account (C23)|Module Account (C23)]]
- [[_COMMUNITY_Module Lib (C24)|Module Lib (C24)]]
- [[_COMMUNITY_Module Resto (C25)|Module Resto (C25)]]
- [[_COMMUNITY_Module Lib (C26)|Module Lib (C26)]]
- [[_COMMUNITY_Module Resto (C27)|Module Resto (C27)]]
- [[_COMMUNITY_Module Qr (C28)|Module Qr (C28)]]
- [[_COMMUNITY_Module Lib (C29)|Module Lib (C29)]]
- [[_COMMUNITY_Module Location (C30)|Module Location (C30)]]
- [[_COMMUNITY_Module Lib (C31)|Module Lib (C31)]]
- [[_COMMUNITY_Module Utils (C32)|Module Utils (C32)]]
- [[_COMMUNITY_Module Home (C33)|Module Home (C33)]]
- [[_COMMUNITY_Module Exemple (C34)|Module Exemple (C34)]]
- [[_COMMUNITY_Module Resto (C35)|Module Resto (C35)]]
- [[_COMMUNITY_Module Lib (C36)|Module Lib (C36)]]
- [[_COMMUNITY_Module Resto (C37)|Module Resto (C37)]]
- [[_COMMUNITY_Module Role (C38)|Module Role (C38)]]
- [[_COMMUNITY_Module Windows (C39)|Module Windows (C39)]]
- [[_COMMUNITY_Module Lib (C40)|Module Lib (C40)]]
- [[_COMMUNITY_Module Resto (C41)|Module Resto (C41)]]
- [[_COMMUNITY_Module Web (C42)|Module Web (C42)]]
- [[_COMMUNITY_Module App (C43)|Module App (C43)]]
- [[_COMMUNITY_Module Services (C44)|Module Services (C44)]]
- [[_COMMUNITY_Module Controllers (C45)|Module Controllers (C45)]]
- [[_COMMUNITY_Module Controllers (C46)|Module Controllers (C46)]]
- [[_COMMUNITY_Module Controllers (C47)|Module Controllers (C47)]]
- [[_COMMUNITY_Module Controllers (C48)|Module Controllers (C48)]]
- [[_COMMUNITY_Module Delivery (C49)|Module Delivery (C49)]]
- [[_COMMUNITY_Module Auth (C50)|Module Auth (C50)]]
- [[_COMMUNITY_Module Restaurant (C51)|Module Restaurant (C51)]]
- [[_COMMUNITY_Module Controllers (C52)|Module Controllers (C52)]]
- [[_COMMUNITY_Module Controllers (C53)|Module Controllers (C53)]]
- [[_COMMUNITY_Module Auth (C54)|Module Auth (C54)]]
- [[_COMMUNITY_Module Group (C55)|Module Group (C55)]]
- [[_COMMUNITY_Module Map (C56)|Module Map (C56)]]
- [[_COMMUNITY_Module Menu (C57)|Module Menu (C57)]]
- [[_COMMUNITY_Module Notification (C58)|Module Notification (C58)]]
- [[_COMMUNITY_Module Order (C59)|Module Order (C59)]]
- [[_COMMUNITY_Module Kitchen (C60)|Module Kitchen (C60)]]
- [[_COMMUNITY_Module Android (C61)|Module Android (C61)]]
- [[_COMMUNITY_Module Review (C62)|Module Review (C62)]]
- [[_COMMUNITY_Module Ios (C63)|Module Ios (C63)]]
- [[_COMMUNITY_Module Commandes (C64)|Module Commandes (C64)]]
- [[_COMMUNITY_Module Commandes (C65)|Module Commandes (C65)]]
- [[_COMMUNITY_Module Android (C66)|Module Android (C66)]]
- [[_COMMUNITY_Module Backend (C67)|Module Backend (C67)]]
- [[_COMMUNITY_Module Livreur (C68)|Module Livreur (C68)]]
- [[_COMMUNITY_Module Ios (C69)|Module Ios (C69)]]
- [[_COMMUNITY_Module Macos (C70)|Module Macos (C70)]]
- [[_COMMUNITY_Module None (C75)|Module None (C75)]]

## God Nodes (most connected - your core abstractions)
1. `FASTProvider` - 35 edges
2. `RestoProvider` - 35 edges
3. `Win32Window` - 22 edges
4. `compilerOptions` - 16 edges
5. `compilerOptions` - 15 edges
6. `AuthProvider` - 14 edges
7. `useApp()` - 13 edges
8. `prisma` - 12 edges
9. `MessageHandler` - 12 edges
10. `scripts` - 11 edges

## Surprising Connections (you probably didn't know these)
- `build` --references--> `FASTProvider`  [EXTRACTED]
  lib/screens/cart_screen.dart → lib/provider.dart
- `build` --references--> `FASTProvider`  [EXTRACTED]
  lib/screens/home_screen.dart → lib/provider.dart
- `build` --references--> `RestoProvider`  [EXTRACTED]
  lib/screens/resto/resto_profile_screen.dart → lib/resto_provider.dart
- `build` --references--> `RestoProvider`  [EXTRACTED]
  lib/screens/resto/resto_shell.dart → lib/resto_provider.dart
- `build` --references--> `RestoProvider`  [EXTRACTED]
  lib/screens/resto/resto_stats_screen.dart → lib/resto_provider.dart

## Import Cycles
- None detected.

## Communities (76 total, 5 thin omitted)

### Community 0 - "Customer App State & Cart Management"
Cohesion: 0.02
Nodes (94): double get, int get, LatLng? get, _activeOrderId, addNotification, addToCart, cancelOrder, _cart (+86 more)

### Community 1 - "Data Models & Serializers"
Cohesion: 0.03
Nodes (70): address, allergyNotes, available, body, CartItem, category, city, comment (+62 more)

### Community 2 - "Windows Native Runner Platform"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject, HWND (+45 more)

### Community 3 - "macOS & iOS Native Platform Runner"
Cohesion: 0.05
Nodes (32): Any, Cocoa, file_selector_macos, Flutter, flutter_secure_storage_macos, FlutterAppDelegate, FlutterMacOS, FlutterPluginRegistry (+24 more)

### Community 4 - "Order Tracker & History UI"
Cohesion: 0.05
Nodes (39): _buildCancelAction, _buildCheckInCard, _buildCompletionOverlay, _buildHistoriqueTab, _buildOrderHistoryCard, _buildRatingCard, _buildStatusBadge, _buildStatusDescriptionCard (+31 more)

### Community 5 - "Livreur Delivery Dispatch Panel"
Cohesion: 0.05
Nodes (39): _acceptOpportunity, _activeDelivery, _activeDeliveryPollTimer, build, _buildActiveDeliveryMap, _buildActiveDeliveryPanel, _buildErrorBanner, _buildOnlineControlPanel (+31 more)

### Community 6 - "Express Rest API Backend"
Cohesion: 0.05
Nodes (38): dependencies, bcryptjs, cors, dotenv, express, express-rate-limit, helmet, jsonwebtoken (+30 more)

### Community 7 - "React Web App Boilerplate"
Cohesion: 0.15
Nodes (27): MainApp(), HistoryLogs(), MenuSection(), MenuSectionProps, NotificationCenter(), NotificationCenterProps, PaymentGateway(), PaymentGatewayProps (+19 more)

### Community 8 - "Restaurant Provider State"
Cohesion: 0.05
Nodes (37): RestaurantSettings, acceptRgpd, addMenuItem, clearAllSettingsAndRestart, clearError, completeTutorial, deleteMenuItem, dispose (+29 more)

### Community 9 - "REST API Client Configuration"
Cohesion: 0.06
Nodes (35): acceptDelivery, activeDelivery, ApiConfig, availableDeliveries, baseUrl, cancelOrder, deleteNotification, generateDelivery (+27 more)

### Community 10 - "React Web App Package Config"
Cohesion: 0.06
Nodes (30): dependencies, dotenv, express, @google/genai, lucide-react, motion, react, react-dom (+22 more)

### Community 11 - "App Entrypoint & Navigation Shell"
Cohesion: 0.07
Nodes (26): Animation, createState, dispose, _getBottomNavIndex, _getScreenFromIndex, _initialized, initState, main (+18 more)

### Community 12 - "Group Dining & Bill Splitting UI"
Cohesion: 0.08
Nodes (26): ../../api/api_exceptions.dart, _billSplitAmount, build, _buildGroupDashboard, _buildWelcomeScreen, _clearError, _createGroup, createState (+18 more)

### Community 13 - "Linux Native Runner Platform"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 14 - "Auth Forms UI"
Cohesion: 0.07
Nodes (26): build, _buildLoginForm, _buildRegisterForm, _buildTextField, createState, dispose, initialRole, initState (+18 more)

### Community 15 - "Module Onboarding (C15)"
Cohesion: 0.08
Nodes (25): build, _buildForm, _buildRgpd, _buildSplash, _buildTimeSlider, _buildTutorial, _checkBackendRestaurant, _checkingBackend (+17 more)

### Community 16 - "Module Menu (C16)"
Cohesion: 0.09
Nodes (23): CameraController?, ImagePicker, build, _cameraController, _cameras, _captureAndScan, createState, dispose (+15 more)

### Community 17 - "Module Cart (C17)"
Cohesion: 0.10
Nodes (21): FormState, build, _buildCartItemsCard, _buildCheckoutFormCard, _buildProcessingCard, _buildWalkChip, _buildWalkTimeSelector, CartScreen (+13 more)

### Community 18 - "Module Onboarding (C18)"
Cohesion: 0.13
Nodes (22): FASTApp, _FASTAppState, MainShell, _MainShellState, AccountScreen, _AccountScreenState, AuthScreen, _AuthScreenState (+14 more)

### Community 19 - "Module Menu (C19)"
Cohesion: 0.10
Nodes (20): _available, build, _category, createState, _description, _dietary, dispose, _field (+12 more)

### Community 20 - "Module Middleware (C20)"
Cohesion: 0.16
Nodes (12): app, createReview(), listReviews(), getStats(), authenticate(), AuthPayload, Request, requireRole() (+4 more)

### Community 21 - "Module Backend (C21)"
Cohesion: 0.10
Nodes (19): compilerOptions, baseUrl, declaration, declarationMap, esModuleInterop, forceConsistentCasingInFileNames, lib, module (+11 more)

### Community 22 - "Module Onboarding (C22)"
Cohesion: 0.10
Nodes (19): IconData, build, _buildSlide, createState, _currentPage, description, dispose, _finishOnboarding (+11 more)

### Community 23 - "Module Account (C23)"
Cohesion: 0.10
Nodes (19): _buildAdressesTab, _buildLevelProgress, _buildNotifsTab, _buildPointsTab, _buildProfileHeader, _buildProfilTab, _buildStatsRow, createState (+11 more)

### Community 24 - "Module Lib (C24)"
Cohesion: 0.11
Nodes (18): api_config.dart, api_exceptions.dart, FlutterSecureStorage, clearSecureData, delete, _handleResponse, init, _instance (+10 more)

### Community 25 - "Module Resto (C25)"
Cohesion: 0.11
Nodes (18): dart:async, _acceptOrder, _buildCancelledCard, _buildOrderCard, _cancelOrder, _completeOrder, createState, dispose (+10 more)

### Community 26 - "Module Lib (C26)"
Cohesion: 0.13
Nodes (17): FASTProvider, build, build, _buildVectorMapCard, initState, build, build, _buildMenuItemTile (+9 more)

### Community 27 - "Module Resto (C27)"
Cohesion: 0.13
Nodes (18): RestoProvider, _processImage, _delete, _save, _nextStep, _submitForm, build, build (+10 more)

### Community 28 - "Module Qr (C28)"
Cohesion: 0.11
Nodes (17): AnimationController, _buildStatusSection, _confirmed, createState, dispose, initState, _isFinderPattern, _isScanning (+9 more)

### Community 29 - "Module Lib (C29)"
Cohesion: 0.11
Nodes (17): AuthState get, UserData, AuthState, autoLogin, clearError, _error, _extractError, isLoggedIn (+9 more)

### Community 30 - "Module Location (C30)"
Cohesion: 0.11
Nodes (17): dart:convert, DateTime?, LatLng?, _cacheDuration, calculateDistance, getCurrentLocation, getWalkingRoute, instance (+9 more)

### Community 31 - "Module Lib (C31)"
Cohesion: 0.11
Nodes (17): AuthResponse, email, fromJson, id, isClient, isRestaurant, LoginRequest, name (+9 more)

### Community 32 - "Module Utils (C32)"
Cohesion: 0.18
Nodes (14): getMe(), login(), logout(), register(), updateProfile(), acceptDeliverySchema, cartItemSchema, createRestaurantSchema (+6 more)

### Community 33 - "Module Home (C33)"
Cohesion: 0.12
Nodes (16): Color, build, _buildActionableBanners, _buildCategoryGrid, _buildMainContent, _buildNoKitchens, _buildRestaurantCard, _buildSlotsOverlay (+8 more)

### Community 34 - "Module Exemple (C34)"
Cohesion: 0.12
Nodes (16): compilerOptions, allowImportingTsExtensions, allowJs, experimentalDecorators, isolatedModules, jsx, lib, module (+8 more)

### Community 35 - "Module Resto (C35)"
Cohesion: 0.14
Nodes (12): dart:math, build, build, _buildKpiCard, _computeWeeklyRevenue, package:fast_resto_bigbonney/main.dart, package:fast_resto_bigbonney/provider.dart, package:fl_chart/fl_chart.dart (+4 more)

### Community 36 - "Module Lib (C36)"
Cohesion: 0.14
Nodes (13): bool get, idle,
  loading,
  success,, ApiResult, ApiState, copyWith, data, error, isError (+5 more)

### Community 37 - "Module Resto (C37)"
Cohesion: 0.15
Nodes (13): kitchen_screen.dart, build, createState, _currentIndex, _pages, RestoMainShell, _RestoMainShellState, List (+5 more)

### Community 38 - "Module Role (C38)"
Cohesion: 0.17
Nodes (11): auth_screen.dart, _SplashScreen, RestaurantScreen, build, RestoDashboardScreen, RestoProfileScreen, RestoStatsScreen, build (+3 more)

### Community 39 - "Module Windows (C39)"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 40 - "Module Lib (C40)"
Cohesion: 0.24
Nodes (10): Exception, ApiException, errors, message, NotFoundException, statusCode, toString, UnauthorizedException (+2 more)

### Community 41 - "Module Resto (C41)"
Cohesion: 0.18
Nodes (10): build, _buildCard, _buildEmpty, _buildList, createState, _filter, _imagePlaceholder, _openEdit (+2 more)

### Community 42 - "Module Web (C42)"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 43 - "Module App (C43)"
Cohesion: 0.22
Nodes (8): allowedOrigins, apiLimiter, authLimiter, errorHandler(), router, router, router, router

### Community 44 - "Module Services (C44)"
Cohesion: 0.31
Nodes (6): env, emitNotificationToUser(), emitOrderStatusToUser(), emitOrderToRestaurant(), emitOrderUpdate(), getIO()

### Community 45 - "Module Controllers (C45)"
Cohesion: 0.31
Nodes (8): acceptDelivery(), generateDelivery(), getAvailableDeliveries(), getMyActiveDelivery(), updateDeliveryStatus(), router, generateDeliverySchema, updateDeliveryStatusSchema

### Community 46 - "Module Controllers (C46)"
Cohesion: 0.33
Nodes (8): createGroup(), generateCode(), getGroup(), getMyGroups(), joinGroup(), leaveGroup(), createGroupSchema, joinGroupSchema

### Community 47 - "Module Controllers (C47)"
Cohesion: 0.33
Nodes (8): clearAllNotifications(), createNotification(), deleteNotification(), listNotifications(), markAllAsRead(), markAsRead(), router, createNotificationSchema

### Community 48 - "Module Controllers (C48)"
Cohesion: 0.33
Nodes (7): createMenuItem(), deleteMenuItem(), listMenuItems(), updateMenuItem(), router, createMenuItemSchema, updateMenuItemSchema

### Community 49 - "Module Delivery (C49)"
Cohesion: 0.22
Nodes (8): ApiClient, acceptDelivery, _client, DeliveryService, generateDelivery, getAvailableDeliveries, getMyActiveDelivery, updateDeliveryStatus

### Community 50 - "Module Auth (C50)"
Cohesion: 0.22
Nodes (8): _api, AuthService, getMe, login, logout, register, updateProfile, ../models/auth_models.dart

### Community 51 - "Module Restaurant (C51)"
Cohesion: 0.25
Nodes (7): ../api/api_config.dart, _api, createMenuItem, getRestaurant, listMenuItems, listRestaurants, RestaurantService

### Community 52 - "Module Controllers (C52)"
Cohesion: 0.43
Nodes (6): cancelMyOrder(), getMyOrders(), getRestaurantOrders(), placeOrder(), updateOrderStatus(), placeOrderSchema

### Community 53 - "Module Controllers (C53)"
Cohesion: 0.46
Nodes (6): createRestaurant(), getMyRestaurant(), getRestaurant(), listRestaurants(), toggleRushMode(), updateRestaurant()

### Community 54 - "Module Auth (C54)"
Cohesion: 0.25
Nodes (8): ChangeNotifier, _buildHome, _initApp, AuthProvider, _handleLogin, _handleRegister, _navigateToShell, _init

### Community 55 - "Module Group (C55)"
Cohesion: 0.25
Nodes (7): _client, createGroup, getGroup, getMyGroups, GroupService, joinGroup, leaveGroup

### Community 56 - "Module Map (C56)"
Cohesion: 0.25
Nodes (7): addImageFromWidget, geo, openFreeMapStyle, registerMapMarkers, toGeo, package:latlong2/latlong.dart, package:maplibre/maplibre.dart

### Community 57 - "Module Menu (C57)"
Cohesion: 0.25
Nodes (7): _api, createItem, deleteItem, getMenuByRestaurant, MenuService, toggleAvailability, updateItem

### Community 58 - "Module Notification (C58)"
Cohesion: 0.25
Nodes (7): _api, clearAll, deleteNotification, listNotifications, markAllAsRead, markAsRead, NotificationService

### Community 59 - "Module Order (C59)"
Cohesion: 0.25
Nodes (7): _api, cancelOrder, getMyOrders, getRestaurantOrders, OrderService, placeOrder, updateOrderStatus

### Community 60 - "Module Kitchen (C60)"
Cohesion: 0.29
Nodes (6): build, createState, dispose, initState, ../models.dart, package:flutter/services.dart

### Community 61 - "Module Android (C61)"
Cohesion: 0.47
Nodes (4): GeneratedPluginRegistrant, String, FlutterEngine, Keep

### Community 62 - "Module Review (C62)"
Cohesion: 0.33
Nodes (5): ../api/api_client.dart, _api, createReview, listReviews, ReviewService

### Community 63 - "Module Ios (C63)"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 64 - "Module Commandes (C64)"
Cohesion: 0.40
Nodes (5): CustomPainter, _ConfettiPainter, MapRoadmapPainter, _QRCodePainter, ViewfinderPainter

### Community 65 - "Module Commandes (C65)"
Cohesion: 0.50
Nodes (4): build, _buildQRButton, _showAddOptions, MaterialPageRoute

### Community 68 - "Module Livreur (C68)"
Cohesion: 0.67
Nodes (3): LivreurScreen, _LivreurScreenState, TickerProviderStateMixin

## Knowledge Gaps
- **777 isolated node(s):** `name`, `version`, `description`, `main`, `dev` (+772 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `FASTProvider` connect `Module Lib (C26)` to `Customer App State & Cart Management`, `Module Commandes (C65)`, `Module Home (C33)`, `Order Tracker & History UI`, `Livreur Delivery Dispatch Panel`, `Module Role (C38)`, `App Entrypoint & Navigation Shell`, `Auth Forms UI`, `Module Cart (C17)`, `Module Onboarding (C18)`, `Module Auth (C54)`, `Module Account (C23)`, `Module Qr (C28)`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Why does `RestoProvider` connect `Module Resto (C27)` to `Module Resto (C35)`, `Module Resto (C37)`, `Module Role (C38)`, `Restaurant Provider State`, `Module Resto (C41)`, `Auth Forms UI`, `Module Onboarding (C15)`, `Module Menu (C16)`, `Module Onboarding (C18)`, `Module Menu (C19)`, `Module Auth (C54)`, `Module Resto (C25)`, `Module Kitchen (C60)`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `ApiClient` connect `Module Delivery (C49)` to `Module Auth (C50)`, `Module Restaurant (C51)`, `Module Group (C55)`, `Module Lib (C24)`, `Module Notification (C58)`, `Module Order (C59)`, `Module Review (C62)`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **What connects `name`, `version`, `description` to the rest of the system?**
  _778 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Customer App State & Cart Management` be split into smaller, more focused modules?**
  _Cohesion score 0.021052631578947368 - nodes in this community are weakly interconnected._
- **Should `Data Models & Serializers` be split into smaller, more focused modules?**
  _Cohesion score 0.028169014084507043 - nodes in this community are weakly interconnected._
- **Should `Windows Native Runner Platform` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._