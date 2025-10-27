import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'inspection_form_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with TickerProviderStateMixin {
  bool hasPermission = false;
  bool isPermissionRequested = false;
  String? scannedData;
  MobileScannerController? controller;
  bool isScanning = true;
  bool isWeb = false;
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    isWeb = kIsWeb;
    _initializeScanner();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));
    _scanAnimationController.repeat();
  }

  @override
  void dispose() {
    controller?.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeScanner() async {
    try {
      print('Initializing scanner for platform: ${isWeb ? "Web" : "Mobile"}');
      
      if (isWeb) {
        // For web, create controller with specific constraints
        controller = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
        );
        setState(() {
          hasPermission = true; // Assume permission will be requested by MobileScanner
          isPermissionRequested = true;
        });
      } else {
        // For mobile, use the standard permission handler
        await _requestMobileCameraPermission();
      }
    } catch (e) {
      print('Scanner initialization error: $e');
      setState(() {
        isPermissionRequested = true;
        hasPermission = false;
      });
    }
  }

  Future<void> _requestMobileCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      hasPermission = status == PermissionStatus.granted;
      isPermissionRequested = true;
    });
    
    if (hasPermission) {
      controller = MobileScannerController();
    }
  }


  Future<void> _retryWebCamera() async {
    print('Retrying web camera...');
    
    setState(() {
      isPermissionRequested = false;
      hasPermission = false;
    });
    
    // Dispose old controller
    controller?.dispose();
    controller = null;
    
    // Wait a bit before reinitializing
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Reinitialize
    await _initializeScanner();
  }

  Future<void> _retryWebCameraWithDifferentSettings() async {
    print('Retrying web camera with different settings...');
    
    setState(() {
      isPermissionRequested = false;
      hasPermission = false;
    });
    
    // Dispose old controller
    controller?.dispose();
    controller = null;
    
    // Wait a bit before reinitializing
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Try with different settings
    try {
      controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.front, // Try front camera
        torchEnabled: false,
      );
      setState(() {
        hasPermission = true;
        isPermissionRequested = true;
      });
    } catch (e) {
      print('Failed to initialize with front camera: $e');
      // Fallback to back camera
      controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      setState(() {
        hasPermission = true;
        isPermissionRequested = true;
      });
    }
  }


  void _showManualInputDialog() {
    final TextEditingController inputController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual QR Code Input'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the QR code data manually:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: inputController,
              decoration: const InputDecoration(
                hintText: 'Enter QR code data...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final input = inputController.text.trim();
              if (input.isNotEmpty) {
                Navigator.of(context).pop();
                // Create a mock BarcodeCapture for manual input
                final barcode = Barcode(rawValue: input);
                final capture = BarcodeCapture(barcodes: [barcode]);
                _onDetect(capture);
              }
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  void _showScannedDataDialog(String data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'QR Code Scanned',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scanned Data:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5568),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E5EC),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFA3B1C6),
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Text(
                data,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2D3748),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E5EC),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFA3B1C6),
                        offset: Offset(3, 3),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(-3, -3),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        isScanning = true;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Scan Again',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4A5568),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Close scanner
                      // Navigate to inspection form with scanned data
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InspectionFormScreen(
                            scannedData: scannedData,
                          ),
                        ),
                      );
                    },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Inspect Now',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          isScanning = false;
          scannedData = code; // Store the scanned data in class variable
        });
        _showScannedDataDialog(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Enhanced responsive breakpoints
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC), // Clean white
              Color(0xFFF1F5F9), // Light gray
              Color(0xFFE2E8F0), // Slightly darker gray
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
          children: [
            // Neumorphic Header
            _buildNeumorphicHeader(context, isTablet),
            
            // Scanner Area
            Expanded(
              child: _buildScannerArea(context, isTablet),
            ),
            
            // Control Buttons
            _buildControlButtons(context, isTablet),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 50 : 45,
            height: isTablet ? 50 : 45,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(8, 111, 222, 0.977),
              borderRadius: BorderRadius.circular(isTablet ? 25 : 22.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(isTablet ? 25 : 22.5),
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR Code Scanner',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Point your camera at a QR code',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerArea(BuildContext context, bool isTablet) {
    if (!isPermissionRequested) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(8, 111, 222, 0.977)),
        ),
      );
    }

    if (!hasPermission) {
      return _buildPermissionDeniedWidget(context, isTablet);
    }

    // If controller is null, show error
    if (controller == null) {
      return _buildCameraErrorWidget(context, isTablet);
    }

    return Container(
      margin: EdgeInsets.all(isTablet ? 32.0 : 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _buildScannerPreview(context, isTablet),
      ),
    );
  }

  Widget _buildScannerPreview(BuildContext context, bool isTablet) {
    return SizedBox(
      height: isTablet ? 400 : 300,
      child: Stack(
        children: [
          // Real camera scanner
          if (controller != null)
            MobileScanner(
              controller: controller!,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                print('MobileScanner error: $error');
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Camera Error',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isTablet ? 14 : 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(8, 111, 222, 0.977)),
                ),
              ),
            ),
          // Scanner overlay
          Center(
            child: Container(
              width: isTablet ? 300 : 250,
              height: isTablet ? 300 : 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner indicators
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF1E40AF), width: 5),
                          left: BorderSide(color: Color(0xFF1E40AF), width: 5),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF1E40AF), width: 5),
                          right: BorderSide(color: Color(0xFF1E40AF), width: 5),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1E40AF), width: 5),
                          left: BorderSide(color: Color(0xFF1E40AF), width: 5),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1E40AF), width: 5),
                          right: BorderSide(color: Color(0xFF1E40AF), width: 5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scan line animation
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Positioned(
                top: (isTablet ? 300 : 250) * _scanAnimation.value,
                left: isTablet ? 32.0 : 16.0,
                right: isTablet ? 32.0 : 16.0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1E40AF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Instructions
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point camera at QR code to scan',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedWidget(BuildContext context, bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 32.0 : 16.0),
      padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 60,
              color: Color(0xFFEF4444),
            ),
          ),
          SizedBox(height: isTablet ? 24 : 20),
          Text(
            'Camera Permission Required',
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Text(
            isWeb 
              ? 'Please allow camera access to scan QR codes. Make sure you\'re using HTTPS and have granted camera permissions.'
              : 'Please allow camera access to scan QR codes.',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 24 : 20),
          Container(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(8, 111, 222, 0.977),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFFE2E8F0),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: TextButton(
              onPressed: isWeb ? _retryWebCamera : _requestMobileCameraPermission,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Grant Permission',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraErrorWidget(BuildContext context, bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 32.0 : 16.0),
      padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 60,
              color: Color(0xFFEF4444),
            ),
          ),
          SizedBox(height: isTablet ? 24 : 20),
          Text(
            'Camera Not Available',
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Text(
            'Unable to access camera. Please check your device settings.',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 24 : 20),
          if (isWeb) ...[
            // Web-specific retry options
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(8, 111, 222, 0.977),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFFE2E8F0),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: _retryWebCamera,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFFE2E8F0),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: _retryWebCameraWithDifferentSettings,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Try Front Camera',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Chrome Camera Troubleshooting:\n• Make sure you\'re using HTTPS (not HTTP)\n• Close other tabs/apps using the camera\n• Check browser camera permissions (lock icon)\n• Try refreshing the page\n• Try incognito/private mode\n• Check if camera is working in other websites',
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            // Mobile retry
            Container(
              decoration: BoxDecoration(
                color: const Color.fromRGBO(8, 111, 222, 0.977),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFE2E8F0),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    controller = null;
                    isPermissionRequested = false;
                    hasPermission = false;
                  });
                  _initializeScanner();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retry Camera',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            'Flash',
            Icons.flash_on_rounded,
            () {
              controller?.toggleTorch();
            },
            isTablet,
          ),
          _buildControlButton(
            'Flip Camera',
            Icons.flip_camera_ios_rounded,
            () {
              controller?.switchCamera();
            },
            isTablet,
          ),
          _buildControlButton(
            'Manual Input',
            Icons.keyboard_rounded,
            () {
              _showManualInputDialog();
            },
            isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(String label, IconData icon, VoidCallback onTap, bool isTablet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isTablet ? 60 : 50,
          height: isTablet ? 60 : 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isTablet ? 30 : 25),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFE2E8F0),
                offset: Offset(0, 2),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(isTablet ? 30 : 25),
              onTap: onTap,
              child: Icon(
                icon,
                color: const Color.fromRGBO(8, 111, 222, 0.977),
                size: isTablet ? 28 : 24,
              ),
            ),
          ),
        ),
        SizedBox(height: isTablet ? 8 : 6),
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            color: const Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}