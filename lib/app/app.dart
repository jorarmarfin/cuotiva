import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/repository_providers.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/update/app_update_service.dart';
import '../core/widgets/lock_screen.dart';

class CuotivaApp extends ConsumerStatefulWidget {
  const CuotivaApp({super.key, this.startupMessage});

  /// Aviso al arrancar (p. ej. restauración fallida y revertida).
  final String? startupMessage;

  @override
  ConsumerState<CuotivaApp> createState() => _CuotivaAppState();
}

class _CuotivaAppState extends ConsumerState<CuotivaApp> {
  @override
  void initState() {
    super.initState();
    // Tras el primer frame, sin bloquear el arranque.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppUpdateService.instance.checkAndDownload());
      // Comprobantes de versiones previas al cifrado.
      unawaited(_encryptPending());
      final msg = widget.startupMessage;
      if (msg != null) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    });
  }

  Future<void> _encryptPending() async {
    try {
      await ref.read(attachmentsRepositoryProvider).encryptPending();
    } on Object {
      // No bloquea el arranque; se reintenta en el próximo inicio.
    }
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
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
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
