package com.example.detector_url

import android.content.Intent
import android.app.UiModeManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "detector_url/shared_text"
    private var channel: MethodChannel? = null
    private var pendingSharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        applyStoredTheme()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pendingSharedText = extractSharedText(intent) ?: pendingSharedText
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    val text = pendingSharedText
                    pendingSharedText = null
                    result.success(text)
                }
                "setThemeMode" -> {
                    val isDark = call.argument<Boolean>("isDark") ?: true
                    applyThemeMode(isDark)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val sharedText = extractSharedText(intent) ?: return
        pendingSharedText = sharedText
        channel?.invokeMethod("onSharedText", sharedText, object : MethodChannel.Result {
            override fun success(result: Any?) {
                pendingSharedText = null
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

            override fun notImplemented() = Unit
        })
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") {
            return null
        }

        return intent.getStringExtra(Intent.EXTRA_TEXT)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    private fun applyStoredTheme() {
        val preferences = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val isDark = preferences.getBoolean("flutter.isDarkMode", true)
        applyThemeMode(isDark)
    }

    private fun applyThemeMode(isDark: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val uiModeManager = getSystemService(UiModeManager::class.java)
            uiModeManager.setApplicationNightMode(
                if (isDark) UiModeManager.MODE_NIGHT_YES else UiModeManager.MODE_NIGHT_NO
            )
        }
    }
}
