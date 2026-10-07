# Guía de diseño — DriveSense (Flutter)

Origen: diseños de Google Stitch (en términos de Tailwind), convertidos a valores de Flutter.

- Las medidas están en **dp** (píxeles lógicos de Flutter); 1 px de Tailwind = 1 dp.
- Los colores van en formato `Color(0xAARRGGBB)`.
- **Marcas usadas en esta guía:**
  - **(derivado)**: el valor no venía en Stitch; se calculó a partir de la paleta (p. ej. un color al 10 % sobre blanco).
  - **(propuesta)**: el valor no venía en Stitch y hay que confirmarlo al ver la pantalla en el dispositivo.
- Regla: **ninguna pantalla escribe colores, tamaños de fuente, radios ni sombras directamente**. Todo sale de estos tokens a través del tema (sección 9).

---

## 1. Colores

Los nombres son **semánticos** (qué función cumplen, no qué color son), para que el modo oscuro solo cambie valores.

### 1.1 Modo claro (activo)

| Token | Hex | Flutter | Uso |
|---|---|---|---|
| `fondo` | #EFEBE1 | `0xFFEFEBE1` | Fondo general de pantalla |
| `superficie` | #FFFFFF | `0xFFFFFFFF` | Tarjetas principales |
| `superficieAlt` | #F9F7F2 | `0xFFF9F7F2` | Tarjetas secundarias, campos |
| `borde` | #E2DCCF | `0xFFE2DCCF` | Borde de tarjetas (1 dp) |
| `bordeFuerte` | #DFD8C7 | `0xFFDFD8C7` | Bordes con más contraste, divisores |
| `textoPrincipal` | #1E252D | `0xFF1E252D` | Títulos y cuerpo |
| `textoSecundario` | #4B5661 | `0xFF4B5661` | Etiquetas, descripciones. Antes #5F6B76: se oscureció con el rediseño de Inicio para leerse mejor (contraste 7,5 sobre `superficie` y 6,3 sobre `fondo`; antes 5,5 y 4,6) |
| `textoTerciario` | #7B8893 | `0xFF7B8893` | Texto de apoyo, ítems inactivos |
| `sobrePrimario` | #FFFFFF | `0xFFFFFFFF` | Texto e íconos sobre `primario` |
| `primario` | #10B981 | `0xFF10B981` | Acento principal (esmeralda) |
| `primarioOscuro` | #059669 | `0xFF059669` | Botón presionado, texto verde sobre fondos claros |
| `secundario` | #0EA5E9 | `0xFF0EA5E9` | Acento cian |
| `confort` | #8B5CF6 | `0xFF8B5CF6` | Métricas de confort (violeta) |
| `peligro` | #EF4444 | `0xFFEF4444` | Frenadas bruscas, errores |
| `advertencia` | #F59E0B | `0xFFF59E0B` | Advertencias de curva |
| `botonPrimario` | #047857 | `0xFF047857` | Fondo del botón primario. El blanco sobre `primario` (#10B981) no tiene contraste suficiente a pleno sol |
| `botonPrimarioPresionado` | #065F46 | `0xFF065F46` | Botón primario presionado **(propuesta)** |
| `enlace` | #047857 | `0xFF047857` | Enlaces de texto ("Crear cuenta") |
| `fondoBotonSecundario` | #E8E2D4 | `0xFFE8E2D4` | Botón secundario y botón primario deshabilitado |
| `bordePeligroSuave` | #F8C9C9 | `0xFFF8C9C9` | Borde del aviso de error |
| `textoPeligro` | #B91C1C | `0xFFB91C1C` | Texto del aviso de error |
| `textoExito` | #047857 | `0xFF047857` | Requisito cumplido (lista de requisitos de contraseña). Mismo verde que `botonPrimario`: #10B981 no contrasta lo suficiente sobre blanco en texto pequeño |
| `carril` | #E8E2D4 | `0xFFE8E2D4` | Carril de barras de progreso y del anillo **(propuesta)** |
| `barraNavegacion` | #FFFFFF al 80 % | `0xCCFFFFFF` | Fondo translúcido de la barra de navegación inferior (sección 5) **(propuesta)** |

**Tintes tenues** (el color de acento al 10–15 % sobre blanco) **(derivado)**:

| Token | Hex | Flutter | Uso |
|---|---|---|---|
| `tintePrimario` | #E7F8F2 | `0xFFE7F8F2` | Micro-tarjeta "Suave" (verde menta) |
| `tinteConfort` | #F3EFFE | `0xFFF3EFFE` | Micro-tarjeta "Progresiva" (lavanda) |
| `tintePeligro` | #FDECEC | `0xFFFDECEC` | Micro-tarjeta de evento brusco |
| `tinteAdvertencia` | #FEF5E7 | `0xFFFEF5E7` | Micro-tarjeta de advertencia |
| `tinteNavActivo` | #DBF4EC | `0xFFDBF4EC` | Cápsula del ítem activo de la barra inferior |
| `tinteSecundario` | #E2F4FC | `0xFFE2F4FC` | Micro-tarjeta de velocidad promedio del detalle y caja de ícono de las filas del historial (cian) |

**Eventos de riesgo** (avisos de HU-14; colores fijos por tipo). El tono vivo va sobre el encabezado oscuro (aro, punto, cápsula, número), con texto `sobreAcentoOscuro` encima; el de texto, sobre los tintes y el blanco. Contraste (WCAG) calculado: vivo vs `encabezadoFondo` ≥ 5,6; `sobreAcentoOscuro` sobre vivo ≥ 6,5; texto vs tinte ≥ 4,7 y vs blanco ≥ 5,0. El blanco sobre los tonos vivos no alcanza (2,1-2,8): no usarlo.

| Tipo | Vivo (sobre oscuro) | Texto (sobre claro) | Tinte |
|---|---|---|---|
| Frenada | `eventoFrenada` #F87171 `0xFFF87171` | `textoEventoFrenada` #B91C1C `0xFFB91C1C` | `tinteEventoFrenada` #FDECEC `0xFFFDECEC` |
| Aceleración | `eventoAceleracion` #A78BFA `0xFFA78BFA` | `textoEventoAceleracion` #6D28D9 `0xFF6D28D9` | `tinteEventoAceleracion` #F3EFFE `0xFFF3EFFE` |
| Giro | `eventoGiro` #F59E0B `0xFFF59E0B` | `textoEventoGiro` #B45309 `0xFFB45309` | `tinteEventoGiro` #FEF5E7 `0xFFFEF5E7` |
| Velocidad | `eventoVelocidad` #38BDF8 `0xFF38BDF8` | `textoEventoVelocidad` #0369A1 `0xFF0369A1` | `tinteEventoVelocidad` #E2F4FC `0xFFE2F4FC` |

**Encabezado oscuro** (bloque superior del login y fondo del arranque; es oscuro también en modo claro):

| Token | Hex | Flutter | Uso |
|---|---|---|---|
| `encabezadoFondo` | #1E252D | `0xFF1E252D` | Fondo del bloque |
| `encabezadoSuperficie` | #12171F | `0xFF12171F` | Caja del logo |
| `encabezadoBorde` | #2A3440 | `0xFF2A3440` | Borde del logo, círculos de la ilustración |
| `encabezadoAcento` | #34D399 | `0xFF34D399` | Trazo del velocímetro, ruta y punto de la ilustración |
| `encabezadoTexto` | #F3F4F6 | `0xFFF3F4F6` | Títulos |
| `encabezadoTextoSecundario` | #9CA3AF | `0xFF9CA3AF` | Subtítulos |
| `acentoOscuroTenue` | #34D399 al 14 % | `0x2434D399` | Cápsula de estado sobre fondo oscuro ("● Registrando viaje") **(propuesta)** |
| `sobreAcentoOscuro` | #12171F | `0xFF12171F` | Texto e ícono del botón de acento (fondo `encabezadoAcento`) **(propuesta)** |

**Degradados:**

| Token | Colores | Uso |
|---|---|---|
| `gradienteScore` | #10B981 → #06B6D4 | Anillo de DriveScore. #06B6D4 es otro cian, distinto de `secundario` |
| `gradienteRellenoGrafica` | #10B981 al 15 % (`0x2610B981`) → al 0 % (`0x0010B981`), de arriba abajo | Relleno bajo la curva semanal |

**Sobre el degradado** (tarjeta de resumen del historial y cabecera del detalle, con fondo `gradienteScore`):

| Token | Hex | Flutter | Uso |
|---|---|---|---|
| `textoSobreGradiente` | #0B2A22 | `0xFF0B2A22` | Textos y números |
| `superficieSobreGradiente` | #FFFFFF al 30 % | `0x4DFFFFFF` | Caja del botón volver **(propuesta)** |
| `lineasSobreGradiente` | #FFFFFF al 35 % | `0x59FFFFFF` | Diana y ruta decorativas **(propuesta)** |

**Mapa del viaje** (HU-29):

| Token | Hex | Flutter | Uso |
|---|---|---|---|
| `bordeRuta` | #0B2A22 al 25 % | `0x400B2A22` | Borde tenue de la línea de la ruta **(propuesta)** |
| `fondoAtribucion` | #FFFFFF al 80 % | `0xCCFFFFFF` | Cápsula "© OpenStreetMap" **(propuesta)** |
| Halo del marcador elegido | tono vivo del tipo al 30 % | `vivo.withValues(alpha: 0.3)` | Derivado en `EstiloEvento.halo`, no es un token aparte |

### 1.2 Modo oscuro (FUTURO — solo documentado, no implementar aún)

| Token | Hex | Notas |
|---|---|---|
| `fondo` | #0A0E14 | |
| `superficie` | #12171F | |
| `superficieAlt` | #161C26 | |
| `borde` / `bordeFuerte` | #1F2937 | |
| `textoPrincipal` | #F3F4F6 | |
| `textoSecundario` / `textoTerciario` | #9CA3AF | |
| `primario` | #34D399 | |
| `secundario` | #38BDF8 | |
| `confort`, `peligro`, `advertencia` | #A78BFA, #F87171, #FBBF24 | **(propuesta)**: variantes claras de los mismos colores |
| Tintes, `carril`, `primarioOscuro`, `sobrePrimario` | — | Por definir cuando se diseñe el modo oscuro |

---

## 2. Tipografía

- **Plus Jakarta Sans**: toda la interfaz.
- **Space Grotesk**: números de telemetría y puntajes (velocímetro, DriveScore, métricas numéricas). Se usa en ambos modos.
- Empaquetar las fuentes como **assets** en `pubspec.yaml` **(propuesta)**, en lugar de descargarlas en tiempo de ejecución con `google_fonts`: la app debe verse bien aunque no haya conexión durante un viaje.
- Pesos que hay que incluir: Plus Jakarta Sans 400, 500, 600, 700 y 800 (ExtraBold, para el saludo y el botón de Inicio); Space Grotesk 500 y 700.

| Token | Fuente | Tamaño | Peso | Otros | Uso |
|---|---|---|---|---|---|
| `velocimetro` | Space Grotesk | 120 | 700 | `height: 1.0` | Velocidad de la pantalla en vivo **(propuesta)** |
| `telemetriaXL` | Space Grotesk | 64 | 700 (`w700`) | `height: 1.0` | Velocímetro principal |
| `numeroGrande` | Space Grotesk | 32 | 700 | `height: 1.1` | Valores de las micro-tarjetas en vivo **(propuesta)** |
| `telemetria` | Space Grotesk | 56 | 700 | `height: 1.0` | Otros valores grandes en vivo |
| `puntaje` | Space Grotesk | 28 | 700 | `height: 1.1` | DriveScore y puntajes en tarjetas |
| `puntajeAnillo` | Space Grotesk | 48 | 700 | `height: 1.0` | DriveScore dentro del anillo del resumen (HU-15) |
| `numeroMetrica` | Space Grotesk | 18 | 500 | — | Valores numéricos pequeños (km, min) **(propuesta)** |
| `numeroLista` | Space Grotesk | 22 | 700 | `height: 1.1` | Distancia de cada fila del historial **(propuesta)** |
| `tituloGrande` | Plus Jakarta Sans | 28 | 700 | `height: 1.2` | Título del resumen **(propuesta)** |
| `titulo` | Plus Jakarta Sans | 24 | 700 | `height: 1.2` | H1 de pantalla |
| `subtituloGrande` | Plus Jakarta Sans | 18 | 600 | `height: 1.3` | Encabezado de tarjeta grande |
| `subtitulo` | Plus Jakarta Sans | 16 | 600 | `height: 1.3` | Encabezado de tarjeta |
| `cuerpo` | Plus Jakarta Sans | 14 | 500 | `height: 1.5` | Texto general (500 desde el rediseño de Inicio: se lee mejor) |
| `cuerpoPequeno` | Plus Jakarta Sans | 13 | 500 | `height: 1.5` | Texto de apoyo |
| `boton` | Plus Jakarta Sans | 16 | 600 | — | Texto de botones **(propuesta de tamaño)** |
| `botonGrande` | Plus Jakarta Sans | 20 | 800 | — | Botón flotante "Iniciar recorrido" de Inicio |
| `saludo` | Plus Jakarta Sans | 17 | 500 | `height: 1.3` | "Buenas tardes," del encabezado de Inicio |
| `nombreSaludo` | Plus Jakarta Sans | 34 | 800 | `height: 1.1` | Nombre del conductor en el encabezado de Inicio |
| `tituloHero` | Plus Jakarta Sans | 32 | 700 | `height: 1.15` | Título del encabezado oscuro ("Cada viaje cuenta.") |
| `tituloTarjeta` | Plus Jakarta Sans | 22 | 700 | `height: 1.25` | Título de tarjeta de formulario ("Inicia sesión") |
| `marca` | Plus Jakarta Sans | 20 | 700 | — | "DriveSense" junto al logo |
| `etiquetaCampo` | Plus Jakarta Sans | 13 | 600 | — | Etiqueta encima de un campo de formulario (sin mayúsculas) |
| `ayuda` | Plus Jakarta Sans | 12 | 500 | `height: 1.4` | Textos de ayuda bajo botones y formularios |
| `etiqueta` | Plus Jakarta Sans | 11 | 500 | `letterSpacing: 0.55` | Labels de métricas, EN MAYÚSCULAS |
| `etiquetaGrande` | Plus Jakarta Sans | 12 | 500 | `letterSpacing: 0.6` | Labels de sección, EN MAYÚSCULAS |

- Flutter no tiene `text-transform`: las mayúsculas de `etiqueta` las pone un widget común (p. ej. `Etiqueta('Velocidad')` que aplica `.toUpperCase()`), no el texto escrito a mano.
- `letterSpacing` = 0.05 em (Tailwind `tracking-wider`): tamaño × 0.05.
- El color de la tipografía no va en el token: se aplica según el contexto (`textoPrincipal` por defecto, `textoSecundario` en etiquetas).

**Correspondencia con `TextTheme` de Material** (para que los widgets de Material hereden la fuente):

| `TextTheme` | Token |
|---|---|
| `headlineSmall` | `titulo` |
| `titleLarge` | `subtituloGrande` |
| `titleMedium` | `subtitulo` |
| `bodyMedium` | `cuerpo` |
| `bodySmall` | `cuerpoPequeno` |
| `labelLarge` | `boton` |
| `labelMedium` | `etiquetaGrande` |
| `labelSmall` | `etiqueta` |

Los estilos de Space Grotesk (`velocimetro`, `telemetriaXL`, `telemetria`, `numeroGrande`, `puntaje`, `puntajeAnillo`, `numeroMetrica`, `numeroLista`), `tituloGrande`, `botonGrande`, `saludo` y `nombreSaludo` no encajan en `TextTheme` y van en la `ThemeExtension` (sección 9).

---

## 3. Espaciado, radios y sombras

### 3.1 Espaciado (escala de 4 dp, como Tailwind)

| Token | dp |
|---|---|
| `xxs` | 4 |
| `xs` | 8 |
| `s` | 12 |
| `m` | 16 |
| `l` | 20 |
| `xl` | 24 |
| `xxl` | 32 |

- Márgenes laterales de pantalla: 20 **(propuesta)**.
- Relleno interno: tarjeta grande 20, micro-tarjeta 12 **(propuesta)**.
- Separación entre tarjetas: 16 **(propuesta)**.

### 3.2 Radios

| Token | Valor | Uso |
|---|---|---|
| `radioPildora` | `StadiumBorder()` (o `BorderRadius.circular(999)`) | Botones primarios, chips, cápsula de navegación, barras de progreso |
| `radioTarjeta` | 24 | Tarjetas grandes |
| `radioMicro` | 16 | Micro-tarjetas, botón secundario no píldora |
| `radioCajaIcono` | 12 | Caja de 36×36 del ícono **(propuesta)** |
| `radioCampo` | 16 | Campos de texto y aviso de error |
| `radioEncabezado` | 32 | Esquinas inferiores del encabezado oscuro |
| `radioTarjetaDestacada` | 28 | Tarjeta del formulario de login/registro |
| `radioLogo` | 14 | Caja del logo (44×44) |

### 3.3 Sombras

CSS y Flutter miden el desenfoque distinto: en CSS, `blur` = 2 × sigma; en Flutter, `blurRadius` ≈ (sigma − 0.5) / 0.577. Por eso **un blur de 20 px en CSS equivale a `blurRadius: 16` en Flutter**.

| Token | Definición Flutter | Uso |
|---|---|---|
| `sombraTarjeta` | `BoxShadow(color: Color(0x0F000000), offset: Offset(0, 4), blurRadius: 16)` (negro al 6 %) | Tarjetas, siempre junto con el borde de 1 dp |
| `sombraBotonPrimario` | `BoxShadow(color: Color(0x3310B981), offset: Offset(0, 6), blurRadius: 16)` (esmeralda al 20 %) | Botón primario **(desplazamiento en propuesta)** |
| `sombraBotonAcento` | `BoxShadow(color: Color(0x4034D399), offset: Offset(0, 6), blurRadius: 16)` (#34D399 al 25 %) | Botón de acento sobre fondo oscuro **(propuesta)** |
| `resplandorPunto` | `BoxShadow(color: Color(0x6610B981), blurRadius: 12, spreadRadius: 2)` (esmeralda al 40 %) | Punto de la diana de fuerzas G **(propuesta)** |

---

## 4. Botones

| Componente | Especificación |
|---|---|
| **Primario** ("Iniciar Detección", "Finalizar Viaje") | `StadiumBorder`, fondo `botonPrimario`, texto e ícono `sobrePrimario`, `padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14)` (54 de alto en formularios), ícono de 20 dp con separación de 8 dp, texto `boton` (600), sombra `sombraBotonPrimario`. Presionado: fondo `botonPrimarioPresionado`. Deshabilitado: fondo `fondoBotonSecundario`, texto `textoSecundario`, sin sombra. Cargando: indicador circular de 20 dp en `sobrePrimario` en lugar del texto |
| **Secundario** ("Pausar", "Calibrar") | `StadiumBorder` o radio `radioMicro` (16), mismo padding que el primario. Variante *relleno*: fondo `fondoBotonSecundario`, texto `textoPrincipal`. Variante *contorno*: fondo transparente, borde de 1 dp `borde`, texto `textoPrincipal`. Sin sombra |
| **Acento sobre oscuro** ("Iniciar recorrido" en la tarjeta oscura) | `StadiumBorder`, fondo `encabezadoAcento`, texto e ícono `sobreAcentoOscuro`, mismo padding y alto que el primario, sombra `sombraBotonAcento` **(propuesta)** |
| **Chip de filtro activo** | Cápsula, `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6)`, fondo `primario` o `textoPrincipal` (#1E252D), texto `sobrePrimario`, `cuerpoPequeno` con peso 600 **(propuesta)** |
| **Chip de filtro inactivo** | Mismo tamaño, fondo `superficie`, borde de 1 dp `borde`, texto `textoSecundario` |

Con Material 3, esto se configura una sola vez en `filledButtonTheme`, `outlinedButtonTheme` y `chipTheme` de `ThemeData`. Las pantallas usan `FilledButton` y `OutlinedButton` sin estilos propios.

## 4.1 Formularios

| Componente | Especificación |
|---|---|
| **Campo de texto** | Etiqueta arriba con `etiquetaCampo` en `textoPrincipal` y 8 dp de separación. Campo de 52 de alto, fondo `superficieAlt`, borde de 1 dp `borde`, radio `radioCampo`, texto `cuerpo`. Foco: borde de 1.5 dp `botonPrimario` **(propuesta)**. Error: borde `peligro` y, si la API indica el campo, su mensaje debajo con `ayuda` en `textoPeligro` |
| **Aviso de error** | Fondo `tintePeligro`, borde de 1 dp `bordePeligroSuave`, radio `radioCampo`, padding 12, ícono de alerta de 20 dp y mensaje con `cuerpoPequeno` en `textoPeligro` |

## 4.2 Pantallas de autenticación (login y registro)

| Elemento | Especificación |
|---|---|
| **Encabezado oscuro** | Fondo `encabezadoFondo`, radio inferior `radioEncabezado`, logo arriba a la izquierda, título `tituloHero` en `encabezadoTexto` y subtítulo `cuerpo` en `encabezadoTextoSecundario`, ambos con ancho máximo de 260 |
| Alto del encabezado | Login: 392 fijo. Registro: se ajusta al contenido, con **mínimo 240** (con título y subtítulo de 2 líneas, 240 fijos dejarían el subtítulo bajo la tarjeta) |
| **Tarjeta del formulario** | Se superpone **56** sobre el encabezado; márgenes laterales 16, radio `radioTarjetaDestacada`, borde `borde`, `sombraTarjeta`, padding 24 (vertical) × 20 (horizontal) |
| **Ilustración** | Login: ruta + círculos (ver `route_illustration_painter.dart`). Registro: solo círculos reducidos (radios 14/26/38, el del medio punteado, con ejes) en la esquina superior derecha, en `encabezadoBorde` |
| **Botón volver** | Flecha de 24 dp en `encabezadoTexto`, área táctil de 44×44, a la izquierda del logo |
| **Lista de requisitos** (contraseña) | Una fila por requisito: ícono de 16 dp + texto `ayuda`. Pendiente: círculo vacío en `textoTerciario`. Cumplido: check en `textoExito`. Pendiente después de salir del campo: `textoPeligro` |

## 5. Barra de navegación inferior

- Fondo `barraNavegacion` (`superficie` al 80 %, `0xCCFFFFFF`) **(propuesta)**, con `BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))`. El `blur()` de CSS ya es la sigma, así que se traslada tal cual. Borde superior de 1 dp `borde`.
- El cuerpo de la pantalla necesita `extendBody: true` en el `Scaffold` para que el contenido pase por detrás de la barra y se vea el desenfoque.
- **Ítem activo:** cápsula `tinteNavActivo` detrás del ícono y la etiqueta; ícono y texto en `primarioOscuro`, peso 700.
- **Ítem inactivo:** sin cápsula; `textoTerciario`, peso 500.
- Tamaños: ícono 24, etiqueta 12 (`ayuda` con el peso del estado) **(propuesta)**.
- Cápsula del ítem: `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6)`, radio píldora; barra con padding vertical 8 más el margen inferior del sistema **(propuesta)**.

## 6. Tarjetas

| Tipo | Especificación |
|---|---|
| **Grande** | Radio 24, fondo `superficie`, borde de 1 dp `borde`, `sombraTarjeta`, padding 20 |
| **Micro-tarjeta de telemetría** | Radio 16, borde de 1 dp `borde`, `sombraTarjeta`, padding 12. Fondo tintado según estado (tabla abajo) |
| **Caja de ícono** | 36×36 (`Medidas.cajaIcono`), radio 12, fondo blanco al 70 % sobre el tinte **(propuesta)**, ícono de 20 dp en el color del estado |

| Estado | Fondo | Color de ícono / acento |
|---|---|---|
| Suave | `tintePrimario` | `primario` |
| Progresiva | `tinteConfort` | `confort` |
| Brusca | `tintePeligro` | `peligro` **(derivado)** |
| Advertencia | `tinteAdvertencia` | `advertencia` **(derivado)** |

## 7. Indicadores

### Anillo de DriveScore
- `CustomPainter`, trazo de 12 dp (10 en tamaños pequeños) y `StrokeCap.round`.
- Encabezado de Inicio (diseño B): anillo oscuro de 132 (`Medidas.anilloEncabezadoInicio`) con trazo de 12, número en `puntajeAnillo` y "DriveScore" debajo; "—" sin puntaje.
- Detalle del viaje (HU-16): 76×76 (`Medidas.anilloDetalle`) con trazo de 10, sobre blanco: carril `carril` y número en `puntaje` `textoPrincipal`, sin la palabra "DriveScore" dentro.
- Sin datos todavía: solo el carril con "—" en el centro (`puntaje`, `textoTerciario`) y un texto explicativo al lado.
- Carril completo en `carril`; arco de progreso con `SweepGradient` de `gradienteScore`, empezando arriba (−90°).
- Número central con `puntaje` (o `telemetria` si el anillo es el protagonista de la pantalla).

### Diana de fuerzas G
- `CustomPainter` con 3 círculos concéntricos de 1 dp en `borde` y ejes cruzados de 1 dp en `borde`.
- Rótulos con `etiqueta` en `textoTerciario`: FRENADO (arriba), ACELERACIÓN (abajo), IZQ (izquierda), DER (derecha).
- Escala: el círculo exterior equivale a 1 g, y los anillos a 0,33 / 0,66 / 1 g **(propuesta)**.
- Punto de 12 dp en `primario` con `resplandorPunto`. Se mueve en tiempo real: animar la posición con un `AnimatedPositioned` o redibujando el painter, para que no salte entre lecturas del sensor.

### Gráfica semanal
- Curva suavizada, trazo de 4 dp en `primario` con extremos redondeados.
- Relleno inferior con `gradienteRellenoGrafica`.
- Si se usa `fl_chart`: `isCurved: true`, `barWidth: 4`, `isStrokeCapRound: true`, `belowBarData` con el degradado.

### Gráfico del DriveScore (HU-17)
- `CustomPainter` (`PintorLineaPuntaje`, sin librería de gráficos). Línea recta entre puntos, trazo de 3 con `gradienteScore` (horizontal), extremos y uniones redondeados; relleno debajo con `gradienteRellenoGrafica`.
- Escala vertical de `min(55, menor − 5)` a 100.
- "Mi DriveScore": alto 200 (`Medidas.altoGrafico`); cada punto según su fecha dentro del periodo; guías punteadas de 1 dp en `borde` (guion 4, espacio 4) en 90, 75 y 60 con el número a la derecha en `ayuda` `textoTerciario`; puntos de 8 (`Medidas.puntoGrafico`) blancos con borde de 2 en `primario` y el último de 12 (`Medidas.puntoGraficoUltimo`) relleno con el color final del degradado; debajo, fechas del inicio, la mitad y "Hoy" en `ayuda` `textoSecundario`.
- Con un solo punto: solo el punto (sin línea ni relleno).
- La línea de la tarjeta de Inicio de HU-17 se quitó con el rediseño B (Inicio ya no tiene gráfico).

### Barras de progreso
- Alto de 8 dp (`Medidas.altoBarra`; 6 en listas compactas), radio píldora, carril `carril`.
- Excepción: las barras del desglose del DriveScore (HU-16) van en el color de texto del tipo de evento (`textoEvento*`), no en esta escala.
- Color de la barra según el valor:

| Valor | Color |
|---|---|
| ≥ 90 % | `primario` |
| 70–89 % | `advertencia` |
| < 70 % | `peligro` |

Stitch dice "verde > 90 %"; se toma 90 % exacto como verde para no dejar el valor sin asignar.

---

## 7.1 Pantallas principales (propuesta)

| Elemento | Especificación |
|---|---|
| **Inicio (diseño B)** | Barra de estado con íconos claros (solo en Inicio). **Encabezado** `encabezadoFondo`, radio inferior `radioEncabezado`, diana y ruta (`IlustracionRutaPainter`, `encabezadoBorde` / `acentoOscuroTenue`, escala 1,5) centradas en el anillo y sin ruta detrás de él; padding 20 (inferior 20 + la mitad del botón). Arriba `LogoDriveSense` (variante oscura) y el avatar (`Avatar(sobreOscuro)`, fondo `encabezadoBorde`). A la izquierda el saludo ("Buenos días" < 12, "Buenas tardes" < 19, "Buenas noches") en `saludo` `encabezadoTextoSecundario`, el primer nombre en `nombreSaludo` `encabezadoTexto` y una línea de alto mínimo 44 (`Medidas.altoLineaEstadoInicio`): cápsula "▲ 4 pts en 7 días" (radio píldora, padding 12 × 6, `cuerpo` 700; sube `acentoOscuroTenue`/`encabezadoAcento`, baja `encabezadoSuperficie`/`eventoFrenada`) o el aviso del estado en `cuerpoPequeno` `encabezadoTextoSecundario` (sin viajes con puntaje, menos de 3, sin viajes en 7 días, error con "Reintentar" en `encabezadoAcento`). A la derecha, el anillo de 132; abre Mi DriveScore si hay viajes con puntaje. **Botón flotante** a medio montar sobre el borde: alto 64 (`Medidas.altoBotonInicio`), radio píldora, `encabezadoAcento` con `sombraBotonAcento`, texto `botonGrande` `sobreAcentoOscuro` (padding izquierdo 24) y círculo de 46 (`Medidas.circuloBotonInicio`) `encabezadoFondo` con el ícono de 24 en `encabezadoAcento` (o el indicador de carga). Debajo, si corresponde, avisos con fondo `tinteAdvertencia` (viaje sin terminar con "Finalizar", resumen pendiente) y errores. **Esta semana** (`tituloTarjeta`) con "Mis viajes" (`cuerpo` 700 `enlace`); tres tarjetas blancas (radio `radioMicro`, borde, padding 16, separación 12): número en `puntaje` (km enteros, tiempo "1h 25m"; "—" sin dato) y etiqueta en `cuerpo` `textoSecundario`. **Último viaje**: tarjeta grande (radio 24, borde, `sombraTarjeta`, padding 16), caja de ícono de 44 `tintePrimario`, "Último viaje · Hoy 08:10" (`cuerpoPequeno` `textoSecundario`; "1 oct" si no es hoy ni ayer), "16,2 km · 32 min" (`subtitulo` 700), cápsula del DriveScore (radio píldora, padding 12 × 8, `numeroMetrica` 700, tinte y color de la calificación; sin cápsula si el viaje no tiene puntaje) y chevron |
| **Tarjeta oscura de recorrido** | (Inicio anterior al diseño B; ya no se usa) |
| **Bloque en vivo** | Alto 460 (`Medidas.altoBloqueEnVivo`), fondo `encabezadoFondo`, radio inferior `radioEncabezado`; diana centrada detrás de la velocidad y ruta punteada en `encabezadoAcento`. Botón volver: caja de 44, fondo `encabezadoSuperficie`, borde `encabezadoBorde`, radio `radioLogo`. Cápsulas: "Registrando" con fondo `acentoOscuroTenue` y texto `encabezadoAcento`; "GPS" con contorno `encabezadoBorde` (sin señal: `advertencia`) |
| **Micro-tarjeta en vivo** | Radio 16, fondo `superficie`, borde + `sombraTarjeta`, padding 16; caja de ícono de 36 tintada (`tintePrimario` / `tinteConfort`) y valor en `numeroGrande` |
| **Marcar maniobra** (solo desarrollo, modo calibración) | Botón flotante extendido de 64 de alto (`Medidas.altoBotonMarca`), `StadiumBorder`, fondo `encabezadoAcento`, texto `boton` e ícono en `sobreAcentoOscuro`, centrado sobre el bloque en vivo, 20 por encima de su borde inferior (debajo de la máxima). En la versión de desarrollo el panel de diagnóstico va debajo de la tarjeta de eventos. Hoja inferior: título `subtitulo` y grilla de 2 columnas (de a dos en orden; la última fila puede quedar con una sola, de media fila) de opciones de 96 de alto (`Medidas.altoOpcionMarca`), radio `radioMicro`, sin borde, ícono de 24 y texto `subtitulo` en el color del tinte: frenada `tintePeligro`/`textoPeligro`, aceleración `tinteConfort`/`confort`, giro `tinteAdvertencia`/`advertencia`, bache `tinteSecundario`/`secundario`, teléfono `tintePrimario`/`primarioOscuro` |
| **Aviso de evento puntual** (HU-14, diseño B) | Durante 4 s: aro de 2 dp alrededor de la diana (radio 80 × escala) y punto con resplandor sobre la ruta, en el tono vivo del tipo; la cápsula "Máxima" se reemplaza por una cápsula de 52 de alto (`Medidas.altoCapsulaEvento`), radio píldora, padding horizontal 24, fondo en el tono vivo, ícono de 24 y nombre ("Frenada brusca", "Aceleración severa", "Giro agresivo") en `subtituloGrande`, ambos en `sobreAcentoOscuro`. Íconos: frenada `south`, aceleración `fast_forward_outlined`, giro `turn_right`, velocidad `speed` |
| **Aviso de exceso de velocidad** (HU-14, diseño C) | Mientras dura el tramo: número de velocidad y punto de la ruta en `eventoVelocidad`; cápsula de 52 de alto, fondo `encabezadoSuperficie`, borde `eventoVelocidad`, ícono `speed` de 20 en `eventoVelocidad`, "Sobre el límite de 60" en `subtitulo` `encabezadoTexto` y el tiempo `m:ss` en `numeroMetrica` 700 `eventoVelocidad`. Un aviso puntual tiene prioridad mientras se muestra |
| **Eventos de este viaje** (HU-14) | Tarjeta grande (radio 24, `superficie`, borde, `sombraTarjeta`), padding 16, `Etiqueta`; cuatro contadores en fila (separación 8), radio `radioMicro`, padding vertical 12, fondo en el tinte del tipo; ícono de 16 y número `numeroMetrica` 700 en el texto del tipo, etiqueta ("Frenadas", "Acelerac.", "Giros", "Velocidad") en `ayuda` `textoSecundario`. En 0: fondo `superficieAlt`, ícono y número en `textoSecundario`. Va bajo las micro-tarjetas, en el lugar del aviso "Puedes apagar la pantalla" |
| **Resumen con mapa** (HU-29, diseño 1) | Reemplaza al diseño C. Bloque `encabezadoFondo` de 176 + el margen superior (`Medidas.altoEncabezadoResumen`), radio inferior `radioEncabezado`, diana y ruta tenues arriba a la derecha. Círculo de 56 (`Medidas.circuloCheckResumen`) en `encabezadoAcento` con anillo exterior de 8 en `acentoOscuroTenue` y el check (pendiente: un teléfono) de 32 en `sobreAcentoOscuro`; "Viaje guardado" en `tituloGrande` `encabezadoTexto` y la franja horaria (pendiente: "En el teléfono · …") en `cuerpo` `encabezadoTextoSecundario`. La tarjeta del mapa se superpone 64 (`Medidas.superposicionMapaResumen`): radio `radioTarjeta`, borde, `sombraTarjeta`, padding 12; mapa de 180 (`Medidas.altoMapaResumen`) con radio `radioMicro`, cápsula "5 eventos" (`encabezadoFondo`, `cuerpo` 700 `encabezadoTexto`, padding 12 × 4) arriba a la izquierda y botón expandir arriba a la derecha; 16 abajo, los contadores por tipo y "Ver mapa completo ›" (`superficieAlt`, radio `radioMicro`, `subtitulo` en `enlace`). Luego la tarjeta del DriveScore (radio `radioTarjeta`, padding 16): anillo claro de 76 (pendiente: nube de 24 en `textoTerciario`), "DriveScore del viaje" en `Etiqueta`, la calificación en `tituloTarjeta` con los colores claros y "Lo que más restó" en `cuerpoPequeno` `textoSecundario`; chevron de 24 en `textoSecundario` si el viaje está finalizado (abre el detalle). Al final la tarjeta de cifras. Si la app lo finalizó sola (auto detenido), debajo de las cifras (y en el resumen de un viaje descartado, bajo el texto) un aviso con fondo `tinteAdvertencia`, radio `radioCampo`, padding 12, ícono de estacionamiento en `advertencia` y "Lo finalizamos automáticamente: estuviste detenido 3 min. El viaje termina donde te detuviste." en `cuerpoPequeno` `textoPrincipal`. Sin la tarjeta "Puntaje por categoría" ni el enlace al historial |
| **Contadores de eventos** (HU-29) | Fila de 4 columnas: caja de 40 (`Medidas.cajaIconoContador`, radio `radioCajaIcono`) en el tinte del tipo con el ícono de 20 en su texto; número en `puntaje` `textoPrincipal`; nombre ("Frenadas", "Aceleraciones", "Giros", "Excesos") en `cuerpoPequeno` `textoSecundario`. En 0: caja `superficieAlt`, ícono y número en `textoTerciario` |
| **Mapa del viaje** (HU-29) | OpenStreetMap con flutter_map (`MapaViaje`). Ruta simplificada con trazo de 5 en `gradienteScore` y borde de 3 en `bordeRuta`. Inicio: círculo de 20 (`Medidas.marcadorInicio`) `superficie` con borde de 4 `primario`. Fin: círculo de 28 `encabezadoFondo` con borde de 2 `superficie` y bandera de 16 en `encabezadoAcento`. Evento: círculo de 28 (`Medidas.marcadorEvento`) en el texto del tipo (`textoEvento*`), borde de 2 `superficie`, ícono de 16 en `superficie` (el blanco contrasta sobre los tonos de texto, no sobre los vivos), `sombraTarjeta`. Elegido: de 40 (`Medidas.marcadorEventoSeleccionado`) con ícono de 20 dentro de un halo de 64 (`Medidas.haloMarcador`) y encima la burbuja de 240 × 72 (`Medidas.anchoBurbujaEvento` / `altoBurbujaEvento`; `superficie`, radio `radioMicro`, `sombraTarjeta`): nombre en `subtitulo` con el texto del tipo, hora en `cuerpoPequeno` 700 `textoSecundario` y "3,4 m/s² · a 38 km/h" en `cuerpo` `textoPrincipal`. Atribución "© OpenStreetMap" siempre visible: cápsula `fondoAtribucion`, `ayuda` `textoSecundario`, abre openstreetmap.org/copyright. Botones sobre el mapa (`BotonMapa`): 44 en `superficie` con `sombraTarjeta`, radio `radioCampo` (volver: círculo), ícono de 24 en `textoPrincipal` |
| **Sin conexión en el mapa** (HU-29) | En lugar del mapa, mismo tamaño: fondo `superficieAlt`, ícono `cloud_off` de 32 en `textoTerciario`, "Sin conexión" en `subtitulo` `textoPrincipal`, "El mapa se verá cuando vuelvas a tener internet." en `cuerpoPequeno` `textoSecundario` y "Reintentar" (botón de texto). Se ocultan la cápsula de eventos, expandir y "Ver mapa completo"; los contadores y los datos siguen |
| **Mapa completo** (HU-29, diseño 2) | Mapa a pantalla completa. Arriba: volver (círculo) y la tarjeta "Ruta del viaje" (`superficie`, radio `radioMicro`, `sombraTarjeta`, padding 16 × 8; `subtitulo` y "Hoy · 16:05 – 16:23 · 7,40 km" en `cuerpoPequeno` `textoSecundario`). Debajo, filtros de 44 de alto (`Medidas.altoChipMapa`) con desplazamiento horizontal, radio píldora: "Todos 5" activo en `textoPrincipal` con texto `sobrePrimario`; los tipos con eventos llevan un círculo de 32 en su tinte con el ícono de 16; inactivos `superficie` con borde `borde`; texto `cuerpo` 700. Hoja inferior arrastrable (40 %, entre 20 y 75 %): `superficie`, radio superior `radioTarjeta`, asa de 40 × 4 `bordeFuerte`, "Eventos del viaje" en `subtituloGrande` y "Toca uno para verlo" en `cuerpoPequeno` `textoSecundario`; filas con caja de 44 en el tinte del tipo, nombre `subtitulo`, detalle `cuerpo` `textoSecundario` y hora `numeroMetrica` 700; la elegida en `superficieAlt` con borde `borde`, radio `radioMicro`. Botón "ver la ruta entera" (`center_focus_weak`) abajo a la derecha, sobre la hoja; atribución centrada sobre la hoja |
| **Resumen con DriveScore** (HU-15, diseño C; reemplazado por el diseño 1 de HU-29) | Bloque de 300, fondo `encabezadoFondo`, radio inferior `radioEncabezado`, diana y ruta tenues (`encabezadoBorde` / `acentoOscuroTenue`). Arriba "Viaje guardado · Hoy 16:05 – 16:23" en `cuerpo` `encabezadoTextoSecundario`. Anillo de 150 (`Medidas.anilloResumen`), trazo 12 (`Medidas.trazoAnillo`), carril `encabezadoBorde`, arco con `gradienteScore` desde arriba y extremos redondeados; número en `puntajeAnillo` (Space Grotesk 48 / 700) `encabezadoTexto` y "DriveScore" en `ayuda` 600 `encabezadoTextoSecundario`. A la derecha, la calificación en `tituloTarjeta`: Excelente y Muy bueno `encabezadoAcento`, Regular `eventoGiro`, Riesgoso `eventoFrenada`. Pendiente de envío: solo el carril con una nube (`iconoEstado`) y "Calculando tu DriveScore" + "Se calculará cuando se envíe el viaje." (`cuerpoPequeno`). Debajo, 20 de separación y la tarjeta de cifras en una fila de 4 (radio `radioTarjeta`, padding 12 × 16): valor `numeroLista` + unidad y etiqueta en `ayuda` `textoSecundario`. Junto a la calificación, "Lo que más restó: frenadas" (o, sin eventos, "Sin eventos de riesgo. ¡Sigue así!") en `cuerpoPequeno` `encabezadoTextoSecundario`. Entre el bloque y las cifras, la tarjeta "Puntaje por categoría" (HU-16), solo con puntaje |
| **Puntaje por categoría** (HU-16) | Tarjeta grande (radio 24, `superficie`, borde, `sombraTarjeta`), padding 16, `Etiqueta` y 16 de separación. Una fila por categoría (frenadas, aceleraciones, giros, velocidad), separadas 12: caja de ícono de 36 (radio `radioCajaIcono`) en el tinte del tipo de evento con el ícono de 20 en su texto (íconos de HU-14), nombre en `cuerpo` `textoPrincipal`, barra de 8 (`Medidas.altoBarra`, carril `carril`, relleno `textoEvento*`, radio píldora) y puntaje en `numeroMetrica` 700 alineado a la derecha. Con `eventosPorTipo`, bajo el nombre, los eventos ("1 frenada", "2 giros", "Sin eventos") en `ayuda` `textoSecundario` (desde HU-29 el detalle ya no los pasa: van en los contadores). "Lo que más restó": la categoría con menor puntaje (< 100); en empate, la de mayor peso y, con el mismo peso, el orden de la lista |
| **Viaje descartado** | Círculo de 88 (`Medidas.circuloDescartado`) en `tinteAdvertencia` con ícono en `advertencia` |
| **Mis viajes (historial)** | Título `titulo`; chips de periodo (sección 4). Tarjeta de resumen: fondo `gradienteScore`, radio `radioTarjeta`, padding 20, diana reducida en `lineasSobreGradiente` recortada en la esquina superior derecha; tres columnas con el número en `puntaje` (unidad en `cuerpoPequeno`) y el texto en `cuerpoPequeno`, todo en `textoSobreGradiente`. Lista agrupada por día con `Etiqueta` grande ("Hoy", "Ayer" o la fecha) |
| **Fila de viaje** | Tarjeta grande (radio 24, `superficie`, borde, `sombraTarjeta`), padding 16; caja de ícono de 44 (`Medidas.cajaIconoFila`, radio 12) que rota entre `tintePrimario`/`primarioOscuro`, `tinteSecundario`/`secundario` y `tinteConfort`/`confort`; franja horaria en `subtitulo`, "18 min · máx. 62 km/h" en `cuerpoPequeno` `textoSecundario`; distancia en `numeroLista` + "km" en `cuerpoPequeno`; chevron en `textoTerciario` |
| **Detalle del viaje con mapa** (HU-29, diseño 3) | Con ruta, el mapa reemplaza la cabecera de degradado: 300 + el margen superior (`Medidas.altoMapaDetalle`), sin interacción (tocarlo abre el mapa completo). Encima: volver (círculo), cápsula "Detalle del viaje" (`superficie`, radio píldora, `subtitulo`) y expandir a la derecha. Tarjeta superpuesta 40 (radio `radioTarjetaDestacada`, padding 20 × 16): la fecha en `cuerpo` `textoSecundario`; "○ 16:05 → ● 16:23" (anillo de 12 con borde de 3 `primario`, flecha en `textoTerciario`, punto `textoPrincipal`, horas en `numeroMetrica` 700) y a la derecha la distancia en `numeroGrande` con "km" en `cuerpo` `textoSecundario`. Debajo, la tarjeta de contadores (si el viaje tiene DriveScore), la del DriveScore con el desglose **sin** la cantidad de eventos bajo cada categoría y las cifras. Sin ruta, el detalle de siempre (abajo) |
| **Detalle del viaje** | Cabecera de 280 (`Medidas.altoCabeceraDetalle`) con `gradienteScore`, radio inferior `radioEncabezado` y la ruta + diana en `lineasSobreGradiente`. Botón volver: caja de 44, fondo `superficieSobreGradiente`, radio `radioCampo`. Título `subtituloGrande`, fecha `subtitulo` y distancia en `telemetriaXL`, en `textoSobreGradiente`. Tarjeta de salida/llegada superpuesta 40 (`Medidas.superposicionDetalle`), radio `radioTarjetaDestacada`: punto de 12 en `primario` (salida) y anillo en el color final del degradado (llegada), unidos por una línea punteada `bordeFuerte`; horas en `numeroMetrica` con peso 700. Debajo (diseño D, HU-16), tarjeta del DriveScore (radio `radioTarjeta`, `superficie`, borde, `sombraTarjeta`, padding 16): anillo de 76, "DriveScore" en `Etiqueta`, la calificación en `tituloTarjeta` (Excelente y Muy bueno `primarioOscuro`, Regular `textoEventoGiro`, Riesgoso `textoEventoFrenada`) y "Lo que más restó" en `cuerpoPequeno` `textoSecundario`; 20 de separación y el desglose por categoría con sus eventos. Sin DriveScore (viajes anteriores a HU-15) no se muestra. Al final, la tarjeta de cifras en una fila de 4, igual que en el resumen |
| **Tu DriveScore en Inicio** (HU-17, diseños 1 y 3) | Reemplazada por el encabezado de Inicio (diseño B), que conserva sus estados |
| **Mi DriveScore** (HU-17, diseño 2) | Pantalla sobre la barra, fondo `fondo`. Volver en caja de 44 `superficie` con borde (radio `radioCampo`) y "Mi DriveScore" en `titulo`. Chips de periodo (7 días, 30 días, 3 meses) como los del historial (`ChipsPeriodo`). Tarjeta del promedio (padding 20): "Promedio · 12 viajes" en `cuerpo` `textoSecundario`, número en `telemetria` (56) `textoPrincipal`, la calificación en `tituloTarjeta` (colores claros de la calificación) y, a la derecha, la cápsula de tendencia; debajo, el gráfico. Tarjeta "Promedio por categoría" con las filas del desglose (HU-16) y al final el cambio en `cuerpoPequeno` 700: "▲ 5" `primarioOscuro`, "▼ 2" `textoPeligro`, "=" `textoSecundario` (sin periodo anterior, vacío). Abajo, "Mejor viaje" (`tintePrimario`) y "Viaje más bajo" (`tintePeligro`) en dos columnas: radio 24, padding 20, título `cuerpo` `textoSecundario`, puntaje en `puntaje`, "28 sep · 12,1 km" en `cuerpoPequeno`; abren el detalle. Periodo sin viajes: tarjeta con círculo de estado (`tintePrimario`, ícono `insights`), "No tienes viajes en los últimos 7 días" y botones "Ver 30 días" / "Ver 3 meses" |
| **Cápsula de tendencia** (HU-17) | Radio píldora, padding 12 × 4, texto `ayuda` 700: sube `tintePrimario`/`primarioOscuro` ("▲ 4 pts"), baja `tintePeligro`/`textoPeligro` ("▼"), igual `superficieAlt`/`textoSecundario` ("="). Sin periodo anterior no se muestra |
| **Sin viajes** | Ilustración de 160 (`Medidas.ilustracionVacia`): diana en `bordeFuerte` y ruta punteada con `gradienteScore` entre dos puntos (`primario` y el color final del degradado). Título `subtituloGrande`, texto `cuerpo` en `textoSecundario`. Botón oscuro: píldora `textoPrincipal`, texto `sobrePrimario` y círculo `encabezadoAcento` con el ícono en `sobreAcentoOscuro` |
| **Perfil** | Avatar de 64 (`Medidas.avatarGrande`); cápsula del rol en `tintePrimario` con texto `primarioOscuro`; "Cerrar sesión" de contorno con borde `bordePeligroSuave` y texto e ícono `textoPeligro` |

## 8. Íconos

- Ícono de la app (launcher y arranque): el velocímetro de `LogoDriveSense` en `encabezadoAcento` (#34D399) sobre `encabezadoSuperficie` (#12171F), igual que el favicon del panel. En la pantalla de arranque, solo el velocímetro sobre `encabezadoFondo`.
- Tamaños: 16 dp en listas de requisitos (`iconoPequeno`), 20 dp en botones y cajas de ícono, 24 dp en la barra de navegación, 32 dp dentro de los círculos de estado del resumen (`iconoEstado`) **(propuesta)**.
- El color siempre se toma de los tokens, nunca de `Colors.*`.

## 9. Implementación en el tema

Estructura:

```
lib/core/design/
├── colors.dart      → ThemeExtension<ColoresDriveSense> con .claro (y en el futuro .oscuro); incluye sombras y degradados
├── typography.dart  → ThemeExtension<TipografiaDriveSense> (Space Grotesk + Plus Jakarta Sans) y su TextTheme
├── spacing.dart     → Espacios, Radios y Medidas (no cambian entre modos)
└── design.dart      → exporta todo y define context.colores / context.tipografia
lib/app/theme.dart   → arma ThemeData (colorScheme, textTheme, botones, campos, extensiones)
```

- **Todo lo que depende del modo** (colores, tintes, degradados, sombras) va en una `ThemeExtension` con `copyWith` y `lerp`. Así el modo oscuro será solo otra instancia (`ColoresDriveSense.oscuro`) y un `darkTheme` en `MaterialApp`, sin tocar pantallas.
- **Lo que no depende del modo** (espaciado, radios, tamaños) puede ir en constantes (`abstract final class Espacios { static const m = 16.0; }`).
- `ColorScheme` también se rellena con estos tokens (`primary: primario`, `surface: superficie`, `error: peligro`, `onPrimary: sobrePrimario`…), para que los widgets de Material usen la paleta sin configuración extra. **No** usar `ColorScheme.fromSeed`, porque generaría colores distintos a los de la guía.
- Acceso en pantallas mediante una extensión de `BuildContext`:

```dart
final colores = context.colores;     // Theme.of(context).extension<ColoresDriveSense>()!
final texto = context.tipografia;    // estilos de Space Grotesk + TextTheme
Text('82', style: texto.puntaje.copyWith(color: colores.textoPrincipal));
```
