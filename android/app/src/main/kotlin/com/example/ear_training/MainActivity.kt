package com.example.ear_training

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "bosyn/audio_accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Retorna true se a opção de acessibilidade "Áudio mono"
                    // estiver ligada — ela soma L+R e invalida o audiograma.
                    "isMonoAudioEnabled" -> {
                        val mono = try {
                            Settings.System.getInt(contentResolver, "master_mono", 0)
                        } catch (e: Exception) {
                            0
                        }
                        result.success(mono == 1)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
