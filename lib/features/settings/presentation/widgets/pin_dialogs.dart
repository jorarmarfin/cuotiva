import 'package:flutter/material.dart';

import '../../../../core/security/pin_service.dart';

/// Pide un PIN (con confirmación si [confirm]). Devuelve null si se cancela.
Future<String?> askPin(
  BuildContext context, {
  required String title,
  bool confirm = false,
}) {
  final a = TextEditingController();
  final b = TextEditingController();
  final formKey = GlobalKey<FormState>();
  InputDecoration deco(String l) =>
      InputDecoration(labelText: l, counterText: '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            TextFormField(
              controller: a,
              autofocus: true,
              obscureText: true,
              maxLength: PinService.maxLength,
              keyboardType: TextInputType.number,
              decoration: deco(
                'PIN (${PinService.minLength}-${PinService.maxLength} dígitos)',
              ),
              validator: (v) => PinService.isValidFormat(v ?? '')
                  ? null
                  : 'Entre ${PinService.minLength} y ${PinService.maxLength} dígitos',
            ),
            if (confirm)
              TextFormField(
                controller: b,
                obscureText: true,
                maxLength: PinService.maxLength,
                keyboardType: TextInputType.number,
                decoration: deco('Repite el PIN'),
                validator: (v) => v == a.text ? null : 'No coincide',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, a.text);
          },
          child: const Text('Aceptar'),
        ),
      ],
    ),
  ).whenComplete(() {
    a.dispose();
    b.dispose();
  });
}
