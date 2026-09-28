package com.drivesense.drivesense

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Atrás" en la pantalla raíz: la app pasa al fondo en vez de cerrarse.
        // Cerrar la actividad detendría el registro de un viaje en curso.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "drivesense/sistema")
            .setMethodCallHandler { llamada, resultado ->
                if (llamada.method == "enviarAlFondo") {
                    moveTaskToBack(true)
                    resultado.success(null)
                } else {
                    resultado.notImplemented()
                }
            }
    }
}
