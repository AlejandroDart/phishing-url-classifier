import 'package:flutter/services.dart';

class ShareIntentService {
  ShareIntentService._();

  static final ShareIntentService instance = ShareIntentService._();
  static const MethodChannel _channel = MethodChannel(
    'detector_url/shared_text',
  );

  Future<void> initialize(ValueChanged<String> onSharedText) async {
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

  void dispose() => _channel.setMethodCallHandler(null);

  Future<void> setThemeMode(bool isDark) async {
    try {
      await _channel.invokeMethod<void>('setThemeMode', {'isDark': isDark});
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
