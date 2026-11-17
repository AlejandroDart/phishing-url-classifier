import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShareIntentService {
  ShareIntentService._();

  static final ShareIntentService instance = ShareIntentService._();
  static const MethodChannel _channel = MethodChannel(
    'detector_url/shared_text',
  );

  bool get _supportsShareIntent =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize(ValueChanged<String> onSharedText) async {
    if (!_supportsShareIntent) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onSharedText') return;

      final text = call.arguments as String?;
      if (text != null && text.trim().isNotEmpty) {
        onSharedText(text);
      }
    });

    try {
      final initialText = await _channel.invokeMethod<String>(
        'getInitialSharedText',
      );
      if (initialText != null && initialText.trim().isNotEmpty) {
        onSharedText(initialText);
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void dispose() {
    if (_supportsShareIntent) _channel.setMethodCallHandler(null);
  }

  Future<void> setThemeMode(bool isDark) async {
    if (!_supportsShareIntent) return;
    try {
      await _channel.invokeMethod<void>('setThemeMode', {'isDark': isDark});
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
