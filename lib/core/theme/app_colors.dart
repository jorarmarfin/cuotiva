import 'package:flutter/material.dart';

/// Paleta de Cuotiva: logo (assets/images/logo.png) + especificación visual.
/// El diseño (CUOTIVA_SPEC.md §6) manda sobre el color extraído del logo.
abstract final class AppColors {
  static const brand = Color(0xFF6D28D9);
  static const brandLight = Color(0xFFA78BFA);
  static const brandDark = Color(0xFF4C1D95);

  static const mint = Color(0xFF34D399); // éxito / recaudado
  static const amber = Color(0xFFFBBF24); // acento cálido
  static const surface = Color(0xFFFAF8FF);
  static const text = Color(0xFF201A2E);

  static const success = mint;
  static const warning = amber;
  static const error = Color(0xFFE53935);
}
