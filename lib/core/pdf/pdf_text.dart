/// Las fuentes base de PDF (Helvetica) cubren Latin-1: tildes, ñ y «S/» van
/// bien, pero emojis o símbolos fuera de ese rango se dibujarían rotos.
/// Se reemplazan por «?» (o se descartan los de formato) antes de imprimir.
String pdfSafe(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    if (r == 0x2013 || r == 0x2014) {
      b.write('-');
    } else if (r == 0x2018 || r == 0x2019) {
      b.write("'");
    } else if (r == 0x201C || r == 0x201D) {
      b.write('"');
    } else if (r == 0x200D || (r >= 0xFE00 && r <= 0xFE0F)) {
      continue;
    } else if (r == 10 ||
        r == 13 ||
        (r >= 32 && r <= 126) ||
        (r >= 160 && r <= 255)) {
      b.writeCharCode(r);
    } else {
      b.write('?');
    }
  }
  return b.toString();
}
