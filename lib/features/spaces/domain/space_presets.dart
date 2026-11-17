import 'package:flutter/material.dart';

class SpaceType {
  const SpaceType(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final String icon;
  final int color;
}

/// Tipos sugeridos (CUOTIVA_SPEC §2). El usuario puede cambiar color e ícono.
const spaceTypes = [
  SpaceType('family', 'Familia', 'family', 0xFF6D28D9),
  SpaceType('business', 'Negocio', 'store', 0xFF34D399),
  SpaceType('school', 'Colegio', 'school', 0xFF2563EB),
  SpaceType('chapel', 'Capilla', 'church', 0xFFF59E0B),
  SpaceType('work', 'Trabajo', 'work', 0xFF0EA5E9),
  SpaceType('events', 'Eventos', 'event', 0xFFEF4444),
  SpaceType('other', 'Otro', 'folder', 0xFF64748B),
];

const spaceIcons = <String, IconData>{
  'family': Icons.family_restroom,
  'store': Icons.storefront,
  'school': Icons.school,
  'church': Icons.church,
  'work': Icons.work,
  'event': Icons.event,
  'folder': Icons.folder,
};

IconData spaceIconData(String key) => spaceIcons[key] ?? Icons.folder;

const spaceColors = [
  0xFF6D28D9,
  0xFF34D399,
  0xFF2563EB,
  0xFFF59E0B,
  0xFF0EA5E9,
  0xFFEF4444,
  0xFFEC4899,
  0xFF64748B,
];
