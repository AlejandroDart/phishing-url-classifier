import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_url_extractor.dart';

@JS('linkShieldRecognizeText')
external JSPromise<JSString> _recognizeText(JSUint8Array image);

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const _maxImageBytes = 12 * 1024 * 1024;

  final _picker = ImagePicker();
  bool _busy = false;
  String? _message;

  Future<void> _selectImage(ImageSource source) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final photo = await _picker.pickImage(source: source);
      if (photo == null || !mounted) return;

      if (await photo.length() > _maxImageBytes) {
        if (mounted) {
          setState(() => _message = 'Usa una imagen de hasta 12 MB.');
        }
        return;
      }

      final bytes = await photo.readAsBytes();
      if (!mounted) return;

      final recognized = await _recognizeText(
        bytes.toJS,
      ).toDart.timeout(const Duration(seconds: 60));
      if (!mounted) return;

      final url = OcrUrlExtractor.extract(recognized.toDart);
      if (url == null) {
        setState(
          () => _message =
              'No se encontró una URL. Prueba con una imagen más nítida.',
        );
        return;
      }
      Navigator.pop(context, url);
    } catch (error) {
      debugPrint('No se pudo completar el OCR web: $error');
      if (mounted) {
        setState(() {
          _message =
              'No pudimos leer la imagen. Revisa tu conexión y prueba con PNG o JPEG.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escaneo visual')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Captura o elige una imagen que muestre la URL.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _selectImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Usar cámara'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _selectImage(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Elegir imagen'),
                  ),
                  if (_busy || _message != null) ...[
                    const SizedBox(height: 20),
                    if (_busy) const LinearProgressIndicator(),
                    Text(
                      _message ?? 'Leyendo la imagen…',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
