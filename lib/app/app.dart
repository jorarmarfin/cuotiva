import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/app_constants.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/update/app_update_service.dart';

class CuotivaApp extends StatefulWidget {
  const CuotivaApp({super.key});

  @override
  State<CuotivaApp> createState() => _CuotivaAppState();
}

class _CuotivaAppState extends State<CuotivaApp> {
  @override
  void initState() {
    super.initState();
    // Tras el primer frame, sin bloquear el arranque.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppUpdateService.instance.checkAndDownload());
    });
  }

  @override
  void dispose() {
    AppUpdateService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: rootMessengerKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light, // modo oscuro: mejora posterior (spec §6)
      routerConfig: appRouter,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
