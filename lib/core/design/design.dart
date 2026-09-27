import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

export 'colors.dart';
export 'spacing.dart';
export 'typography.dart';

/// Acceso a los tokens desde las pantallas: `context.colores`, `context.tipografia`.
extension DisenoContexto on BuildContext {
  ColoresDriveSense get colores =>
      Theme.of(this).extension<ColoresDriveSense>()!;
  TipografiaDriveSense get tipografia =>
      Theme.of(this).extension<TipografiaDriveSense>()!;
}
