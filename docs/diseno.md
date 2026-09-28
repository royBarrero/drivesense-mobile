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
| `textoSecundario` | #5F6B76 | `0xFF5F6B76` | Etiquetas, descripciones |
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
- Pesos que hay que incluir: Plus Jakarta Sans 400, 500, 600 y 700; Space Grotesk 500 y 700.

| Token | Fuente | Tamaño | Peso | Otros | Uso |
|---|---|---|---|---|---|
| `velocimetro` | Space Grotesk | 120 | 700 | `height: 1.0` | Velocidad de la pantalla en vivo **(propuesta)** |
| `telemetriaXL` | Space Grotesk | 64 | 700 (`w700`) | `height: 1.0` | Velocímetro principal |
| `numeroGrande` | Space Grotesk | 32 | 700 | `height: 1.1` | Valores de las micro-tarjetas en vivo **(propuesta)** |
| `telemetria` | Space Grotesk | 56 | 700 | `height: 1.0` | Otros valores grandes en vivo |
| `puntaje` | Space Grotesk | 28 | 700 | `height: 1.1` | DriveScore y puntajes en tarjetas |
| `numeroMetrica` | Space Grotesk | 18 | 500 | — | Valores numéricos pequeños (km, min) **(propuesta)** |
| `tituloGrande` | Plus Jakarta Sans | 28 | 700 | `height: 1.2` | Saludo de Inicio, título del resumen **(propuesta)** |
| `titulo` | Plus Jakarta Sans | 24 | 700 | `height: 1.2` | H1 de pantalla |
| `subtituloGrande` | Plus Jakarta Sans | 18 | 600 | `height: 1.3` | Encabezado de tarjeta grande |
| `subtitulo` | Plus Jakarta Sans | 16 | 600 | `height: 1.3` | Encabezado de tarjeta |
| `cuerpo` | Plus Jakarta Sans | 14 | 400 | `height: 1.5` | Texto general |
| `cuerpoPequeno` | Plus Jakarta Sans | 13 | 400 | `height: 1.5` | Texto de apoyo |
| `boton` | Plus Jakarta Sans | 16 | 600 | — | Texto de botones **(propuesta de tamaño)** |
| `tituloHero` | Plus Jakarta Sans | 32 | 700 | `height: 1.15` | Título del encabezado oscuro ("Cada viaje cuenta.") |
| `tituloTarjeta` | Plus Jakarta Sans | 22 | 700 | `height: 1.25` | Título de tarjeta de formulario ("Inicia sesión") |
| `marca` | Plus Jakarta Sans | 20 | 700 | — | "DriveSense" junto al logo |
| `etiquetaCampo` | Plus Jakarta Sans | 13 | 600 | — | Etiqueta encima de un campo de formulario (sin mayúsculas) |
| `ayuda` | Plus Jakarta Sans | 12 | 400 | `height: 1.4` | Textos de ayuda bajo botones y formularios |
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

Los estilos de Space Grotesk (`velocimetro`, `telemetriaXL`, `telemetria`, `numeroGrande`, `puntaje`, `numeroMetrica`) y `tituloGrande` no encajan en `TextTheme` y van en la `ThemeExtension` (sección 9).

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
- Tarjeta de Inicio: 88×88 (`Medidas.anilloInicio`) con trazo de 10 (`Medidas.trazoAnilloPequeno`) **(propuesta)**.
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

### Barras de progreso
- Alto de 8 dp (6 en listas compactas), radio píldora, carril `carril`.
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
| **Cabecera de Inicio** | Logo pequeño (caja de 36, radio 12, fondo `encabezadoFondo`) + "DriveSense" (`subtitulo`); a la derecha el avatar con las iniciales (círculo de 44, `Medidas.avatar`, fondo `encabezadoFondo`, texto `encabezadoAcento` en `subtitulo`) |
| **Tarjeta oscura de recorrido** | Fondo `encabezadoFondo`, radio `radioTarjetaDestacada` (28), padding 24, diana (círculos + ejes en `encabezadoBorde`) recortada en la esquina superior derecha. Etiqueta en `encabezadoAcento`, título `tituloTarjeta` en `encabezadoTexto`, texto `cuerpo` en `encabezadoTextoSecundario` |
| **Bloque en vivo** | Alto 460 (`Medidas.altoBloqueEnVivo`), fondo `encabezadoFondo`, radio inferior `radioEncabezado`; diana centrada detrás de la velocidad y ruta punteada en `encabezadoAcento`. Botón volver: caja de 44, fondo `encabezadoSuperficie`, borde `encabezadoBorde`, radio `radioLogo`. Cápsulas: "Registrando" con fondo `acentoOscuroTenue` y texto `encabezadoAcento`; "GPS" con contorno `encabezadoBorde` (sin señal: `advertencia`) |
| **Micro-tarjeta en vivo** | Radio 16, fondo `superficie`, borde + `sombraTarjeta`, padding 16; caja de ícono de 36 tintada (`tintePrimario` / `tinteConfort`) y valor en `numeroGrande` |
| **Bloque del resumen** | Alto 300 (`Medidas.altoBloqueResumen`), fondo `encabezadoFondo`, radio inferior `radioEncabezado`; círculo de 64 (`Medidas.circuloEstado`) en `encabezadoAcento` con check en `sobreAcentoOscuro`; título `tituloGrande` en `encabezadoTexto`. La tarjeta de métricas se superpone 48 (`Medidas.superposicionResumen`) |
| **Viaje descartado** | Círculo de 88 (`Medidas.circuloDescartado`) en `tinteAdvertencia` con ícono en `advertencia` |
| **Perfil** | Avatar de 64 (`Medidas.avatarGrande`); cápsula del rol en `tintePrimario` con texto `primarioOscuro`; "Cerrar sesión" de contorno con borde `bordePeligroSuave` y texto e ícono `textoPeligro` |

## 8. Íconos

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
