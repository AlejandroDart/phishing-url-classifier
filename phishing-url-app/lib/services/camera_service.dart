import 'package:flutter/material.dart';
import '../screens/camera_screen.dart';

class CameraUrlService {
  static const String cancelledResult = '__CANCELLED__';

  Future<String?> takePictureAndExtractUrl(BuildContext context) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScreen(),
      ),
    );

    return result;
  }
}
