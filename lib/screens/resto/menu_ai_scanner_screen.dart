import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../resto_provider.dart';
import '../../services/restaurant_service.dart';

class MenuAiScannerScreen extends StatefulWidget {
  const MenuAiScannerScreen({super.key});

  @override
  State<MenuAiScannerScreen> createState() => _MenuAiScannerScreenState();
}

class _MenuAiScannerScreenState extends State<MenuAiScannerScreen> {
  int _state = 0; // 0: Idle/Frame, 1: Scanning, 2: Success, -1: Error
  String _errorMessage = '';
  final ImagePicker _picker = ImagePicker();

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Permission caméra refusée.';
          _state = -1;
        });
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('[Scanner] No cameras found.');
        return;
      }

      // Initialize the back camera
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[Scanner] Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _takeInAppPicture() async {
    debugPrint('[Scanner] _takeInAppPicture called');
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('[Scanner] Camera not ready: controller is ${_cameraController == null ? "null" : "not initialized"}');
      return;
    }

    try {
      setState(() => _state = 1);

      final XFile file = await _cameraController!.takePicture();
      debugPrint('[Scanner] In-app photo taken: ${file.path}');

      await _processImage(file);
    } catch (e) {
      debugPrint('[Scanner] Error taking picture: $e');
      if (mounted) {
        setState(() {
          _state = -1;
          _errorMessage = 'Erreur lors de l\'import: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _captureAndScan(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (file == null) return; // User cancelled

      setState(() => _state = 1);

      await _processImage(file);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = -1;
          _errorMessage = 'Erreur lors de l\'import: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    if (!mounted) return;

    final restoProvider = Provider.of<RestoProvider>(context, listen: false);
    final restaurantId = restoProvider.restaurantId;

    if (restaurantId == null) {
      setState(() {
        _state = -1;
        _errorMessage = 'Aucun restaurant connecté.';
      });
      return;
    }

    try {
      // Read image bytes and encode as base64
      final bytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(bytes);

      final service = RestaurantService();
      await service.scanMenu(restaurantId, imageBase64);

      // Refresh menu in provider
      await restoProvider.loadMenu();

      if (!mounted) return;
      setState(() => _state = 2);

      Timer(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = -1;
          _errorMessage = 'Erreur lors de l\'analyse: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Assistant IA FAST',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Live Camera Preview as the background
          if (_state == 0)
            Positioned.fill(
              child: _isCameraInitialized && _cameraController != null
                  ? ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize!.height,
                            height: _cameraController!.value.previewSize!.width,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    )
                  : Container(color: const Color(0xFF09090B)),
            ),

          // Viewfinder darkened overlay with a clear center cutout
          if (_state == 0)
            Positioned.fill(
              child: CustomPaint(
                painter: ViewfinderPainter(),
              ),
            ),

          // Green Finder cadre box and guidelines
          if (_state == 0)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 360,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Corner highlights
                        _scannerCorner(top: 0, left: 0),
                        _scannerCorner(top: 0, right: 0),
                        _scannerCorner(bottom: 0, left: 0),
                        _scannerCorner(bottom: 0, right: 0),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'Cadrez le menu\npapier ou l\'ardoise\npour l\'importation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  height: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Prenez une photo nette du menu',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 4,
                            color: Color(0x80000000),
                          ),
                        ]),
                  ),
                ],
              ),
            ),

          // Control buttons at the bottom
          if (_state == 0)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gallery picker button
                  IconButton(
                    onPressed: () => _captureAndScan(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 48),
                  // Capture camera button in the absolute center
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _takeInAppPicture,
                      borderRadius: BorderRadius.circular(38),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF27272A), width: 6),
                        ),
                        child: const Center(
                          child: Icon(Icons.camera_alt,
                              color: Color(0xFF09090B), size: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                  // Spacing balance (matches the gallery button width of 48px)
                  const SizedBox(width: 48),
                ],
              ),
            ),

          if (_state == 1)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  SizedBox(height: 24),
                  Text(
                    'L\'IA analyse votre menu...',
                    style: TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Extraction des plats et des prix en cours',
                      style: TextStyle(color: Color(0xFFA1A1AA))),
                ],
              ),
            ),

          if (_state == 2)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 80),
                  SizedBox(height: 24),
                  Text(
                    'Menu importé avec succès !',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          if (_state == -1)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFEF4444), size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'Erreur d\'import',
                    style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _state = 0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF09090B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _scannerCorner(
      {double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(top != null && left != null ? 8 : 0),
            topRight: Radius.circular(top != null && right != null ? 8 : 0),
            bottomLeft: Radius.circular(bottom != null && left != null ? 8 : 0),
            bottomRight:
                Radius.circular(bottom != null && right != null ? 8 : 0),
          ),
        ),
      ),
    );
  }
}

class ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.65);

    // Viewfinder dimensions
    const width = 260.0;
    const height = 360.0;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;

    final rect = Rect.fromLTWH(left, top, width, height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Draw overlay with transparent cutout in the center
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(rrect),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
