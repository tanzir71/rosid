import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// Loads bundled Anek Bangla and Tiro Bangla fonts into Flutter's test font
/// registry so golden PNGs render authentic Bangla & English typography.
Future<void> loadRosidTestFonts() async {
  if (_loaded) return;
  _loaded = true;

  final anek = FontLoader('Anek Bangla');
  for (final file in const [
    'assets/fonts/AnekBangla-Regular.ttf',
    'assets/fonts/AnekBangla-Medium.ttf',
    'assets/fonts/AnekBangla-SemiBold.ttf',
    'assets/fonts/AnekBangla-Bold.ttf',
  ]) {
    final bytes = await File(file).readAsBytes();
    anek.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await anek.load();

  final tiro = FontLoader('Tiro Bangla');
  final tiroBytes = await File('assets/fonts/TiroBangla-Regular.ttf')
      .readAsBytes();
  tiro.addFont(Future.value(ByteData.view(tiroBytes.buffer)));
  await tiro.load();
}
