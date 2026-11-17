# Cuotiva

*Cada cuota cuenta.* App Android (Flutter), local-first y mono-usuario, para controlar cobros, cuotas y abonos.

- Spec: [`spec/CUOTIVA_SPEC.md`](spec/CUOTIVA_SPEC.md)
- Plan de fases y estado: [`.claude/spec-plan.md`](.claude/spec-plan.md)
- Decisiones: [`docs/adr/`](docs/adr/)

## Comandos

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # código Drift
flutter analyze
flutter test
flutter run            # o ./run.sh (Linux/Android auto), ./run.sh test, ./run.sh clean
./scripts/build_release.sh apk        # release ofuscado
./scripts/build_release.sh appbundle
```

No se guardan credenciales de firma en el repositorio.
