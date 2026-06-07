package com.example.ear_training

import android.content.Context
import android.content.Intent
import android.media.AudioManager
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

                    // Volume de mídia atual como fração 0..1 (atual / máximo).
                    // O teste e os treinos precisam de um referencial de volume
                    // FIXO; o app lê isto para saber se está no nível combinado.
                    "getMediaVolumeFraction" -> {
                        val fraction = try {
                            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            if (max <= 0) 1.0
                            else am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
                        } catch (e: Exception) {
                            1.0 // falha → não bloqueia o fluxo (degrada gracioso)
                        }
                        result.success(fraction)
                    }

                    // Define o volume de mídia a partir de uma fração 0..1.
                    // Flag 0 = sem a UI de volume do sistema (subida silenciosa,
                    // controlada pelo app). STREAM_MUSIC não exige permissão.
                    "setMediaVolumeFraction" -> {
                        try {
                            val fraction = (call.argument<Double>("fraction") ?: 1.0)
                                .coerceIn(0.0, 1.0)
                            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val target = Math.round(fraction * max).toInt().coerceIn(0, max)
                            am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
                            result.success(null)
                        } catch (e: Exception) {
                            // Em alguns devices/perfis o set pode falhar; não é fatal.
                            result.success(null)
                        }
                    }

                    // Abre as configurações de Texto-para-fala do sistema, para
                    // o usuário instalar/baixar a voz da variante certa (ex.:
                    // pt-BR). O SO NÃO deixa o app instalar voz silenciosamente;
                    // só guiamos o usuário. Retorna true se conseguiu abrir.
                    "openTtsSettings" -> {
                        val opened = try {
                            startActivity(
                                Intent("com.android.settings.TTS_SETTINGS")
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            true
                        } catch (e: Exception) {
                            // Algumas ROMs não expõem a tela de TTS; cai para as
                            // configurações gerais para não deixar o botão "morto".
                            try {
                                startActivity(
                                    Intent(Settings.ACTION_SETTINGS)
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                                true
                            } catch (e2: Exception) {
                                false
                            }
                        }
                        result.success(opened)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
