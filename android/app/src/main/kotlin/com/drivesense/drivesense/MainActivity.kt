package com.drivesense.drivesense

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "drivesense/sistema")
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    // "Atrás" en la pantalla raíz: la app pasa al fondo en vez de cerrarse.
                    // Cerrar la actividad detendría el registro de un viaje en curso.
                    "enviarAlFondo" -> {
                        moveTaskToBack(true)
                        resultado.success(null)
                    }
                    // Evento de riesgo (HU-14): vibración y, si está activado, un sonido
                    // corto. Funciona con la pantalla apagada: el servicio en primer plano
                    // de geolocator mantiene vivo el proceso.
                    "avisarEvento" -> {
                        vibrar()
                        if (llamada.argument<Boolean>("sonido") == true) sonar()
                        resultado.success(null)
                    }
                    else -> resultado.notImplemented()
                }
            }
    }

    private fun vibrar() {
        val vibrador = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrador.hasVibrator()) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            vibrador.vibrate(DURACION_VIBRACION_MS)
            return
        }
        val efecto = VibrationEffect.createOneShot(DURACION_VIBRACION_MS, VibrationEffect.DEFAULT_AMPLITUDE)
        // Uso "notificación": se permite con la app en segundo plano y respeta el
        // modo del teléfono
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrador.vibrate(
                efecto,
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_NOTIFICATION),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrador.vibrate(
                efecto,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .build(),
            )
        }
    }

    /// Tono corto por el canal de notificaciones: en silencio o "no molestar" no suena.
    private fun sonar() {
        val tono = try {
            ToneGenerator(AudioManager.STREAM_NOTIFICATION, VOLUMEN_TONO)
        } catch (e: RuntimeException) {
            return
        }
        tono.startTone(ToneGenerator.TONE_PROP_BEEP, DURACION_TONO_MS)
        Handler(Looper.getMainLooper()).postDelayed({ tono.release() }, DURACION_TONO_MS + 100L)
    }

    private companion object {
        const val DURACION_VIBRACION_MS = 250L
        const val DURACION_TONO_MS = 150
        const val VOLUMEN_TONO = 80
    }
}
