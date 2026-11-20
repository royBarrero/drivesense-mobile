package com.drivesense.drivesense

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// Voz del Copiloto y del Modo aprendizaje (HU-31). Se crea al primer uso.
    private var voz: TextToSpeech? = null
    private var vozLista = false
    private var focoAudio: AudioFocusRequest? = null

    /// Canal con Dart: también lo usa Android para pedir que se abra el recorrido.
    private var canal: MethodChannel? = null

    // La actividad es `singleTop`: tocar la notificación de un evento llega aquí.
    // Con la actividad cerrada el motor de Dart tampoco vive, así que no hay un
    // viaje en curso que abrir: la app arranca en Inicio con "Continuar viaje".
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (pideAbrirRecorrido(intent)) canal?.invokeMethod("abrirRecorrido", null)
    }

    private fun pideAbrirRecorrido(intent: Intent?): Boolean =
        intent?.getStringExtra(EXTRA_ABRIR) == ABRIR_RECORRIDO

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "drivesense/sistema")
        canal?.setMethodCallHandler { llamada, resultado ->
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
                        canalNotificacion = crearCanalAvisos(),
                        id = ID_VIAJE_FINALIZADO,
                        abrir = null,
                    )
                    resultado.success(null)
                }
                // Evento de riesgo con la app en segundo plano o la pantalla
                // bloqueada: notificación emergente y silenciosa (la vibración y
                // el tono los pone `avisarEvento`). Una nueva reemplaza a la
                // anterior; al tocarla se abre el recorrido.
                "notificarEvento" -> {
                    notificar(
                        llamada.argument<String>("titulo") ?: "",
                        llamada.argument<String>("texto") ?: "",
                        canalNotificacion = crearCanalEventos(),
                        id = ID_EVENTO,
                        abrir = ABRIR_RECORRIDO,
                    )
                    resultado.success(null)
                }
                "quitarNotificacionEvento" -> {
                    gestorNotificaciones().cancel(ID_EVENTO)
                    resultado.success(null)
                }
                // Copiloto por voz y Modo aprendizaje (HU-31). `prioridad`: una
                // indicación de ruta corta lo que se estaba diciendo; un consejo
                // espera su turno.
                "hablar" -> {
                    hablar(
                        llamada.argument<String>("texto") ?: "",
                        llamada.argument<Boolean>("prioridad") == true,
                    )
                    resultado.success(null)
                }
                "callarVoz" -> {
                    voz?.stop()
                    soltarFoco()
                    resultado.success(null)
                }
                else -> resultado.notImplemented()
            }
        }
    }

    /// Habla en español con la voz del teléfono. Pide el foco de audio con
    /// atenuación: la música baja mientras habla y vuelve al terminar.
    private fun hablar(texto: String, prioridad: Boolean) {
        if (texto.isBlank()) return
        val actual = voz
        if (actual == null) {
            // Todavía no se creó: se crea y se dice al estar lista
            voz = TextToSpeech(applicationContext) { estado ->
                vozLista = estado == TextToSpeech.SUCCESS && configurarVoz()
                if (vozLista) decir(texto, prioridad)
            }
            return
        }
        if (vozLista) decir(texto, prioridad)
    }

    /// Español de Bolivia o, si el teléfono no lo tiene, de Estados Unidos o el
    /// genérico. `false` si no hay ninguna voz en español.
    private fun configurarVoz(): Boolean {
        val tts = voz ?: return false
        val idiomas = listOf(Locale.forLanguageTag("es-BO"), Locale.forLanguageTag("es-US"), Locale("es"))
        val idioma = idiomas.firstOrNull {
            tts.isLanguageAvailable(it) >= TextToSpeech.LANG_AVAILABLE
        }
        if (idioma == null) {
            Log.w(ETIQUETA_LOG, "No hay voz en español instalada")
            return false
        }
        tts.language = idioma
        tts.setAudioAttributes(atributosVoz())
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) {
                if (!tts.isSpeaking) soltarFoco()
            }
            @Deprecated("Reemplazado en la API 21, se mantiene por compatibilidad")
            override fun onError(id: String?) {
                soltarFoco()
            }
        })
        return true
    }

    private fun decir(texto: String, prioridad: Boolean) {
        val tts = voz ?: return
        pedirFoco()
        val modo = if (prioridad) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD
        tts.speak(texto, modo, null, "drivesense-${System.nanoTime()}")
    }

    private fun atributosVoz(): AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    private fun pedirFoco() {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val pedido = focoAudio ?: AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(atributosVoz())
                .build()
                .also { focoAudio = it }
            audio.requestAudioFocus(pedido)
        } else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
    }

    private fun soltarFoco() {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focoAudio?.let { audio.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audio.abandonAudioFocus(null)
        }
    }

    override fun onDestroy() {
        voz?.shutdown()
        voz = null
        super.onDestroy()
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

    private fun gestorNotificaciones() =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /// Canal "Avisos de viaje" (viaje finalizado solo).
    private fun crearCanalAvisos(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            gestorNotificaciones().createNotificationChannel(
                NotificationChannel(
                    CANAL_AVISOS,
                    "Avisos de viaje",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        return CANAL_AVISOS
    }

    /// Canal "Eventos de riesgo": emergente y sin sonido ni vibración propios. El
    /// conductor puede silenciarlo desde los ajustes del teléfono.
    private fun crearCanalEventos(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canalEventos = NotificationChannel(
                CANAL_EVENTOS,
                "Eventos de riesgo",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Avisos de frenadas, aceleraciones, giros y excesos durante el viaje"
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            gestorNotificaciones().createNotificationChannel(canalEventos)
        }
        return CANAL_EVENTOS
    }

    /// [abrir]: qué pantalla abre la app al tocarla (nula: donde esté).
    private fun notificar(
        titulo: String,
        texto: String,
        canalNotificacion: String,
        id: Int,
        abrir: String?,
    ) {
        val abrirApp = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (abrir != null) abrirApp.putExtra(EXTRA_ABRIR, abrir)
        val alTocar = PendingIntent.getActivity(
            this,
            id,
            abrirApp,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val constructor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, canalNotificacion)
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
            .setShowWhen(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
        // Sin el permiso de notificaciones (Android 13+) no se muestra: no es un error
        try {
            gestorNotificaciones().notify(id, notificacion)
        } catch (e: SecurityException) {
            return
        }
    }

    private companion object {
        const val ETIQUETA_LOG = "DriveSense"
        const val CANAL_AVISOS = "avisos_viaje"
        const val CANAL_EVENTOS = "eventos_riesgo"
        const val ID_VIAJE_FINALIZADO = 1001
        const val ID_EVENTO = 1002
        const val EXTRA_ABRIR = "abrir"
        const val ABRIR_RECORRIDO = "recorrido"
        const val DURACION_VIBRACION_MS = 250L
        const val DURACION_TONO_MS = 150
        const val VOLUMEN_TONO = 80
    }
}
