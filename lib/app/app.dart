import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class DriveSenseApp extends ConsumerWidget {
  const DriveSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'DriveSense',
      debugShowCheckedModeBanner: false,
      theme: temaClaro(),
      routerConfig: ref.watch(rutasProvider),
      // Textos propios de Material (copiar/pegar, tooltips) en español
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
