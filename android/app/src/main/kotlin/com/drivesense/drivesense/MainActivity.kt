package com.drivesense.drivesense

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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
                    // Viaje finalizado solo porque el auto quedó detenido: el usuario
                    // puede tener la pantalla apagada. Al tocarla se abre la app.
                    "notificarViajeFinalizado" -> {
                        notificar(
                            llamada.argument<String>("titulo") ?: "",
                            llamada.argument<String>("texto") ?: "",
                        )
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

    private fun notificar(titulo: String, texto: String) {
        val gestor = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            gestor.createNotificationChannel(
                NotificationChannel(
                    CANAL_AVISOS,
                    "Avisos de viaje",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        val abrir = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val alTocar = PendingIntent.getActivity(
            this,
            0,
            abrir,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val constructor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CANAL_AVISOS)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
        }
        val notificacion = constructor
            .setSmallIcon(R.drawable.ic_notificacion)
            .setContentTitle(titulo)
            .setContentText(texto)
            .setStyle(Notification.BigTextStyle().bigText(texto))
            .setContentIntent(alTocar)
            .setAutoCancel(true)
            .build()
        // Sin el permiso de notificaciones (Android 13+) no se muestra: no es un error
        try {
            gestor.notify(ID_VIAJE_FINALIZADO, notificacion)
        } catch (e: SecurityException) {
            return
        }
    }

    private companion object {
        const val CANAL_AVISOS = "avisos_viaje"
        const val ID_VIAJE_FINALIZADO = 1001
        const val DURACION_VIBRACION_MS = 250L
        const val DURACION_TONO_MS = 150
        const val VOLUMEN_TONO = 80
    }
}
