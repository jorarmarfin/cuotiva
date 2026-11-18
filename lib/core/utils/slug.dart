/// Texto apto para nombre de archivo: minúsculas, sin tildes, separado por
/// guiones. «Trajes 2027 · Ñandú» → `trajes-2027-nandu`.
String slugify(String input, {int maxLength = 40}) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final b = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  var s = b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.length > maxLength) {
    s = s.substring(0, maxLength).replaceAll(RegExp(r'-+$'), '');
  }
  return s;
}

/// `estado-de-cuenta_<partes>` omitiendo las partes vacías.
String reportFileName(String base, Iterable<String> parts) => [
  base,
  for (final p in parts)
    if (slugify(p).isNotEmpty) slugify(p),
].join('_');
