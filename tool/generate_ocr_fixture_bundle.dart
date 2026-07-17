import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as image;

const _fixtures = [
  'english_receipt.png',
  'mixed_bangla_receipt.png',
  'handwritten_bangla_note.png',
];

Future<void> main() async {
  final output = StringBuffer()
    ..writeln('// GENERATED FILE. DO NOT EDIT.')
    ..writeln('// Run: dart run tool/generate_ocr_fixture_bundle.dart')
    ..writeln()
    ..writeln('final ocrFixtureBase64 = <String, String>{');
  for (final name in _fixtures) {
    final source = File('assets/fixtures/$name');
    final decoded = image.decodeImage(await source.readAsBytes());
    if (decoded == null) throw FormatException('Cannot decode ${source.path}');
    final oriented = image.bakeOrientation(decoded);
    final longest = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longest <= 1200
        ? oriented
        : image.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? 1200 : null,
            height: oriented.height > oriented.width ? 1200 : null,
            interpolation: image.Interpolation.linear,
          );
    final encoded = base64Encode(image.encodeJpg(resized, quality: 88));
    output.writeln("  'assets/fixtures/$name': [");
    for (var offset = 0; offset < encoded.length; offset += 100) {
      final end = (offset + 100).clamp(0, encoded.length);
      output.writeln("    '${encoded.substring(offset, end)}',");
    }
    output.writeln('  ].join(),');
  }
  output.writeln('};');
  await File(
    'integration_test/ocr_fixture_bytes.g.dart',
  ).writeAsString(output.toString(), flush: true);
}
