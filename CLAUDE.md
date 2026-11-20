# drivesense-mobile

App del conductor. El contexto general del proyecto (módulos, HU, roles) está en `../CLAUDE.md`. **Todo lo visual se rige por [`docs/diseno.md`](docs/diseno.md).**

## Entorno

- Flutter 3.41.6 / Dart 3.11.4, **solo Android**.
- Creado con `--org com.drivesense`: el paquete Dart se llama `drivesense` (imports `package:drivesense/...`) y el `applicationId` es `com.drivesense.drivesense`.
- Dispositivo de pruebas: Samsung Galaxy A34 (Android 16) conectado por USB.
- Dependencias: `flutter_map` 8 + `latlong2` (mapa del viaje, HU-29), `url_launcher` (atribución de OpenStreetMap), `flutter_riverpod` 3 (sin generación de código), `go_router`, `dio`, `flutter_secure_storage`, `flutter_localizations` (SDK, para textos de Material en español), `geolocator` (GPS y servicio en primer plano), `permission_handler` (permiso de notificaciones), `shared_preferences` (viaje en curso y resumen pendiente), `sensors_plus` 7 (acelerómetro y giroscopio), `path_provider` (archivos de ruta y CSV), `share_plus` 13 (compartir el CSV de calibración), `device_info_plus` 13 y `package_info_plus` 10 (teléfono y versión enviados al iniciar un viaje). **Riverpod queda en 3.3.x**: la 3.4 exige Dart 3.12. **`permission_handler` queda en 12.x**: la 13 (`permission_handler_android` 14) exige AGP 9 y compileSdk 37, y el proyecto usa AGP 8.11.
- `adb` no está en el PATH: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.

## Estado actual

- Implementado: base de la app, login (HU-02), registro de conductor (HU-01), estructura principal con barra inferior (Inicio, Viajes, Perfil), iniciar/finalizar recorrido (HU-04, HU-05), historial de viajes (HU-06), captura de acelerómetro y giroscopio (HU-07), ruta GPS (HU-08), filtro de señal (HU-09) y detección de frenada brusca, aceleración severa, giro agresivo y exceso de velocidad (HU-10 a HU-13) y sus avisos en tiempo real (HU-14), el DriveScore del viaje en el resumen (HU-15: los eventos se envían al finalizar), su desglose por categoría en el resumen y el detalle (HU-16) y su histórico en Inicio y "Mi DriveScore" (HU-17), el mapa de la ruta con sus eventos en el resumen, el detalle y el mapa completo (HU-29) y las recomendaciones del viaje: la principal (HU-18) y las secundarias (HU-19), el comparativo entre periodos (HU-20) desde "Mi DriveScore", el nivel y los logros (HU-21) en Perfil, los desafíos semanales y su recompensa (HU-22, HU-23) en Inicio y el resumen del viaje, el Copiloto, paso 1 (HU-30): elegir un destino y ver la ruta antes de iniciar, y el Copiloto por voz y el Modo aprendizaje (HU-31), y el asistente de ayuda (sin HU). El cambio de contraseña temporal es **provisional** (`lib/app/placeholder_screens.dart`).
- Navegación (`app/router.dart`): `StatefulShellRoute` con las tres pestañas (`app/main_shell.dart`) y, fuera de la barra, `/recorrido` (en vivo, se abre con `push`: "Atrás" vuelve a Inicio y el viaje sigue) y `/resumen-recorrido` (se abre con `go`). El detalle de un viaje es `/viajes/:id` (`Rutas.detalleViaje`), subruta de Viajes con el navegador raíz: tapa la barra y "atrás" vuelve a la lista. El mapa completo es `/mapa-viaje` (`Rutas.mapaViaje`), en la raíz: se abre con `push` y `extra: DatosMapaViaje`. "Mi DriveScore" es `/inicio/drivescore` (`Rutas.miDriveScore`), igual pero bajo Inicio. El comparativo es `/inicio/drivescore/comparar` (`Rutas.comparativo`), subruta de Mi DriveScore con el navegador raíz; se abre con `push`. Los logros son `/perfil/logros` (`Rutas.logros`), igual pero bajo Perfil. Los desafíos son `/inicio/desafios` (`Rutas.desafios`), igual pero bajo Inicio; se abren con `push`. El Copiloto es `/copiloto` (`Rutas.copiloto`, en la raíz): se abre con `push` desde la hoja "¿Cómo quieres viajar?" y, al iniciar, se reemplaza por `/recorrido` (`pushReplacement`: "Atrás" desde el viaje vuelve a Inicio). Con sesión, el `redirect` solo aparta de arranque, login y registro.
- Login y registro comparten `EncabezadoAuth` (`features/auth/presentation/widgets/auth_header.dart`): alto fijo en el login, ajustado al contenido (mín. 240) en el registro. Las reglas de validación del registro están en `features/auth/models/register_validation.dart` y replican las del backend (p. ej. "letra" = `[A-Za-z]`, sin tildes).
- Formularios: los errores locales se muestran solo después de salir del campo (`CampoFormulario.alPerderFoco`); los de la API (409/422) van debajo de su campo y se borran al editarlo. Los botones dentro de un campo (ojo) van con `ExcludeFocus`, porque si no, el "Siguiente" del teclado salta al botón en vez de al campo siguiente.
- Flujo de sesión (`features/auth/providers/session_provider.dart` + `app/router.dart`): las rutas se deciden solo por `sesionProvider` (`redirect` de GoRouter). Al abrir la app, con token → `GET /auth/yo`: 200 → inicio (o cambio de contraseña si `debe_cambiar_contrasenia`); 401 → borra el token → login; sin conexión o servidor caído (5xx) → entra con el último usuario guardado (`features/auth/data/user_storage.dart`, se guarda en cada login y `/auth/yo` y se borra al cerrar sesión o con 401), y si no hay ninguno, arranque con "Reintentar" (no borra el token). Sirve para continuar un viaje abriendo la app sin señal. No navegar a mano tras login/logout: basta con cambiar el estado de la sesión.

## Recorridos (HU-04, HU-05)

- Estado en `features/recorridos/providers/trip_provider.dart` (`viajeProvider`): `SinViaje` → `ViajeEnCurso` (se publica cada segundo y con cada lectura) → `ViajeTerminado` (pantalla de resumen); al abrir la app, `ViajeInterrumpido` si el backend (`GET /recorridos/activo`) o, sin conexión, el teléfono tienen uno en curso: Inicio ofrece continuarlo o finalizarlo.
- Todo se calcula en el teléfono (`models/trip_accumulator.dart`, Dart puro y con pruebas): distancia sumando tramos (descarta precisión > 20 m, saltos > 200 km/h y temblor con el teléfono quieto), velocidad actual del GPS (0 si no hay lectura en 5 s), máxima de las lecturas aceptadas, promedio = distancia / duración recortado a la máxima, duración con el reloj del teléfono. Umbrales en `UmbralesRecorrido`.
- Decisiones acordadas: al **continuar** un viaje interrumpido, el tramo sin registrar no suma distancia pero el cronómetro sigue contando desde el inicio. Al **finalizar un viaje interrumpido**, la llegada es la hora y la ubicación del último punto registrado.
- Registro en segundo plano: el flujo de geolocator con `foregroundNotificationConfig` corre como servicio en primer plano (notificación fija "DriveSense está registrando tu viaje", ícono `res/drawable/ic_notificacion.xml`) y sigue con la pantalla apagada o la app en segundo plano. **Si se cierra la app desde recientes, el registro se detiene** hasta reabrirla y pulsar "Continuar". Solo se pide ubicación "mientras se usa la app" (no en segundo plano).
- **Finalización automática (viaje olvidado):** si el auto está detenido `UmbralesRecorrido.detenidoParaFinalizar` (3 min) seguidos, el reloj de 1 s llama a `finalizar(automatico: true)`. "Detenido" = ninguna lectura aceptada a `velocidadMovimientoKmh` (8) o más ni a más de `radioDetencionM` (40 m) del punto donde se detuvo (`AcumuladorRecorrido.detenidoDesde`; sin lecturas tampoco se reinicia). El fin es `detenidoDesde` (la espera no cuenta) y `ResumenRecorrido.desde(recortar: true)` quita la ruta y los eventos posteriores. La detención vive solo en memoria: `continuar()` la reinicia. Avisa con una notificación nativa (`data/trip_finished_alert.dart` → `MainActivity.notificarViajeFinalizado`, canal "Avisos de viaje"), `rutasProvider` lleva al resumen desde cualquier pantalla y el resumen muestra el aviso (`ViajeTerminado.automatico`). Para probar sin esperar: `--dart-define=MINUTOS_DETENIDO=1`.
- Al restaurar, si el viaje en curso del backend coincide con el resumen pendiente, se trata como terminado (el reenvío lo cierra): no se ofrece como interrumpido.
- Persistencia (`data/trip_local_storage.dart`, `shared_preferences`): viaje en curso con sus acumulados (cada 5 s) y resumen pendiente (con la ruta), con el id del usuario en la clave. La ruta del viaje en curso va aparte, en `ruta_<usuario>.jsonl` (documentos de la app): cada 5 s se agregan solo los puntos nuevos.
- Resumen pendiente (`providers/pending_summary_provider.dart`): se guarda antes de enviarlo y se reintenta al abrir la app, al volver del segundo plano, cada 30 s y antes de iniciar otro viaje. 200/409 → enviado; 404/422 → se descarta; 401 → se conserva y se cierra sesión; sin conexión/5xx → sigue pendiente. No se puede iniciar otro viaje mientras haya uno pendiente (el backend respondería 409).
- Durante un viaje no se puede iniciar otro ni cerrar sesión.
- Dispositivo: `iniciar` envía `dispositivo_modelo` (`"$manufacturer $model"`), `dispositivo_android` (`version.release`) y `version_app` (`version` de `pubspec.yaml`) con `device_info_plus` y `package_info_plus` (`data/device_data.dart`, `DatosDispositivo.leer()`, leído una vez). Si falla, se omite: no impide el viaje. Sirve para comparar la detección entre teléfonos en el modo pruebas del panel; **subir la versión en `pubspec.yaml` en cada APK que se reparta**.

## Telemetría (HU-07 a HU-13)

- Módulo `features/telemetria/`. `ViajeNotifier` inicia y detiene la captura junto con el seguimiento del GPS.
- Sensores (`data/sensor_service.dart`, `CapturaSensores`): acelerómetro con gravedad y giroscopio pedidos a 50 Hz. Android toma el periodo solo como sugerencia (en el A34 el acelerómetro entrega ~125 Hz): `LimitadorFrecuencia` (`models/rate_limiter.dart`) los deja en ~50 Hz. Cada muestra (`MuestraSensor`: instante del sensor + x, y, z) va a un `BuferCircular` por sensor (`models/sensor_buffer.dart`, 500 muestras ≈ 10 s, con `ventana()`): es lo que consumirán el filtro (HU-09) y los detectores (HU-10 a 13). Siguen llegando con la pantalla apagada gracias al servicio en primer plano de geolocator (verificado en el A34 en un viaje real de 15 min: sin huecos; con la pantalla apagada el acelerómetro baja de ~125 a ~50-70 Hz, el giroscopio sigue en 50). Al conectarse, Android entrega primero la última lectura guardada con su instante viejo (la del viaje anterior): se descartan las muestras anteriores al inicio de la captura.
- Sin giroscopio (`NO_SENSOR`) el viaje sigue y `ViajeActivo.sinGiroscopio` queda en `true` ("sin detección de giros"). **Solo en la app**; el backend no lo recibe.
- Ruta (`models/route.dart`, `ConstructorRuta`): con las lecturas que el acumulador acepta, un punto cada 5 s o 20 m (`UmbralesRuta`). Al pasar de 10 000 puntos (límite del backend) se diezma (uno de cada dos). Se envía en el resumen (también al reenviar un pendiente).
- Solo en la versión de desarrollo (`kDebugMode`): panel de diagnóstico en la pantalla en vivo (Hz del búfer y, entre paréntesis, del sensor; valores actuales; precisión GPS; puntos de ruta; señal filtrada de HU-09 con el motivo si se descarta; va debajo de la tarjeta de eventos de HU-14) y modo calibración (interruptor en Perfil, `modoCalibracionProvider`): graba `calibracion_<recorrido>.csv` con **todas** las muestras crudas y todas las lecturas GPS (`tipo,fecha_us,x,y,z,lat,lon,precision_m,velocidad_ms,etiqueta`). Mientras graba, la pantalla en vivo muestra "Marcar maniobra" (`telemetria/presentation/widgets/maneuver_mark_sheet.dart`): una hoja con Frenada fuerte, Aceleración fuerte, Giro brusco, Bache y Teléfono movido (`TipoMarca`) escribe una fila `marca` con el instante **del toque al botón** (no al elegir) y la maniobra en `etiqueta` (`frenada_fuerte`, `aceleracion_fuerte`, `giro_brusco`, `bache`, `telefono_movido`); las demás filas la dejan vacía. El panel de diagnóstico cuenta las marcas de cada tipo de la sesión (al continuar un viaje interrumpido vuelve a cero; el CSV conserva todas). Al continuar un viaje interrumpido sigue en el mismo archivo; al iniciar otro se borran los anteriores. El resumen ofrece "Compartir datos de calibración".

### Umbrales acordados (HU-10 a HU-13)

Implementados. Son un estándar para conducción urbana en autos particulares (~0,2-0,45 g, el rango habitual de las apps de telemetría y seguros), no lo que alcanza un auto en particular: un viaje normal no debe disparar eventos. Se validaron con dos viajes reales del A34 (`calibracion_63.csv` con maniobras intencionales y marcas, `calibracion_64.csv` tranquilo; fuera del repo).

| Evento | Umbral | Medición | Eventos esperados (63 / 64) |
|---|---|---|---|
| Frenada brusca (HU-10) | ≥ 2,5 m/s² (~0,25 g, −9 km/h en 1 s), si la lectura anterior iba a ≥ 10 km/h | caída de la velocidad del GPS entre lecturas seguidas (1 Hz) | 5 / 1 |
| Aceleración severa (HU-11) | ≥ 2,0 m/s² (~0,2 g, +7,2 km/h en 1 s), si la lectura actual llega a ≥ 8 km/h | subida de la velocidad del GPS entre lecturas seguidas | 2 / 1 |
| Giro agresivo (HU-12) | aceleración lateral ≥ 3,5 m/s² (~0,35 g), solo a más de 15 km/h | velocidad del GPS × velocidad angular del giroscopio sobre el eje vertical (gravedad estimada con una ventana de ~30 s), promediada 1 s | 1 / sin verificar |
| Exceso de velocidad (HU-13) | > 60 km/h durante ≥ 5 s seguidos (límite fijo, sin límites por vía) | velocidad del GPS confirmada por el filtro | 1 / 0 |

- Cada valor del GPS es el promedio de 1 s: la maniobra debe durar ~1 s y un golpe suelto no la dispara.
- Un evento por maniobra: el mismo tipo no se repite hasta que el valor vuelva bajo el umbral, con al menos 3 s de separación. En el exceso de velocidad, un evento por tramo sobre el límite.
- Un solo nivel por ahora. Si el DriveScore (HU-15/16) necesita severidad, se agrega después.
- Entradas (de `FiltroSenal`, HU-09): HU-10/11 usan `velocidades` (diferencia entre lecturas seguidas); HU-12 usa `giroRadS` × la velocidad y solo evalúa intervalos `confiable(desde, hasta)`.
- Al implementarlos: valores en `UmbralesDeteccion` y, como prueba de aceptación, pasar los dos CSV (`test/fixtures/gps_63.csv` y `gps_64.csv`, solo GPS y sin posición) y obtener exactamente los eventos de la tabla.
- **Ajuste del 18-nov-2026** (antes: frenada ≥ 3,0, aceleración ≥ 2,5, ambas solo en tramos `confiable`): en un viaje real con el teléfono en la mano no se detectó un 40 → 10 km/h en ~2 s. Se bajaron los umbrales y se dejó de exigir `confiable` (mover el teléfono no altera la velocidad del GPS). Con la frenada en 2,0 el viaje tranquilo (64) sumaba 4 paradas normales (2,1-2,4 m/s²); con 2,5 queda en 1. Las velocidades mínimas evitan el ruido del GPS parado (hasta ~7 km/h); con 10 km/h en la aceleración se perdía el arranque 0 → 9,9 km/h del 63. Comparar el cambio en una ventana de varios segundos no sirve: el promedio nunca supera el segundo más fuerte.
- Frenadas del 63: la marcada (43 → 33 → 22 km/h; se detecta en el primer tramo, 2,86 m/s²), la que antes salía sin marcar (26 → 14 km/h, 3,22 m/s²) y tres más sin marcar de 2,56-2,81 m/s². En el 64, la misma de antes (30 km/h, 3,22 m/s²).
- Aceleraciones: en los dos viajes, un arranque desde parado (63 sin marcar: 0 → 9,9 km/h, 2,74 m/s²; 64: 0 → 12,9 km/h, 3,59 m/s²) y, en el 63, un tirón desde 19 km/h (2,26 m/s²).
- Giros: en el 63, una curva sin marcar a 59 km/h (3,51 m/s²); los tres giros marcados llegaron a 2,5-3,0 m/s² y no disparan. Se acordó mantener el umbral. En los viajes 110 y 111 (18-nov) las curvas más fuertes llegaron a 2,2-2,9 m/s² a 15-21 km/h, que el conductor no sintió bruscas: se volvió a acordar mantener 3,5. El 64 no se pudo verificar: su CSV completo ya no está (solo `gps_64.csv` y `parada_64.csv`).
- Verificado también con el `calibracion_63.csv` completo (sensores y GPS), con los umbrales anteriores: 2 frenadas, 1 aceleración, 1 giro.

### Detección de eventos (HU-10 a HU-13)

`models/event_detector.dart`, Dart puro: `DetectorEventos` vive en `CapturaSensores` (`detector`) y se evalúa tras cada lectura del GPS (`CapturaSensores.gps`) con la última velocidad confirmada de `FiltroSenal` y la anterior. Se reinicia con la captura.
- Cambio de velocidad `(v actual − v previa) / dt`: frenada brusca si baja ≥ 2,5 m/s² desde 10 km/h o más (`velocidadMinimaFrenadaKmh`), aceleración severa si sube ≥ 2,0 m/s² hasta 8 km/h o más (`velocidadMinimaAceleracionKmh`) (`TipoEvento`: código JSON; umbrales en `UmbralesDeteccion`). No se evalúa con un hueco de más de 3 s (no cambia el estado de la maniobra). **No usa `confiable`**: un bache o el teléfono movido no alteran la velocidad del GPS (igual que el exceso).
- Giro agresivo (`evaluarGiro`, tras cada muestra del giroscopio): `|giroRadS| × última velocidad confirmada ≥ 3,5 m/s²`, solo a más de 15 km/h. No se evalúa sin giroscopio, si la velocidad tiene más de 3 s (GPS sin señal) ni si el último segundo no es `confiable`.
- Exceso de velocidad (`_evaluarExceso`, con cada velocidad confirmada): sobre 60 km/h durante 5 s seguidos, un evento por tramo. Se crea al cumplir los 5 s (`enCurso: true`) y **se vuelve a avisar con cada lectura del tramo** con `velocidadMaximaMs` y `duracionS` (de la primera a la última lectura sobre el límite) actualizadas. Se avisa cerrado (`enCurso: false`) al bajar a 60 km/h o menos o tras un hueco de más de 3 s (el tramo vuelve a empezar). No usa `confiable` (un bache no altera la velocidad del GPS).
- `alDetectar` recibe eventos nuevos o actualizados: `ViajeActivo.registrarEvento` reemplaza el de igual `tipo` y `fecha`. `ViajeActivo.cerrarEventosEnCurso()` cierra el exceso abierto con lo acumulado al **finalizar** (sin guardar: el viaje se borra enseguida) y al **continuar** un viaje interrumpido (y se guarda); `DetectorEventos.reiniciar()` no avisa nada.
- El estado de la maniobra (sobre el umbral, último evento) es **por tipo** (`_registrar`): una frenada no bloquea la aceleración que sigue.
- `EventoRiesgo`: `tipo` (`frenada_brusca` | `aceleracion_severa` | `giro_agresivo` | `exceso_velocidad`), `fecha` (en los giros, la de la muestra del giroscopio; en el exceso, la de la primera lectura sobre el límite, igual que la posición), `latitud` y `longitud` de la lectura con la que se detecta (`VelocidadFiltrada` lleva la posición), `intensidad` (siempre positiva; m/s² en frenadas, aceleraciones y giros, en el exceso, m/s de la máxima sobre el límite; JSON `intensidad`, y se lee también la clave anterior `intensidad_ms2`) y `velocidadPreviaMs` (en los giros, la velocidad durante el giro; en el exceso, la de la primera lectura sobre el límite) y, solo en el exceso, `velocidadMaximaMs`, `duracionS` y `enCurso` (JSON `velocidad_maxima_ms`, `duracion_s`, `en_curso`; un evento guardado sin ellos se lee con `null`/`false`).
- Se guardan en `ViajeActivo.eventos` (JSON `eventos`; un viaje guardado sin la clave los lee vacíos) y el viaje se guarda en el teléfono **en cuanto se detecta o actualiza uno** (durante un exceso, cada segundo), además del guardado cada 5 s: si la app se cierra de golpe, el exceso queda con la máxima y la duración hasta la última lectura. Al continuar un viaje interrumpido se conservan.
- Se envían al backend en el resumen del viaje (HU-15, ver "DriveScore").
- Pruebas: `test/event_detector_test.dart` (incluye los ejemplos 20 → 5 → 0 km/h, 40 → 10 en 3 s, 2 → 20 → 30, el ruido parado y el teléfono movido). Umbrales del 18-nov verificados en dos viajes reales del A34 con el teléfono en soporte (`calibracion_110.csv` y `_111.csv`, fuera del repo, sin marcas): frenadas y aceleraciones como las percibió el conductor (110: 4 y 5; 111: 3 y 2), ningún tramo descartado salvo la vertical inicial.

### Filtro de señal (HU-09)

`models/signal_filter.dart`, Dart puro: `FiltroSenal` vive en `CapturaSensores` (`filtro`), recibe las muestras que deja pasar `LimitadorFrecuencia` (~50 Hz, cualquiera sea la frecuencia del teléfono) y las lecturas del GPS (`ViajeNotifier` → `CapturaSensores.gps`). Se reinicia con la captura. No detecta eventos; nada se envía ni se guarda en el historial.
- `velocidades`: lecturas del GPS confirmadas (últimos 30 s), sin las de precisión > 20 m, sin velocidad (< 0) ni los saltos de una sola lectura (≥ 1,5 m/s hacia abajo y de vuelta, o al revés, con vecinas a ≤ 3 s; en el viaje 64 hubo 5 instantes en 0 km/h). Llegan con una lectura de retraso.
- `giroRadS`: giro alrededor de la vertical (giroscopio · gravedad), media de 1 s, 0 bajo 0,03 rad/s (sesgo del giroscopio). `null` sin giroscopio o los primeros ~3 s. No depende de cómo esté puesto el teléfono.
- Vertical: media del acelerómetro de los últimos 30 s, en sumas por segundo.
- `confiable(desde, hasta)` / `descarte`: tramos descartados. **Bache**: golpe vertical (media 0,1 s) ≥ 5 m/s², ±1 s. **Teléfono movido**: rotación fuera de la vertical (media 0,2 s) ≥ 1 rad/s, o la orientación de 1 s a ≥ 35° de la gravedad durante 2 s; desde 1 s antes hasta 2 s después. En el segundo caso la vertical vuelve a empezar con la posición nueva.
- Valores en `UmbralesFiltro`, medidos en los viajes 63 y 64: manejando, la rotación no pasó de 0,7 rad/s, el ángulo de 26,5° y el golpe vertical de ~7 m/s². Con ellos se descartan 2-3 s por viaje (solo baches) y ninguna maniobra marcada. **Pendiente**: calibrar bache y teléfono movido con un viaje que tenga esas marcas.
- Pruebas: `test/signal_filter_test.dart`, sintéticas y con tramos reales en `test/fixtures/` (sin latitud ni longitud).

### Avisos en tiempo real (HU-14)

- Lógica pura en `telemetria/models/live_alerts.dart`: `GestorAvisos` decide qué avisa (un evento puntual nuevo o el inicio de un exceso; no las actualizaciones ni el cierre del exceso) y recuerda el último puntual; `AvisoEnVivo.de` decide qué se muestra: el puntual durante **4 s** (`UmbralesAviso.duracionPuntual`; uno nuevo reemplaza al anterior y reinicia el plazo) y, si no, el exceso abierto (`enCurso`). `ViajeEnCurso.aviso` lo expone con `avisoPuntual`/`avisoPuntualDesde`, que publica `ViajeNotifier` (se publica en cuanto llega el evento y cada segundo).
- `registrarYAvisar` (en `trip_provider.dart`): registra el evento en el viaje (`registrarEvento` devuelve si es nuevo) y, si avisa, llama a `AvisosEvento.avisar(sonido:)` (`telemetria/data/event_alert_service.dart`).
- Pantalla en vivo (`BloqueVelocidadEnVivo`): puntual → aro y punto de la diana en el color del tipo y `CapsulaEvento` en lugar de "Máxima"; exceso → número de velocidad y punto en `eventoVelocidad` y `CapsulaExceso` ("Sobre el límite de 60" + `m:ss` de `duracionS`). Una sola cápsula (`AnimatedSwitcher` que quita la anterior al instante y funde la nueva) en un espacio de alto fijo (`Medidas.altoCapsulaEvento`): la velocidad no salta al cambiar. Revisado en el A34 (vista previa temporal con estados simulados): avisos, colores y vibración también con la pantalla apagada. Colores, íconos y nombres por tipo en `EstiloEvento` (`recorridos/presentation/widgets/live_alert_capsules.dart`).
- `TarjetaEventosViaje` (`widgets/trip_events_card.dart`): contadores por tipo de `viaje.eventos` (incluye los de antes de continuar), en 0 en gris. Reemplazó al aviso "Puedes apagar la pantalla". La parte clara de la pantalla es desplazable; "Finalizar viaje" queda fijo.
- Vibración y sonido: canal `drivesense/sistema`, método `avisarEvento` (`MainActivity.kt`): vibración de 250 ms con uso "notificación" y, si `sonido`, `ToneGenerator` de 150 ms por `STREAM_NOTIFICATION` (respeta silencio y "no molestar"). Permiso `VIBRATE`. Funciona con la pantalla apagada porque el servicio en primer plano de geolocator mantiene vivo el proceso y el detector corre en el isolate principal. **Pendiente: verificarlo en el A34** con la pantalla apagada.
- Preferencia "Sonido de avisos" (`sonidoAvisosProvider`, `SharedPreferencesAsync`, clave `sonido_avisos`, activada por defecto), en Perfil; silenciada, solo vibra.

#### Notificaciones de eventos (mejora de HU-14)

Notificaciones locales del sistema, sin Firebase ni servidor, para ver el evento con la pantalla bloqueada o la app en segundo plano.
- **Cuándo**: solo los eventos que ya avisan (`GestorAvisos.registrar` = `true`: un puntual nuevo o el inicio de un exceso; nunca sus actualizaciones ni el cierre) y solo si la app **no está en pantalla** (`WidgetsBinding.instance.lifecycleState != resumed`; con la pantalla bloqueada y la app abierta, sí notifica). Con la app en pantalla basta la vibración de siempre.
- **Tiempo mínimo**: **30 s** entre una notificación y la siguiente (`UmbralesAviso.entreNotificaciones`, `LimitadorNotificaciones` en `live_alerts.dart`). Los eventos de ese lapso no notifican, pero vibran, suenan y se registran como siempre. Un evento con la app en pantalla no gasta el plazo. Se reinicia al iniciar o continuar un viaje.
- **Textos** (`tituloNotificacionEvento`, `textoNotificacionEvento`): título "Frenada brusca detectada", "Aceleración severa detectada", "Giro agresivo detectado" o "Exceso de velocidad detectado"; texto "Toca para volver a tu viaje.".
- **Flujo**: `registrarYAvisar` (con `enPantalla` y el limitador) → `AvisosEvento.notificar` → `MainActivity.notificarEvento` (canal `drivesense/sistema`). Un solo id (`ID_EVENTO` = 1002): la nueva reemplaza a la anterior; `quitarNotificacionEvento` la borra al finalizar el viaje (manual o automático).
- **Canal propio** `eventos_riesgo`, "Eventos de riesgo" (descripción "Avisos de frenadas, aceleraciones, giros y excesos durante el viaje"): importancia alta (emergente, también sobre la pantalla de bloqueo, visibilidad pública), **sin sonido ni vibración propios**: los pone `avisarEvento`, así no vibra dos veces y se respeta "Sonido de avisos". El conductor puede silenciarlo o bloquearlo en Ajustes > Notificaciones del teléfono; eso quita el cartel, no la vibración ni el tono de la app. El viaje finalizado solo sigue en su canal `avisos_viaje` ("Avisos de viaje").
- **Al tocarla**: el intent lleva el extra `abrir = recorrido`; la actividad es `singleTop`, así que llega a `onNewIntent`, que llama a `abrirRecorrido` en Dart (`alTocarNotificacionEvento`, `core/platform/system_navigation.dart`). `rutasProvider` hace `push(Rutas.recorrido)` si hay un `ViajeEnCurso` y no se está ya en esa pantalla; sin viaje en curso se queda donde está. No hay caso de arranque en frío: si la actividad se cerró, el motor de Dart y el registro también, y la app abre en Inicio con "Continuar viaje".
- **Permiso** (Android 13+, `POST_NOTIFICATIONS`): se pide la primera vez que se inicia o continúa un viaje, después de la hoja "Antes de empezar" (el motivo "Notificaciones" explica los avisos con la pantalla apagada y el aviso fijo). Si lo niega, el viaje se registra igual y un `SnackBar` dice "Sin notificaciones no verás los avisos con la pantalla apagada. El viaje se registra igual." (`ServicioUbicacion.notificacionesNegadas`). En Perfil, bajo "Sonido de avisos", "Notificaciones desactivadas: …" con "Activar" (ajustes de la app) mientras siga negado (`notificacionesPermitidasProvider`, se revisa al volver a la app).
- **Segundo plano**: el servicio en primer plano de geolocator (notificación fija "Viaje en curso" / "DriveSense está registrando tu viaje", canal "Recorridos", con wakelock) mantiene vivos el proceso, los sensores y el detector con la pantalla apagada. Acordado: no se pide excluir la app de la optimización de batería.
- Pruebas en `test/live_alerts_test.dart` (grupo "Notificación del sistema"). **Pendiente: probarlo en el A34 en un viaje real** (pantalla apagada y en segundo plano, 30 s, tocarla, silenciar el canal, negar el permiso).
- Pruebas: `test/live_alerts_test.dart`.

## DriveScore (HU-15)

- Envío: `ResumenRecorrido.eventos` (de `viaje.eventos`, ya cerrados al finalizar) va en el `PATCH .../finalizar` (`EventoRiesgo.toApiJson`: velocidades en km/h; solo el exceso con `duracion_s` y `velocidad_maxima_kmh`). El resumen pendiente se guarda con `toJson` (incluye `toApiJson`): **el reintento lleva los eventos**; `fromJson` los lee con `EventoRiesgo.desdeApi`. Un pendiente de una versión anterior (sin `eventos`) se envía sin el campo.
- Puntaje: `PuntajeViaje` (`models/trip_score.dart`, `drivescore` y las 4 categorías; nulo si la respuesta no lo trae) en `Recorrido` (respuesta del PATCH) y `RecorridoHistorial` (solo el detalle lo trae). `Calificacion.de`: Excelente 90–100, Muy bueno 75–89, Regular 60–74, Riesgoso < 60.
- `Envio.puntaje`: de la respuesta; con 409 (ya finalizado, se perdió la respuesta) se pide `GET /recorridos/{id}`, y si falla queda nulo. `ViajeTerminado.puntaje` sale de ahí. Si el resumen estaba pendiente y el reintento llega al backend con la pantalla abierta, `ResumenPendienteNotifier` avisa a `ViajeNotifier.alEnviarResumen` y el anillo se actualiza.
- Pantalla de resumen: desde HU-29 es el diseño 1 (ver "Mapa del viaje"). La tarjeta del DriveScore usa `AnilloDriveScore.claro` (`widgets/drive_score_ring.dart`; con `esperando`, la nube) y la calificación con `colorCalificacion`; pendiente: "Calculando tu DriveScore"; sin puntaje: "—". Las cifras van en una fila de 4 (`FilaCifras`, `widgets/trip_figures_row.dart`, también en el detalle).
- Pruebas: `test/drive_score_test.dart`.

## Desglose del DriveScore (HU-16)

- `CategoriaPuntaje` (`models/trip_score.dart`): frenadas, aceleraciones, giros y velocidad, en ese orden, con su peso (el del backend) y su `TipoEvento` (colores e íconos de `EstiloEvento`). `PuntajeViaje.masResto`: la de menor puntaje bajo 100; en empate, la de mayor riesgo (`CategoriaPuntaje.porRiesgo`: velocidad, frenadas, giros, aceleraciones; el mismo desempate de la recomendación del backend, HU-18); nula si todas están en 100.
- `DesgloseCategorias` (`widgets/score_breakdown.dart`): las cuatro barras; con `eventosPorTipo`, "1 frenada" / "Sin eventos" bajo el nombre. `textoMasResto`: "Lo que más restó: frenadas" o, sin eventos, "Sin eventos de riesgo. ¡Sigue así!" (nada si hubo eventos pero todo quedó en 100).
- Resumen: "Lo que más restó" junto a la calificación (sin eventos según `resumen.eventos`; un pendiente de una versión anterior no los trae). Desde HU-29 el resumen ya no tiene la tarjeta "Puntaje por categoría": la flecha de la tarjeta del DriveScore abre el detalle.
- Detalle (diseño D): tarjeta con `AnilloDriveScore.claro`, calificación, "Lo que más restó" (sin eventos según `eventosPorTipo`) y el desglose; desde HU-29 sin la cantidad de eventos bajo cada categoría (van en la tarjeta de contadores, con `eventos_por_tipo` del `GET /recorridos/{id}`). Debajo, `FilaCifras`. Sin puntaje (viajes anteriores a HU-15) solo van las cifras.
- Pruebas: `test/drive_score_test.dart` (resumen) y `test/trip_history_test.dart` (detalle).

## Mapa del viaje (HU-29)

- Proveedor: OpenStreetMap con `flutter_map` (`https://tile.openstreetmap.org`, `userAgentPackageName: com.drivesense.drivesense`, como pide su política de uso). Atribución "© OpenStreetMap" siempre visible; abre openstreetmap.org/copyright. flutter_map guarda los mosaicos en su caché (`path_provider`): un mapa ya visto puede verse sin conexión. flutter_map avisa en la consola que los servidores públicos de OSM no son para cualquier uso: para producción conviene evaluar otro proveedor (solo cambia `trip_map.dart`).
- `MapaViaje` (`presentation/widgets/trip_map.dart`) es **el único archivo que importa flutter_map/latlong2**: recibe `ruta` (`List<PuntoRuta>`) y `eventos` (`List<EventoRiesgo>`) más `seleccionado`, `alTocarEvento`, `alTocar` (mapa fijo), `interactivo`, `relleno` (lo que tapan los controles), `ControladorMapaViaje` (`verRutaCompleta()`) y `alCambiarDisponibilidad`. Cambiar de proveedor = cambiar ese archivo.
- La ruta se simplifica una vez al recibirla (`simplificarRuta`, `models/route_simplifier.dart`: Douglas-Peucker iterativo en metros, tolerancia de 5 m en `UmbralesMapa`, conserva los extremos); además `PolylineLayer` simplifica por zoom. Al abrir encuadra la ruta y los eventos (zoom ≤ 17); un evento elegido se centra en la zona visible (zoom ≥ 16, animación de 450 ms hecha en el widget) con la burbuja `BurbujaEvento` encima.
- Sin internet: si fallan los mosaicos sin que haya cargado ninguno, `MapaViaje` muestra "Sin conexión" con "Reintentar" en lugar del mapa y llama a `alCambiarDisponibilidad(false)`; el resumen y el detalle ocultan expandir, la cápsula de eventos y "Ver mapa completo".
- Resumen (diseño 1, `trip_summary_screen.dart`): bloque oscuro con el check y "Viaje guardado"; la tarjeta del mapa (con `resumen.ruta` y `resumen.eventos`, del teléfono: no necesita el backend), los contadores (`FilaConteoEventos`, `widgets/event_counts_row.dart`) y "Ver mapa completo"; la tarjeta del DriveScore, cuya flecha abre el detalle (solo si quedó finalizado), y las cifras. Sin ruta: solo los contadores; sin ruta ni eventos (pendiente de una versión anterior), sin la tarjeta.
- Detalle (diseño 3): con ruta (`RecorridoHistorial.ruta`, 2 puntos o más) el mapa fijo reemplaza la cabecera de degradado y la tarjeta superpuesta lleva fecha, "salida → llegada" y la distancia; sin ruta, el detalle anterior. Los eventos con posición vienen en `eventos` del `GET /recorridos/{id}` (`RecorridoHistorial.eventos`, leídos con `EventoRiesgo.desdeApi`).
- Mapa completo (`trip_map_screen.dart`, `MapaViajePantalla` con `DatosMapaViaje`): filtros por tipo (solo los que tuvieron eventos) y hoja arrastrable con la lista; tocar una fila o un marcador lo elige; "ver la ruta entera" quita la selección y reencuadra; un filtro que oculta al elegido lo deselecciona. Botones sobre el mapa: `BotonMapa` (`widgets/map_button.dart`).
- Textos: `FormatoEvento.detalle` (`trip_format.dart`): "3,4 m/s² · a 38 km/h" (frenada, giro), "2,8 m/s² · desde 10 km/h" (aceleración), "9 s · máx. 68 km/h" (exceso; desde 1 min, `m:ss`). `EstiloEvento.plural` ("Aceleraciones", "Excesos") y `EstiloEvento.halo`.
- Pruebas: `test/trip_map_test.dart` (simplificación, textos, mapa completo) y `test/trip_map_offline_test.dart` (aviso sin conexión; va aparte porque la caché de mosaicos es única por proceso y queda atada al reloj falso de la primera prueba que la usa). En las pruebas toda petición HTTP responde 400, así que los mosaicos fallan solos; la caché necesita un `path_provider` simulado.

## Inicio (diseño B)

- `features/inicio/presentation/home_screen.dart`. Barra de estado con íconos claros solo aquí (`AnnotatedRegion` con `SystemUiOverlayStyle.dark` + íconos claros; las demás pestañas usan el `dark` de `main_shell.dart`).
- Encabezado oscuro: saludo según la hora (`saludoSegunHora`: < 12 días, < 19 tardes, si no noches; `InicioPantalla(reloj:)` para las pruebas), primer nombre y, de `historicoPuntajeProvider(dias7)`: con tendencia, la cápsula "▲ 4 pts en 7 días" (`CapsulaTendencia(sobreOscuro)`); sin viajes con puntaje, "Tu DriveScore aparecerá después de tu primer viaje"; con menos de 3 **en total** (`viajes_totales`), el anillo con `promedio_total` y "Haz N viajes más…"; con 3 o más sin viajes en 7 días, "—" y el aviso. Cargando y error ocupan el mismo alto (`Medidas.altoLineaEstadoInicio`). El anillo abre Mi DriveScore si hay viajes con puntaje.
- Botón flotante del recorrido (mitad sobre el borde): "Iniciar recorrido", "Volver al viaje" (en curso) o "Continuar viaje" (interrumpido, con el aviso y "Finalizar" debajo); conserva la lógica de la tarjeta anterior. Debajo también el aviso de resumen pendiente y los errores.
- "Esta semana" = `historialProvider(PeriodoHistorial.semana).resumen` (comparte caché con Viajes); "Mis viajes" → `Rutas.viajes`. Formatos `kilometrosEnteros` y `duracionCompacta`.
- "Desafíos de la semana" (HU-22): bajo "Esta semana", ver "Desafíos semanales".
- "Último viaje" = `ultimoViajeProvider` (`GET /recorridos?limite=1`); cápsula con su `drivescore` (el listado lo trae; nulo → sin cápsula); abre el detalle. Sin viajes, no aparece. `ResumenPendienteNotifier` invalida semana, último viaje y DriveScore al recibir el backend un viaje.
- "Consejo" (HU-18): bajo el último viaje, ver "Recomendaciones".
- Pruebas: `test/home_screen_test.dart`.

## Recomendaciones (HU-18, HU-19)

- Las genera el backend al finalizar (reglas fijas eligen el tipo que más restó, con el mismo criterio que "Lo que más restó"; el título y el texto los redacta la IA con los datos del viaje o, si no responde, salen de una plantilla). Módulo `features/recomendaciones/`: `Recomendacion` (`models/recommendation.dart`: `tipo` = `TipoEvento`, nulo en el mensaje positivo `sin_eventos`; `titulo`, `texto`; `generadaPorIa` de `generada_por_ia`, falso si no viene; `fromJson` devuelve nulo sin la clave o con `null`). `CapsulaIA` ("Con IA", en `recommendation_card.dart`) marca los de la IA junto a "Consejo" y a "También puedes mejorar" y `TarjetaConsejo` (`presentation/widgets/recommendation_card.dart`, diseño en `docs/diseno.md`).
- Se lee en `Recorrido` (respuesta del PATCH) y `RecorridoHistorial` (solo el detalle). `Envio.recomendacion` sale de la misma fuente que el puntaje (con 409, del `GET /recorridos/{id}`) y llega a `ViajeTerminado.recomendacion`; con un pendiente, aparece cuando el reintento llega al backend (`alEnviarResumen`).
- Resumen y detalle: entre la tarjeta del DriveScore y las cifras; sin recomendación (pendiente, descartado, viaje anterior a HU-15), sin tarjeta. Inicio: `_Consejo`, con `detalleRecorridoProvider(último.id)` (comparte caché con el detalle; el listado no la trae); mientras carga, con error o sin recomendación no aparece; tocarla abre el detalle.
- Secundarias (HU-19): `recomendaciones_secundarias` del backend (como máximo 2, en orden; nunca del tipo de la principal) en `Recorrido.secundarias` y `RecorridoHistorial.secundarias` (`Recomendacion.listaDesdeJson`: vacía sin la clave). Viajan igual que la principal (`Envio.secundarias` → `ViajeTerminado.secundarias`). `ConsejosSecundarios` (`presentation/widgets/secondary_recommendations.dart`) va justo debajo de `TarjetaConsejo` en el resumen y el detalle; lista vacía → no aparece. **Inicio muestra solo la principal.** La caja del ícono de las dos tarjetas sale de `estiloConsejo` (`recommendation_card.dart`).
- Pruebas: `test/drive_score_test.dart` (lectura y resumen), `test/trip_history_test.dart` (detalle) y `test/home_screen_test.dart` (Inicio).

## Histórico del DriveScore (HU-17)

- Módulo `features/puntaje/`: `GET /puntaje/historico?desde=...` (`PuntajeRepositorio`, `desde` en UTC) → `HistoricoPuntaje` (`models/score_history.dart`). Promedios ponderados por distancia, calculados en el backend; los puntos vienen por viaje (7 días), por día (30) o por semana (3 meses).
- `PeriodoPuntaje`: 7 días, 30 días, 3 meses = desde la medianoche local de hace 6, 29 y 89 días hasta ahora. `historicoPuntajeProvider` (familia por periodo; `null` sin sesión; `conSesion` cierra la sesión con 401). `ResumenPendienteNotifier` lo invalida junto con el historial cuando el backend recibe un viaje: Inicio se actualiza al finalizar.
- En Inicio, el encabezado (ver "Inicio") usa el periodo de 7 días con los mismos casos que tenía la tarjeta de HU-17 (que el rediseño B reemplazó, junto con su línea).
- Pantalla `presentation/score_history_screen.dart`: chips de periodo (`ChipsPeriodo`, `core/widgets/period_chips.dart`, compartidos con el historial), promedio con calificación y tendencia, gráfico (`GraficoDriveScore`), promedio por categoría (`FilaCategoria` del desglose de HU-16 con `DiferenciaCategoria`), mejor y peor viaje (abren el detalle; con un viaje, solo el mejor). Periodo sin viajes: botones para los otros periodos. Error: `ErrorCarga`.
- Gráficos con `CustomPainter` (`PintorLineaPuntaje`, `presentation/widgets/score_chart.dart`), sin librería. Con un solo punto, solo el punto.
- Pruebas: `test/score_history_test.dart` (modelo y pantalla con un `PuntajeRepositorio` falso).

## Comparativo entre periodos (HU-20)

- `GET /puntaje/comparativo?periodo=semana|mes&desde=...` (`PuntajeRepositorio.comparativo`) → `ComparativoPuntaje` (`models/period_comparison.dart`). Todo el cálculo (promedios ponderados por distancia, diferencias, si mejoró o empeoró, destacados y el mínimo de viajes) es del backend; la app solo lo muestra.
- `PeriodoComparativo`: semana (desde el lunes) y mes (desde el día 1), a medianoche local, con el mismo cálculo que `PeriodoHistorial`. **`desde` va con la zona del teléfono, no en UTC** (`isoConZona` en `data/score_repository.dart`): el backend comprueba que sea lunes o día 1 a medianoche en esa zona y calcula el periodo anterior.
- `comparativoPuntajeProvider` (familia por periodo, `conSesion`, sin reintentos); `ResumenPendienteNotifier` lo invalida junto con el histórico.
- Pantalla `presentation/period_comparison_screen.dart` (`ComparativoPantalla`): chips Semana / Mes; tarjeta del DriveScore (actual y anterior, con calificación y `CapsulaTendencia`); "Lo que más mejoró" / "Lo que más empeoró" (si falta una, la otra ocupa el ancho; sin ninguna, no aparecen); "Por categoría" (`FilaCategoria` + `DiferenciaCategoria`); "Actividad": viajes, km y eventos cada 10 km con el valor del periodo anterior debajo y `CambioCifra` (`widgets/trend_badge.dart`): viajes y km en gris (acordado: no son mejores ni peores), eventos con el color del `resultado` del backend (▼ en verde). Sin el mínimo (`minimo_viajes` del backend, hoy 2): "No hay datos para comparar", cuántos viajes lleva cada periodo y "Ver mes" / "Ver semana".
- Acceso: tarjeta "Comparar periodos" al final de Mi DriveScore (`_TarjetaComparar`), también con el periodo vacío. La cabecera (volver + título) y la tarjeta grande son comunes (`core/widgets/screen_header.dart`: `CabeceraPantalla`, `BotonVolverCaja`, `decoracionTarjeta`).
- Pruebas: `test/period_comparison_test.dart` (modelo, `desde`, zona y pantalla con un `PuntajeRepositorio` falso).

## Nivel y logros (HU-21)

- Todo lo calcula el backend (fórmula de puntos, niveles y lista de logros en su CLAUDE.md); la app solo muestra. Módulo `features/gamificacion/`: `GET /gamificacion/progreso` (`GamificacionRepositorio`) → `ProgresoConductor` (`models/progress.dart`: `Nivel`, `Logro` con `tipo`/`meta`/`progreso` y `faltante` ("Te faltan 3 viajes", "63 de 100 km", "Racha actual: 3 de 5"), `avance` dentro del nivel). `progresoProvider` (`conSesion`, sin reintentos); `ResumenPendienteNotifier` lo invalida al recibir el backend un viaje.
- Perfil: `TarjetaNivel` (`presentation/widgets/level_card.dart`) bajo la tarjeta del usuario: nivel, puntos, `BarraProgreso` al siguiente, "Te faltan N pts para …" (o "Alcanzaste el nivel máximo") y la fila "Logros · X de 9" que abre `LogrosPantalla` (`presentation/achievements_screen.dart`): resumen, "Desbloqueados" con "Desbloqueado el 3 de noviembre" (`FormatoViaje.diaMes`) y "Pendientes" con barra (no en los de un solo viaje) y lo que falta. Ícono de cada logro: `iconoLogro` (`widgets/achievement_widgets.dart`, con `CajaLogro` y `BarraProgreso`).
- Resumen del viaje: `RecompensaViaje` llega en la respuesta del PATCH (`Recorrido.recompensa` → `ViajeTerminado.recompensa`, también con el reintento de un pendiente vía `alEnviarResumen`). `TarjetaRecompensa` (`widgets/reward_card.dart`) va entre el DriveScore y el consejo **solo si subió de nivel, hubo logros nuevos o completó algún desafío semanal** (`hayNovedades`, HU-23); abre los logros. Con 409 (respuesta perdida) no hay recompensa: el detalle no la trae (los puntos de los desafíos igual se suman en el backend y se ven en Perfil y en la pantalla de desafíos).
- Pruebas: `test/gamification_test.dart` (modelo incluida la recompensa con desafíos y bono, tarjeta de Perfil, pantalla de logros) y `test/drive_score_test.dart` (tarjeta del resumen, con desafíos y bono). `main_screens_test.dart` reemplaza `progresoProvider` (sin red).

## Desafíos semanales (HU-22, HU-23)

- Todo lo decide y calcula el backend (catálogo, recompensas, elección del punto débil y avance; ver su CLAUDE.md); la app solo muestra. `GET /gamificacion/desafios?desde=...` (`GamificacionRepositorio.desafios`) → `DesafiosSemana` (`models/weekly_challenges.dart`: `inicio`, `fin`, `desafios`, `completados`, `tiempoRestante(ahora)`: "Quedan 3 días" / "Queda 1 día" / "Quedan 5 h" / "Queda menos de 1 h").
- `desde` = lunes 00:00 local (`PeriodoHistorial.semana`) **con la zona del teléfono** (`isoConZona`): el backend fija la semana con ella la primera vez y luego devuelve los mismos 3 hasta que termina.
- `Desafio`: `tipo` (`TipoDesafio`: constancia, calidad, punto débil, con su `etiqueta`), `tipoProgreso` (`TipoProgreso`, que ganó `promedio`), `meta`, `progreso`, `completado`, `puntos`, `categoria` (`CategoriaPuntaje`, solo punto débil) y, en el promedio, `promedio`/`viajes`/`viajesMinimos`. `avanceTexto`: "2 de 5 viajes", "0 de 1 viaje", "34 de 50 km", "Racha actual: 1 de 3", "Promedio 90 · 2 de 3 viajes" (faltan viajes) o "Promedio 76 · meta 80". `avance` (0–1; completado = 1; en el promedio, mientras faltan viajes, cuenta los viajes).
- `desafiosProvider` (`providers/challenges_provider.dart`, `conSesion`, sin reintentos); `ResumenPendienteNotifier` lo invalida al recibir el backend un viaje.
- Pantalla `presentation/challenges_screen.dart` (`DesafiosPantalla`, con `reloj` para las pruebas): resumen "1 de 3 completados" con barra y tiempo restante; una tarjeta por desafío con `CajaDesafio` (`widgets/challenge_widgets.dart`; recibe `codigo` y `categoria`, así sirve también para el resumen del viaje; ícono de `iconoDesafio`, el punto débil con el ícono y los colores de `EstiloEvento` de su categoría), la etiqueta del tipo, nombre, descripción, `CapsulaPuntos` ("+150 pts", `achievement_widgets.dart`, también en `TarjetaRecompensa`), `BarraProgreso`, `avanceTexto` y `CapsulaCompletado`. Error: `ErrorCarga`.
- Inicio: `_DesafiosSemana` bajo "Esta semana": "Desafíos de la semana" con "Ver todos", y una tarjeta tocable con "1 de 3 completados · Quedan 2 días" y una fila por desafío (caja de 36, nombre, `avanceTexto` y check si está completado). Cargando, con error o sin datos, no aparece.
- **Completar y recompensa (HU-23)**: los desafíos se completan solos en el backend al finalizar un viaje (no hay botón de reclamar); la app solo muestra. `RecompensaViaje` (HU-21) ganó `desafiosCompletados` (`DesafioCompletado`: `codigo`, `nombre`, `puntos`, `categoria`; `models/progress.dart`), `bono` (100 si este viaje dio el bono semanal, nulo si no), `puntosTotal` (viaje + desafíos + bono) y `hayNovedades` también con desafíos. Un backend anterior (sin las claves) los deja vacíos.
  - `TarjetaRecompensa`: la cápsula de arriba muestra `puntosTotal`; después, la subida de nivel (ya cuenta los puntos de desafíos y bono, calculada por el backend), una fila por desafío completado (`CajaDesafio`, "Desafío completado", el nombre y su `CapsulaPuntos`), la fila del "Bono semanal" ("¡Completaste los 3 desafíos!" y "+100 pts") y los logros nuevos (`_FilaRecompensa`).
  - Pantalla de desafíos: el completado deja de ofrecer los puntos (sin la cápsula de arriba) y muestra "+150 pts recibidos" en su línea de avance junto a "Completado". La tarjeta resumen agrega la línea del bono (`BonoSemana`, `DesafiosSemana.bono`): "Completa los 3 y gana +100 pts de bono" o, ya entregado, "Bono recibido · +100 pts".
  - `ResumenPendienteNotifier` ya invalida `desafiosProvider` y `progresoProvider` al recibir el viaje, así que Inicio, la pantalla de desafíos y Perfil se actualizan solos.
- Pruebas: `test/challenges_test.dart` (modelo, textos, tiempo restante, `desde` y pantalla con un `GamificacionRepositorio` falso) y `test/home_screen_test.dart` (tarjeta de Inicio; `desafiosProvider` reemplazado, nulo por defecto). `main_screens_test.dart` también lo reemplaza.

## Copiloto (HU-30, paso 1)

- **Elegir el tipo de recorrido**: "Iniciar recorrido" (Inicio y Viajes vacío) llama a `iniciarRecorrido` (`features/navegacion/presentation/widgets/trip_type_sheet.dart`), que abre `HojaTipoRecorrido`. "Recorrido libre" → `iniciarViaje` como siempre; "Con destino" → `prepararUbicacion` y `push(Rutas.copiloto)`. "Volver al viaje" y "Continuar viaje" no cambian.
- **Proveedor**: el backend (`GET /navegacion/ruta` y `GET /navegacion/lugares`) consulta a OSRM y Nominatim (por defecto, sin clave) u OpenRouteService; **la app nunca habla con el proveedor ni tiene claves**. Ruta en auto que respeta el sentido de las calles; lugares solo de Bolivia, primero los de Santa Cruz. Ver la sección "Navegación (HU-30)" del CLAUDE.md del backend (caché, cuota, errores).
- Módulo `features/navegacion/`:
  - `models/route_plan.dart` (Dart puro): `Coordenada`, `Destino` (`nombre`, `posicion`, `direccion`; `Destino.enMapa` con el nombre fijo "Punto en el mapa", porque el backend no tiene búsqueda inversa; `toApiJson` recorta el nombre a 150), `Lugar`, `RutaPlaneada` (`distanciaM`, `duracionS`, `trazado`, `pasos`), `PasoRuta` (`instruccion` en español, armada por el backend, `tipo`, `distanciaM`, `calle`, `salidaRotonda`), `TipoPaso` (un código desconocido = seguir recto) y `ErrorNavegacion` con `MotivoErrorNavegacion`.
  - `data/navigation_repository.dart` (`NavegacionRepositorio`): traduce los errores con `traducirError`. Usa el `codigo` del cuerpo, que `ErrorApi` ahora lee en `clave`: `sin_ruta` → sin ruta, `sin_cuota` → sin cuota, `navegacion_desactivada` y `proveedor_caido` → no disponible. Sin respuesta o 5xx sin código → sin conexión. Los demás (401, 422) siguen como `ErrorApi`.
  - `providers/navigation_provider.dart`: `rutaPlaneadaProvider` (familia por `(origen, destino)`) y `lugaresProvider` (por texto), `autoDispose`, `conSesion` y sin reintentos. "Reintentar" = `ref.invalidate` del mismo par.
  - `presentation/copilot_screen.dart` (`CopilotoPantalla`):
    - Al abrir pide la ubicación (`servicioUbicacionProvider.posicionActual()`); si falla, ofrece "Reintentar" o "Hacer un recorrido libre".
    - El destino lo elige tocar o mantener pulsado el mapa, o la búsqueda. La ruta se pide sola al fijarlo.
    - "Iniciar con destino" llama a `ViajeNotifier.iniciar(destino:)` y reemplaza la pantalla por la del viaje en vivo.
    - Error de la ruta: aviso con "Reintentar" (no sin ruta) y "Recorrido libre" (inicia sin destino).
  - El estado (ubicación, destino) vive en la pantalla: no hace falta fuera de ella en este paso.
  - Hojas en `presentation/widgets/`:
    - `place_search_sheet.dart` (`buscarDestino`): mínimo 3 letras y solo al enviar, sin autocompletar.
    - `route_steps_sheet.dart` (`mostrarPasosRuta`).
  - Textos e íconos en `presentation/route_format.dart` (`FormatoRuta`: "850 m" / "3,12 km", "7 min", como mínimo "1 min").
- **Mapa**: `MapaDestino` vive en `recorridos/presentation/widgets/trip_map.dart`, que sigue siendo el único archivo que importa flutter_map:
  - Ubicación, destino y ruta planeada; `alElegirDestino` al tocar o mantener pulsado.
  - `ControladorMapaDestino.encuadrar()`; encuadra solo al llegar la ruta.
  - Comparte con `MapaViaje` el mixin `_MosaicosConAviso` (mosaicos de OSM y aviso "Sin conexión").
- **Recorrido con destino**:
  - `RecorridosRepositorio.iniciar(destino:)` manda `destino` en el `POST /recorridos`; sin destino no va la clave.
  - El viaje en curso, los eventos, el DriveScore, el resumen y el historial no cambian: el teléfono no guarda el destino.
  - El detalle lo lee de `destino` (`RecorridoHistorial.destino`) y muestra `LineaDestino` ("Destino: …") en la tarjeta de horas, con y sin mapa.
  - Seguir la ruta durante el viaje: ver "Copiloto por voz y Modo aprendizaje (HU-31)".
- Pruebas:
  - `test/copilot_test.dart`: modelo, formatos, repositorio y errores, hoja de elección, pantalla con un repositorio y una ubicación falsos (buscar, ruta y pasos, búsqueda corta y sin resultados, quitar, iniciar con destino, sin ruta → recorrido libre, sin conexión → reintentar) y tocar el mapa.
  - `test/trip_history_test.dart`: destino en el detalle.
  - `test/trips_repository_test.dart`: `destino` en el `POST`.

## Copiloto por voz y Modo aprendizaje (HU-31)

Reglas acordadas (valores urbanos; se ajustan después de probar en la calle, en `UmbralesCopiloto`, `features/navegacion/models/route_progress.dart`). No cambian el DriveScore ni los avisos visuales de HU-14.

- **Voz**: `TextToSpeech` de Android en `MainActivity.kt` (métodos `hablar` `{texto, prioridad}` y `callarVoz` del canal `drivesense/sistema`; `VozCopiloto` en `telemetria/data/voice_service.dart`). Sin dependencias nuevas (`flutter_tts` traería otra dependencia de Android atada a AGP).
  - Idioma `es-BO`, si no `es-US`, si no `es`; sin voz en español no habla (log "No hay voz en español instalada").
  - Uso "guía de navegación" con foco de audio transitorio con atenuación: la música baja mientras habla.
  - Funciona con la pantalla apagada (como `avisarEvento`).
  - **Prioridad**: las indicaciones de ruta cortan lo que se esté diciendo (`QUEUE_FLUSH`); los consejos esperan su turno (`QUEUE_ADD`).
- **Seguimiento** (`SeguidorRuta`, Dart puro): proyecta cada lectura aceptada del GPS sobre el trazado. Busca cerca del último segmento (2 atrás, 40 adelante) y, si queda a más de 30 m, en toda la ruta.
  - Da la distancia a la ruta, lo recorrido y lo que falta. El tiempo restante es la duración de la ruta en proporción a lo que falta.
  - Da también el paso en curso y la próxima maniobra con los metros hasta ella. La maniobra de cada paso está en su `inicio`: `PasoRuta` ganó `inicio` y `fin`.
- **Avisos de maniobra** (`GuiaVoz`, `features/navegacion/models/voice_guide.dart`):
  - Se avisa a **300 m** (solo si el tramo desde la maniobra anterior mide más de **400 m**), a **100 m** y "ahora" a **30 m**. Cada umbral se dice una vez por maniobra, y uno más cercano deja sin efecto los lejanos.
  - Se dice la distancia real redondeada: a la decena bajo 100 m y a la cincuentena desde ahí ("En 90 metros").
  - La salida no se anuncia.
  - **Llegada** a **30 m** del destino: "Llegaste a tu destino.". No finaliza el viaje: lo hace el conductor (o la finalización automática por detenido).
  - Frases propias en tuteo (`GuiaVoz.maniobra`), no la `instruccion` del backend (con ORS viene en "usted" y es larga); la lista de pasos de la HU-30 sí la usa. Con OSRM, el backend arma la `instruccion` con estas mismas frases. Ejemplos:
    - "En 100 metros, gira a la derecha en Avenida Busch."
    - "Ahora, gira cerrado a la izquierda."
    - "En 300 metros, en la rotonda, toma la segunda salida." (ordinales en palabras hasta la décima).
  - En pantalla, `GuiaVoz.titulo` ("Gira a la derecha").
- **Desvío** (`DetectorDesvio`):
  - Cuenta como desvío estar a más de **50 m** de la ruta durante **5 s**, contando solo lecturas de precisión **≤ 20 m** (las imprecisas no cuentan ni reinician).
  - Se dice "Te saliste de la ruta. Recalculando." (una vez por desvío) y se pide la ruta desde la posición actual, como mucho **cada 20 s**. Con la ruta nueva: "Ruta actualizada.".
  - **Sin conexión**: sigue con la última ruta y dice "Sin conexión: sigo con la última ruta, no puedo recalcular." **una sola vez** hasta que se vuelva a calcular una ruta. La cápsula del bloque pasa a "Sin conexión".
  - Mientras está desviado no da indicaciones.
- **Modo aprendizaje** (`ConsejeroAprendizaje`, `telemetria/models/learning_coach.dart`):
  - **Funciona en todo recorrido**, libre o con destino.
  - El consejo se dice **cuando la maniobra termina**:
    - Frenada, aceleración y giro: **3 s** después del evento, si no hubo otro del mismo tipo (otro reinicia la espera).
    - Exceso: al cerrarse el tramo (`enCurso: false`).
    - Si terminan varios a la vez, va el de mayor riesgo (orden de la HU-18).
  - **Giro con velocidad alta** (solo con destino): a **40 km/h** o más y a **150 m** o menos de un giro (normal o cerrado, media vuelta o rotonda; no los leves ni seguir derecho), una vez por maniobra.
  - Como mucho **un consejo cada 15 s**. Un consejo que toca antes de ese tiempo, o a menos de **4 s** de una indicación de ruta, **se descarta** (no se encola).
  - **Frases fijas** (`FrasesAprendizaje`; generales, sin velocidades exactas ni distancias a otros vehículos):
    - Frenada: "Frenaste fuerte. Mira más lejos y suelta el acelerador antes para frenar con suavidad."
    - Aceleración: "Aceleraste fuerte. Pisa el acelerador de a poco al arrancar."
    - Giro: "Giro brusco. Reduce la velocidad antes de entrar a la curva."
    - Exceso: "Fuiste sobre el límite. Mantén una velocidad constante y segura."
    - Giro con velocidad: "Se acerca un giro: reduce la velocidad."
- **Preferencias**:
  - `modoAprendizajeProvider` (`SharedPreferencesAsync`, clave `modo_aprendizaje`, **apagado por defecto**), con su interruptor (`InterruptorAprendizaje`, `telemetria/presentation/widgets/learning_toggle.dart`):
    - en el Copiloto, antes de iniciar;
    - en la pantalla del viaje: el botón sobre el mapa con destino, `TarjetaAprendizaje` en el viaje libre;
    - en Perfil.
  - El **silencio** (`EstadoCopiloto.silenciado`) vale solo para el viaje actual, calla la guía y los consejos (`callarVoz`) y no afecta la vibración ni el sonido de HU-14.
- **Integración** (`CopilotoNotifier`, `features/navegacion/providers/copilot_provider.dart`; nulo fuera de un viaje):
  - `ViajeNotifier` llama a `comenzar` en `_comenzarSeguimiento`, `lectura` con cada lectura aceptada, `evento` en `alDetectar`, `segundo` con el reloj de 1 s y `terminar` en `_detenerSeguimiento`.
  - `ViajeNotifier.iniciar(destino:, ruta:)` recibe la ruta que ya calculó el Copiloto (no se pide dos veces).
  - **El viaje en curso guarda el destino** (`ViajeActivo.destino`, JSON `destino` con la dirección; un viaje guardado antes sigue siendo libre) y `/activo` lo trae (`Recorrido.destino`).
  - **Al continuar un viaje interrumpido**, la ruta se pide de nuevo con la primera lectura. Si no se puede, el bloque dice "Sin ruta por ahora", la voz dice "No pude calcular la ruta. El viaje se sigue registrando." una vez y lo vuelve a intentar cada 20 s.
- **Pantalla**: con destino, `live_trip_screen.dart` muestra `VistaViajeCopiloto` (`navegacion/presentation/copilot_trip_view.dart`, diseño en `docs/diseno.md`); sin destino, la de siempre más `TarjetaAprendizaje`. `CapsulaEnVivo` y `BotonVolverEnVivo` (antes privados) se comparten entre las dos.
- **Mapa**: `MapaDestino` ganó `seguir` (la cámara acompaña a la ubicación, zoom 17; al recalcular no reencuadra), `recorrido` (tramo hecho en `rutaHecha`), `alMoverManual` (al moverlo deja de seguir y aparece "Centrar") y `ControladorMapaDestino.centrar()`. `alElegirDestino` es opcional.
- Pruebas: `test/copilot_voice_test.dart`:
  - Seguimiento y desvío.
  - Guía: umbrales, tramo corto, rotonda y llegada.
  - Modo aprendizaje: después de la maniobra, el exceso al cerrarse, 15 s, prioridad de la ruta y el giro con velocidad.
  - `CopilotoNotifier` con voz y navegación falsas: guía completa, ruta al continuar, desvío, sin conexión, silencio y aprendizaje en el viaje libre.
  - El destino del viaje en curso, la pantalla y el interruptor.
- **Pendiente: probar en el A34**:
  - La voz con la pantalla apagada y la música atenuada.
  - Los avisos a 300, 100 y 30 m, la llegada y desviarse a propósito.
  - El modo avión y el aprendizaje en un viaje libre.

## Asistente de ayuda (sin HU)

Chat que responde cómo usar la app; lo responde el backend (Claude con una guía fija o, sin IA, preguntas frecuentes; ver la sección "Asistente de ayuda" de su CLAUDE.md). **No ve los viajes ni los puntajes del conductor.**
- Módulo `features/asistente/`: `MensajeAsistente` (`models/assistant_message.dart`: `rol` usuario / asistente, `texto`, `generadaPorIa`), `AsistenteRepositorio` (`data/assistant_repository.dart`: `GET /asistente/sugerencias` y `POST /asistente/mensajes` con los últimos 20 mensajes, `maximoMensajesEnviados`).
- `asistenteProvider` (`providers/assistant_provider.dart`, `AsistenteNotifier`): la conversación vive en memoria durante la sesión (al salir de la pantalla y volver sigue; se borra al cambiar de usuario o cerrar sesión). `preguntar` agrega la pregunta y pide la respuesta (`conSesion`); con error, la pregunta queda y `reintentar` vuelve a pedirla; `nueva` la borra. `sugerenciasAsistenteProvider`: `[]` si fallan (la pantalla funciona sin ellas).
- Pantalla `presentation/assistant_screen.dart` (`AsistentePantalla`, ruta `/asistente` en la raíz, `push`): saludo, chips de sugerencias (solo sin conversación; tocarlos pregunta), burbujas (la cápsula "Con IA" en las que redactó la IA), "Escribiendo…", `AvisoError` con "Reintentar", "Nueva conversación" en la cabecera y el campo (hasta 500 caracteres, `TextInputAction.send`) con el botón Enviar. Barra de estado oscura (`AnnotatedRegion`: desde Inicio llegaría clara). Diseño en `docs/diseno.md` 7.1 ("Asistente de ayuda" y "Ayuda").
- Entradas: botón "?" del encabezado de Inicio (`_BotonAyuda`) y tarjeta "Ayuda" en Perfil (`_Ayuda`).
- Pruebas: `test/assistant_test.dart` (modelo, recorte a 20 mensajes y pantalla con un repositorio falso: sugerencias, enviar, sin cápsula en la respuesta fija, error y reintentar, nueva conversación). En las pruebas, después de `enterText` hace falta un `pump` para que se active el botón Enviar.

## Historial (HU-06)

- `providers/trip_history_provider.dart`: `historialProvider` (familia por `PeriodoHistorial`: semana desde el lunes, mes desde el día 1, todos) pide `GET /recorridos` con `desde` en UTC calculado con la zona del teléfono; `cargarMas()` pagina con `antes_de` y el mismo `desde`. Si el periodo viene vacío, una consulta de `Todos` con `limite=1` decide entre "Aún no tienes viajes" (sin filtros) y el aviso del periodo. `detalleRecorridoProvider` → `GET /recorridos/{id}`. Un 401 cierra la sesión (`pedirConSesion`).
- Se recarga solo: `ResumenPendienteNotifier` invalida `historialProvider` cuando el backend recibe un resumen (200/409). Riverpod pausa los listeners de las pestañas ocultas, así que la petición sale al mostrar Viajes.
- "Podrás revisar este viaje en tu historial" del resumen abre el detalle (solo si quedó finalizado). "Iniciar recorrido" del estado vacío usa `iniciarViaje` (`widgets/location_permission_flow.dart`), igual que Inicio.
- Formato (`trip_format.dart`): km con 2 decimales bajo 10 km y 1 desde ahí (en toda la app); duración `18 min` / `1 h 05 min`; días "Hoy", "Ayer" o "domingo 27 de septiembre" (nombres propios en español, sin `intl`).

## Ejecutar en el teléfono

```
# 1. Backend (desde drivesense-backend)
.venv\Scripts\activate
uvicorn app.main:app --reload
# 2. Redirigir el puerto 8000 del teléfono al PC (se pierde al desconectar el USB)
adb reverse tcp:8000 tcp:8000
# 3. App (desde drivesense-mobile)
flutter run
```
Para usar otro backend: `flutter run --dart-define=API_URL=http://<ip>:8000`.

### Probar fuera de casa (caminata, auto)

Con `adb reverse` el teléfono solo llega al backend por el cable. Para probar sin cable, con datos móviles, se expone el backend con un túnel de Cloudflare (sin cuenta):

```
# 1. Backend (desde drivesense-backend), igual que siempre
uvicorn app.main:app
# 2. Túnel (instalado con: winget install Cloudflare.cloudflared)
"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --url http://localhost:8000
#    → imprime una URL https://<algo>.trycloudflare.com (tarda ~1 min en responder)
# 3. App apuntando al túnel (HTTPS: no necesita usesCleartextTraffic)
flutter build apk --debug --dart-define=API_URL=https://<algo>.trycloudflare.com
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```
- El PC debe quedar encendido con el backend y el túnel mientras dure la prueba.
- La URL cambia cada vez que se levanta el túnel: hay que recompilar la app con la nueva.
- En el auto, el teléfono lo maneja un acompañante, no el conductor.

### Ícono, nombre y arranque

- Nombre visible "DriveSense" (`android:label`). Ícono adaptativo en `res/mipmap-anydpi-v26/ic_launcher.xml`: fondo `@color/ic_launcher_fondo` (#12171F) y el velocímetro del logo en `res/drawable/ic_launcher_frente.xml` (coordenadas del favicon del panel ×2,6, dentro del círculo seguro de 66 dp; también es la capa `monochrome`). Los `mipmap-*dpi/ic_launcher.png` (Android 7) son el mismo diseño en PNG; si cambia el logo, regenerarlos.
- Arranque sin destello blanco: fondo `@color/arranque_fondo` (#1E252D, el de la pantalla de carga) en `launch_background.xml` y en `NormalTheme`; en Android 12+ (`values-v31`, `values-night-v31`) el sistema muestra solo el velocímetro (`windowSplashScreenAnimatedIcon`) sobre ese fondo, porque Samsung pone el ícono completo sobre un recuadro blanco.

### APK para los testers (backend en AWS)

```
flutter build apk --release --dart-define=API_URL=https://<dominio>
#   → build\app\outputs\flutter-apk\app-release.apk
```
- `<dominio>` es el `DOMINIO` del `deploy/.env` del backend (con sslip.io, la IP elástica con guiones: `3-85-120-14.sslip.io`). Ver `docs/despliegue.md` del backend.
- Antes de cada APK que se reparta, subir `version` en `pubspec.yaml` (el número tras `+` siempre crece; si no, Android no deja actualizar encima). Se ve en el modo pruebas del panel.
- Firma: el release usa la firma debug (`android/app/build.gradle.kts`). Sirve para repartir el APK a mano; todos los APK deben compilarse en la misma PC (otra firma obliga a desinstalar la app antes de instalar la nueva).
- El APK se reparte directo (Drive, WhatsApp); el tester debe permitir "instalar apps desconocidas".
- Solo HTTPS: el manifest principal no permite HTTP (únicamente el de debug).

## Estructura

```
lib/
├── main.dart
├── app/        → tema (ThemeData), rutas
├── core/       → api/ (cliente HTTP), storage/ (token), design/ (tokens), widgets/ comunes
└── features/<modulo>/
    ├── data/          → llamadas a la API (repositorio)
    ├── models/        → clases de datos
    ├── providers/     → estado Riverpod
    └── presentation/  → pantallas y widgets
```

- **Nombres:** archivos y carpetas en inglés y snake_case, según su función (`login_screen.dart`, `auth_repository.dart`, `session_provider.dart`, `core/storage/`). Clases, variables y funciones en español (`LoginPantalla`, `AlmacenToken`, `iniciarSesion`). Las carpetas de módulo, en español.
- Módulos en español sin tildes, iguales a los del backend cuando existan allí: `auth`, `recorridos`, `telemetria`, `puntaje`, `recomendaciones`, `gamificacion`, `navegacion`, `perfil`, `asistente`.
- **Crear cada módulo solo cuando se implemente su primera historia.**
- Estado con Riverpod.
- Tema y tokens: `lib/core/design/` (`ColoresDriveSense`, `TipografiaDriveSense`, `Espacios`, `Radios`, `Medidas`; acceso con `context.colores` / `context.tipografia`); `ThemeData` en `lib/app/theme.dart`. Token nuevo → primero en `docs/diseno.md`, luego en el código.
- Widgets comunes en `lib/core/widgets/` (`CampoFormulario`, `BotonPrimario` con ícono opcional, `BotonAcento` para fondos oscuros, `AvisoError`, `LogoDriveSense` (con variante `compacto`), `Avatar`, `Etiqueta`): reutilizarlos en las pantallas nuevas.
- Ilustraciones (`core/widgets/illustration_painters.dart`): `IlustracionRutaPainter` (diana + ruta punteada; `centro`, `escala`, `conPunto`, `huecoCentral`), `CirculosReducidosPainter` (solo la diana; `escala`) e `IlustracionHistorialVacioPainter` (diana con la ruta en degradado, historial vacío). Las usan login, registro, el encabezado de Inicio, el bloque en vivo y el historial.
- Pantallas principales (docs/diseno.md, 7.1): bloque o tarjeta oscura (`encabezado*`) con la diana y contenido claro debajo, como en login y registro.
- Fuentes: TTF **estáticos por peso** en `assets/fonts/` (Plus Jakarta Sans 400–800, Space Grotesk 500 y 700), generados con `fontTools varLib.instancer` desde las variables oficiales de Google Fonts (Flutter no aplica bien `FontWeight` a fuentes variables). Si hace falta otro peso, generarlo igual.

## API (drivesense-backend)

- Base `/api/v1`. JWT en el header `Authorization: Bearer <token>`. El token dura 7 días, no hay refresh ni logout en el backend: cerrar sesión = borrar el token guardado.
- Formato de errores:
  - 422: `{"detail": "Datos inválidos", "errores": [{"campo": "...", "mensaje": "..."}]}`. `campo` sirve para marcar el campo del formulario; puede ser `null`.
  - 401, 403, 409: `{"detail": "mensaje en español"}`. Mostrar `detail` tal cual.
- Cliente: `clienteApiProvider` (`lib/core/api/api_client.dart`) añade el token solo. Los repositorios convierten `DioException` → `ErrorApi` (`lib/core/api/api_error.dart`) y las pantallas muestran `ErrorApi.mensaje`. El único mensaje propio es el de "sin conexión" y el de respuestas sin `detail` (p. ej. un 500).
- El correo se normaliza (`trim().toLowerCase()`) en el repositorio antes de enviarlo.
- Endpoints de auth que usa la app:
  - `POST /auth/registro`
  - `POST /auth/login`: solo conductores; un admin recibe 403.
  - `GET /auth/yo`: al abrir la app, para validar la sesión.
  - La respuesta de sesión trae `debe_cambiar_contrasenia`: si es `true`, llevar a cambiar la contraseña temporal.
  - Un 401 en cualquier endpoint protegido significa sesión inválida o expirada: borrar el token y volver al login.
- La confirmación de contraseña del registro se valida solo en la app; el backend no la recibe.

### Red en Android
- HTTP sin TLS está permitido **solo** en `android/app/src/debug/AndroidManifest.xml` (`usesCleartextTraffic`); nunca en el manifest principal.
- El permiso `INTERNET` está en el manifest principal (sin él, la versión release no tiene red).
- La URL base viene de `--dart-define=API_URL` (por defecto `http://127.0.0.1:8000`, pensado para `adb reverse`).

## Reglas de diseño

- **Nunca** colores, tamaños de fuente, radios ni sombras escritos directamente en las pantallas: todo sale de los tokens del tema (`ThemeData` + `ThemeExtension`), definidos en `docs/diseno.md`.
- Por ahora solo modo claro, pero con los tokens preparados para un modo oscuro sin tocar pantallas: nombres semánticos y todo lo que dependa del modo dentro de la `ThemeExtension`.
- Fuentes: Plus Jakarta Sans (interfaz) y Space Grotesk (números de telemetría y puntajes), en ambos modos.
- Textos de la interfaz en español.

## Reglas de trabajo

- Avanzar paso a paso: implementar solo lo que se pida, sin adelantar funcionalidades.

## Pendientes

- Filtro de ruido del GPS: con el teléfono quieto en interiores suma distancia (≈60 m en 19 min) y marca velocidades de hasta ~7 km/h. En auto dio valores coherentes (3,3 km, máx. 41 km/h, prom. 18 km/h). Opciones: usar `speedAccuracy` o una velocidad mínima para sumar distancia; ajustar `UmbralesRecorrido`.
- Registro con la app cerrada desde recientes: en el A34 (Samsung) el servicio en primer plano mantuvo vivo el proceso y siguió registrando, pero no está garantizado en otras marcas. Registro garantizado requeriría `flutter_foreground_task` (isolate propio).
