import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'services/ocr_service.dart';
import 'services/barcode_service.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WebViewApp(),
    );
  }
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> with SingleTickerProviderStateMixin {
  // WebView variables
  InAppWebViewController? webViewController;
  bool isLoading = true;
  final initialUrl = "http://10.130.54.78:5204/";
  
  // Camera variables
  bool showCamera = false;
  List<CameraDescription> cameras = [];
  
  // OCR and Barcode services
  final OcrService _ocrService = OcrService();
  final BarcodeService _barcodeService = BarcodeService();
  String _recognizedText = '';
  
  // Menu variables
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _animateIcon;
  
  @override
  void initState() {
    super.initState();
    _initializeCameras();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _animateIcon = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  Future<void> _initializeCameras() async {
    cameras = await availableCameras();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ocrService.dispose();
    super.dispose();
  }
  
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
    
    if (_isMenuOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  // Toggle camera visibility
  void _toggleCamera() async {
    if (showCamera) {
      _ocrService.stopLiveOcr();
      setState(() {
        showCamera = false;
      });
      _ocrService.dispose();
    } else {
      await _ocrService.initializeCamera(cameras);
      if (_ocrService.isCameraInitialized) {
        setState(() {
          showCamera = true;
        });
      }
    }
  }
  
  // Handle text recognition 
  void _updateRecognizedText(String text) {
    if (mounted) {
      setState(() {
        _recognizedText = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
              ),
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                isLoading = true;
              });
            },
            onLoadStop: (controller, url) {
              setState(() {
                isLoading = false;
              });
            },
          ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (showCamera && _ocrService.cameraController != null && _ocrService.isCameraInitialized)
            Positioned.fill(
              child: Stack(
                children: [
                  CameraPreview(_ocrService.cameraController!),
                  
                  Positioned(
                    top: 40,
                    right: 20,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _toggleCamera,
                      ),
                    ),
                  ),
                  
                  if (_recognizedText.isNotEmpty)
                    Positioned(
                      top: 100,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _recognizedText,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ElevatedButton(
                        onPressed: () => _ocrService.toggleLiveOcr(_updateRecognizedText),
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(20),
                          backgroundColor: _ocrService.isLiveOcrRunning ? Colors.red : Colors.blue,
                        ),
                        child: Icon(_ocrService.isLiveOcrRunning ? Icons.stop : Icons.text_fields),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Camera button
          _buildMenuButton(
            icon: Icons.camera_alt,
            label: 'Camera',
            visible: _isMenuOpen,
            onPressed: () {
              _toggleMenu();
              _toggleCamera();
            },
            index: 0,
          ),
          
          // Live OCR button
          _buildMenuButton(
            icon: Icons.text_fields,
            label: 'Live OCR',
            visible: _isMenuOpen,
            onPressed: () {
              _toggleMenu();
              if (showCamera) {
                _ocrService.toggleLiveOcr(_updateRecognizedText);
              } else {
                _toggleCamera();
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_ocrService.isCameraInitialized) {
                    _ocrService.toggleLiveOcr(_updateRecognizedText);
                  }
                });
              }
            },
            index: 1,
          ),
          
          // Barcode scanner button
          _buildMenuButton(
            icon: Icons.qr_code_scanner,
            label: 'Barcode',
            visible: _isMenuOpen,
            onPressed: () async {
              _toggleMenu();
              final barcodeResult = await _barcodeService.scanBarcode(context);
              
              if (barcodeResult != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Barcode: $barcodeResult'),
                    duration: const Duration(seconds: 3),
                  ),
                );
                
                // Redirect to webview with scanned barcode
                webViewController?.loadUrl(
                  urlRequest: URLRequest(url: WebUri('http://10.130.67.130:5204/Packages/Overview/$barcodeResult'))
                );
              }
            },
            index: 2,
          ),
          
          // Main menu button
          FloatingActionButton(
            onPressed: _toggleMenu,
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _animateIcon,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required bool visible,
    required VoidCallback onPressed,
    required int index,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: visible ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(
          0, 
          visible ? 0 : 100, 
          0
        ),
        height: visible ? 48.0 : 0.0,
        margin: EdgeInsets.only(bottom: visible ? 16.0 : 0),
        child: visible
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  FloatingActionButton(
                    mini: true,
                    heroTag: "btn_$index",  
                    onPressed: onPressed,
                    child: Icon(icon),
                  ),
                ],
              )
            : Container(),
      ),
    );
  }
}