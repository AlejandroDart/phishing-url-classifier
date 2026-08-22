import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../services/camera_service.dart';
import '../services/ocr_url_extractor.dart';
import '../theme/app_design.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? controller;
  final TextRecognizer textRecognizer = TextRecognizer();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  ScaffoldMessengerState? _messenger;

  bool isProcessing = false;
  bool _isInitializing = false;
  String? _cameraError;

  final GlobalKey _cameraLayoutKey = GlobalKey();
  final GlobalKey _scanAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initButtonAnimation();
    initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller?.dispose();
      controller = null;
    } else if (state == AppLifecycleState.resumed && controller == null) {
      initCamera();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearSnackBars();
    });
  }

  void _initButtonAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);
  }

  void _clearSnackBars() {
    _messenger?.hideCurrentSnackBar();
    _messenger?.removeCurrentSnackBar();
  }

  void _showSnackBar(String message) {
    _clearSnackBars();

    _messenger?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    if (mounted) setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera available');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller!.initialize();
      try {
        await controller!.setFlashMode(FlashMode.off);
        await controller!.setFocusMode(FocusMode.auto);
        await controller!.setExposureMode(ExposureMode.auto);
      } catch (_) {
        // Camera drivers may omit manual focus or exposure controls.
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error inicializando cámara: $e');
      _showSnackBar('No se pudo inicializar la cámara');
      if (mounted) {
        setState(() => _cameraError = 'No se pudo acceder a la cámara');
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<File?> cropImageToScanArea(File originalFile) async {
    try {
      final layoutContext = _cameraLayoutKey.currentContext;
      final scanContext = _scanAreaKey.currentContext;

      if (layoutContext == null || scanContext == null) return null;

      final layoutBox = layoutContext.findRenderObject() as RenderBox;
      final scanBox = scanContext.findRenderObject() as RenderBox;

      final layoutTopLeft = layoutBox.localToGlobal(Offset.zero);
      final scanTopLeft = scanBox.localToGlobal(Offset.zero);

      final layoutSize = layoutBox.size;
      final scanSize = scanBox.size;

      final scanLeft = scanTopLeft.dx - layoutTopLeft.dx;
      final scanTop = scanTopLeft.dy - layoutTopLeft.dy;

      final bytes = await originalFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final baked = img.bakeOrientation(decoded);

      final imageWidth = baked.width.toDouble();
      final imageHeight = baked.height.toDouble();

      final scale = _coverScale(
        srcWidth: imageWidth,
        srcHeight: imageHeight,
        dstWidth: layoutSize.width,
        dstHeight: layoutSize.height,
      );

      final displayedWidth = imageWidth * scale;
      final displayedHeight = imageHeight * scale;

      final dx = (layoutSize.width - displayedWidth) / 2;
      final dy = (layoutSize.height - displayedHeight) / 2;

      int cropX = ((scanLeft - dx) / scale).round();
      int cropY = ((scanTop - dy) / scale).round();
      int cropW = (scanSize.width / scale).round();
      int cropH = (scanSize.height / scale).round();

      cropX = cropX.clamp(0, baked.width - 1);
      cropY = cropY.clamp(0, baked.height - 1);
      cropW = cropW.clamp(1, baked.width - cropX);
      cropH = cropH.clamp(1, baked.height - cropY);

      final cropped = img.copyCrop(
        baked,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final croppedBytes = Uint8List.fromList(
        img.encodeJpg(cropped, quality: 95),
      );

      final croppedFile = File(
        '${originalFile.parent.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await croppedFile.writeAsBytes(croppedBytes, flush: true);
      return croppedFile;
    } catch (e) {
      debugPrint('Error recortando imagen: $e');
      return null;
    }
  }

  double _coverScale({
    required double srcWidth,
    required double srcHeight,
    required double dstWidth,
    required double dstHeight,
  }) {
    final scaleX = dstWidth / srcWidth;
    final scaleY = dstHeight / srcHeight;
    return scaleX > scaleY ? scaleX : scaleY;
  }

  Future<void> captureAndScan() async {
    if (isProcessing) return;
    if (controller == null || !controller!.value.isInitialized) return;

    _clearSnackBars();

    setState(() {
      isProcessing = true;
    });

    _pulseController.stop();

    File? imageFile;
    File? croppedFile;
    try {
      final XFile picture = await controller!.takePicture();
      imageFile = File(picture.path);

      croppedFile = await cropImageToScanArea(imageFile);
      String? detectedUrl;
      for (final file in <File?>[croppedFile, imageFile]) {
        if (file == null || detectedUrl != null) continue;
        final inputImage = InputImage.fromFile(file);
        final recognizedText = await textRecognizer.processImage(inputImage);
        detectedUrl = OcrUrlExtractor.extract(recognizedText.text);
      }

      if (detectedUrl != null) {
        _clearSnackBars();

        if (mounted) {
          Navigator.pop(context, detectedUrl);
        }
        return;
      }

      _showSnackBar('No se detectó ninguna URL válida');
    } catch (e) {
      debugPrint('Error OCR: $e');
      _showSnackBar('Ocurrió un error al analizar la imagen');
    } finally {
      for (final file in <File?>[croppedFile, imageFile]) {
        if (file == null) continue;
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }

      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  void _closeCamera() {
    _clearSnackBars();
    Navigator.pop(context, CameraUrlService.cancelledResult);
  }

  @override
  void dispose() {
    _clearSnackBars();
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    textRecognizer.close();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    final previewSize = controller!.value.previewSize!;

    final previewWidth = previewSize.height;
    final previewHeight = previewSize.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _coverScale(
          srcWidth: previewWidth,
          srcHeight: previewHeight,
          dstWidth: constraints.maxWidth,
          dstHeight: constraints.maxHeight,
        );

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: SizedBox(
              width: previewWidth * scale,
              height: previewHeight * scale,
              child: CameraPreview(controller!),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _cameraError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_photography_outlined,
                      color: Colors.white70,
                      size: 42,
                    ),
                    const SizedBox(height: AppDesign.gapRegular),
                    Text(
                      _cameraError!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: AppDesign.gapRegular),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Volver',
                          onPressed: _closeCamera,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const SizedBox(width: AppDesign.gapRegular),
                        IconButton(
                          tooltip: 'Reintentar',
                          onPressed: initCamera,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      );
    }

    final scanWidth =
        (MediaQuery.sizeOf(context).width - (AppDesign.gapSection * 2))
            .clamp(240.0, AppDesign.cameraFrameMaxWidth);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeCamera();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              key: _cameraLayoutKey,
              child: _buildCameraPreview(),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: ScannerOverlayPainter(
                  scanWidth: scanWidth,
                  scanHeight: AppDesign.cameraFrameHeight,
                ),
              ),
            ),
            Center(
              child: Container(
                key: _scanAreaKey,
                width: scanWidth,
                height: AppDesign.cameraFrameHeight,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.greenAccent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDesign.radiusControl,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.45),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _closeCamera,
              ),
            ),
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: GestureDetector(
                    onTap: isProcessing ? null : captureAndScan,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: isProcessing
                          ? AppDesign.cameraCaptureBusySize
                          : AppDesign.cameraCaptureSize,
                      height: isProcessing
                          ? AppDesign.cameraCaptureBusySize
                          : AppDesign.cameraCaptureSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.45),
                            blurRadius: isProcessing ? 10 : 22,
                            spreadRadius: isProcessing ? 2 : 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: isProcessing
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.8,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double scanWidth;
  final double scanHeight;

  ScannerOverlayPainter({
    required this.scanWidth,
    required this.scanHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);

    final fullScreen = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final holeRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanWidth,
      height: scanHeight,
    );

    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          holeRect,
          const Radius.circular(AppDesign.radiusControl),
        ),
      );

    final finalPath = Path.combine(
      PathOperation.difference,
      fullScreen,
      holePath,
    );

    canvas.drawPath(finalPath, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
