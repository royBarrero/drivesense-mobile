/// Destino del Copiloto y ruta planeada hacia él (HU-30). Dart puro.
library;

/// Punto en el mapa (latitud y longitud), sin hora ni velocidad.
class Coordenada {
  const Coordenada(this.latitud, this.longitud);

  factory Coordenada.fromJson(Map<String, dynamic> json) => Coordenada(
    (json['lat'] as num).toDouble(),
    (json['lon'] as num).toDouble(),
  );

  final double latitud;
  final double longitud;

  @override
  bool operator ==(Object other) =>
      other is Coordenada &&
      other.latitud == latitud &&
      other.longitud == longitud;

  @override
  int get hashCode => Object.hash(latitud, longitud);
}

/// Destino elegido: un lugar buscado o un punto tocado en el mapa.
class Destino {
  const Destino({required this.nombre, required this.posicion, this.direccion});

  /// Punto tocado en el mapa: el backend no tiene búsqueda inversa, así que
  /// lleva un nombre fijo.
  factory Destino.enMapa(Coordenada posicion) =>
      Destino(nombre: nombrePuntoEnMapa, posicion: posicion);

  factory Destino.deLugar(Lugar lugar) => Destino(
    nombre: lugar.nombre,
    posicion: lugar.posicion,
    direccion: lugar.direccion,
  );

  /// `destino` del detalle del recorrido; nulo sin la clave o con `null`.
  static Destino? fromJson(Object? json) => switch (json) {
    final Map<String, dynamic> destino => Destino(
      nombre: destino['nombre'] as String,
      posicion: Coordenada.fromJson(destino),
      // Solo en el viaje guardado en el teléfono (HU-31)
      direccion: destino['direccion'] as String?,
    ),
    _ => null,
  };

  static const nombrePuntoEnMapa = 'Punto en el mapa';

  /// Como máximo 150 caracteres (límite del backend).
  final String nombre;
  final Coordenada posicion;

  /// Barrio, ciudad y departamento del lugar buscado; nula en un punto del
  /// mapa.
  final String? direccion;

  bool get esPuntoEnMapa => direccion == null;

  /// Viaje en curso guardado en el teléfono (HU-31): con la dirección.
  Map<String, dynamic> toJson() => {...toApiJson(), 'direccion': ?direccion};

  /// `destino` del `POST /recorridos`.
  Map<String, dynamic> toApiJson() => {
    'nombre': nombre.length > 150 ? nombre.substring(0, 150) : nombre,
    'lat': posicion.latitud,
    'lon': posicion.longitud,
  };
}

/// Resultado de la búsqueda por nombre (`GET /navegacion/lugares`).
class Lugar {
  const Lugar({
    required this.nombre,
    required this.direccion,
    required this.posicion,
  });

  factory Lugar.fromJson(Map<String, dynamic> json) => Lugar(
    nombre: json['nombre'] as String,
    direccion: json['direccion'] as String,
    posicion: Coordenada.fromJson(json),
  );

  final String nombre;
  final String direccion;
  final Coordenada posicion;
}

/// Maniobra de un paso (`tipo` del backend).
enum TipoPaso {
  girarIzquierda('girar_izquierda'),
  girarDerecha('girar_derecha'),
  girarFuerteIzquierda('girar_fuerte_izquierda'),
  girarFuerteDerecha('girar_fuerte_derecha'),
  girarLeveIzquierda('girar_leve_izquierda'),
  girarLeveDerecha('girar_leve_derecha'),
  seguirRecto('seguir_recto'),
  entrarRotonda('entrar_rotonda'),
  salirRotonda('salir_rotonda'),
  mediaVuelta('media_vuelta'),
  llegada('llegada'),
  salida('salida'),
  mantenerIzquierda('mantener_izquierda'),
  mantenerDerecha('mantener_derecha');

  const TipoPaso(this.codigo);

  final String codigo;

  /// Un tipo nuevo del backend se toma como seguir recto.
  static TipoPaso desdeCodigo(String codigo) => values.firstWhere(
    (tipo) => tipo.codigo == codigo,
    orElse: () => seguirRecto,
  );
}

/// Una indicación de la ruta, con su texto en español.
class PasoRuta {
  const PasoRuta({
    required this.instruccion,
    required this.tipo,
    required this.distanciaM,
    required this.duracionS,
    this.calle,
    this.salidaRotonda,
    this.inicio = 0,
    this.fin = 0,
  });

  factory PasoRuta.fromJson(Map<String, dynamic> json) => PasoRuta(
    instruccion: json['instruccion'] as String,
    tipo: TipoPaso.desdeCodigo(json['tipo'] as String),
    distanciaM: (json['distancia_m'] as num).toDouble(),
    duracionS: (json['duracion_s'] as num).toDouble(),
    calle: json['calle'] as String?,
    salidaRotonda: json['salida_rotonda'] as int?,
    inicio: json['inicio'] as int? ?? 0,
    fin: json['fin'] as int? ?? 0,
  );

  final String instruccion;
  final TipoPaso tipo;
  final double distanciaM;
  final double duracionS;
  final String? calle;
  final int? salidaRotonda;

  /// Tramo del paso: índices en `RutaPlaneada.trazado`. La maniobra se hace en
  /// [inicio] (HU-31).
  final int inicio;
  final int fin;
}

/// Ruta en auto hasta el destino (`GET /navegacion/ruta`).
class RutaPlaneada {
  const RutaPlaneada({
    required this.distanciaM,
    required this.duracionS,
    required this.trazado,
    required this.pasos,
  });

  factory RutaPlaneada.fromJson(Map<String, dynamic> json) => RutaPlaneada(
    distanciaM: (json['distancia_m'] as num).toDouble(),
    duracionS: (json['duracion_s'] as num).toDouble(),
    trazado: [
      for (final punto in json['trazado'] as List<dynamic>)
        Coordenada.fromJson(punto as Map<String, dynamic>),
    ],
    pasos: [
      for (final paso in json['pasos'] as List<dynamic>)
        PasoRuta.fromJson(paso as Map<String, dynamic>),
    ],
  );

  final double distanciaM;
  final double duracionS;
  final List<Coordenada> trazado;
  final List<PasoRuta> pasos;
}

/// Por qué no se pudo buscar o calcular la ruta.
enum MotivoErrorNavegacion {
  /// Sin internet o el servidor no responde.
  sinConexion,

  /// No hay ruta en auto hasta ese destino (o está demasiado lejos).
  sinRuta,

  /// Se acabó la cuota de consultas del proveedor.
  sinCuota,

  /// Navegación desactivada en el servidor o proveedor caído.
  noDisponible,
}

class ErrorNavegacion implements Exception {
  const ErrorNavegacion(this.motivo, this.mensaje);

  final MotivoErrorNavegacion motivo;

  /// El `detail` del backend; con [MotivoErrorNavegacion.sinConexion], el
  /// mensaje de la app.
  final String mensaje;

  /// Título del aviso.
  String get titulo => switch (motivo) {
    MotivoErrorNavegacion.sinConexion => 'Sin conexión',
    MotivoErrorNavegacion.sinRuta => 'No encontramos una ruta',
    MotivoErrorNavegacion.sinCuota => 'Copiloto ocupado',
    MotivoErrorNavegacion.noDisponible => 'Copiloto no disponible',
  };

  @override
  String toString() => 'ErrorNavegacion($motivo): $mensaje';
}
