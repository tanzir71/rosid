// Generates lib/core/theme/tokens.g.dart from design/tokens.json.
// Run: dart run tool/generate_tokens.dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final source = File('design/tokens.json');
  final raw = jsonDecode(await source.readAsString()) as Map<String, dynamic>;
  final colours = raw['colour'] as Map<String, dynamic>;
  final sizes = raw['size'] as Map<String, dynamic>;
  final textStyles = raw['text'] as Map<String, dynamic>;
  final effects = raw['effects'] as Map<String, dynamic>;

  final buf = StringBuffer()
    ..writeln('// GENERATED FILE. DO NOT EDIT.')
    ..writeln('// Source: design/tokens.json')
    ..writeln('// Run: dart run tool/generate_tokens.dart')
    ..writeln()
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln()
    ..writeln('abstract final class RosidColorTokens {');

  for (final entry in colours.entries) {
    final name = _camel(entry.key);
    final map = entry.value as Map<String, dynamic>;
    final lightHex = _hex(map['light'] as String);
    final darkHex = _hex(map['dark'] as String);
    buf.writeln('  static const Color ${name}Light = Color($lightHex);');
    buf.writeln('  static const Color ${name}Dark = Color($darkHex);');
  }
  buf
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class RosidSizeTokens {');

  for (final entry in sizes.entries) {
    final name = _camel(entry.key);
    final value = (entry.value as num).toDouble();
    buf.writeln('  static const double $name = $value;');
  }
  buf
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class RosidTextTokens {');

  for (final entry in textStyles.entries) {
    final key = entry.key;
    if (key.startsWith('web/')) continue;
    final name = _camel(key);
    final map = entry.value as Map<String, dynamic>;
    final family = map['family'] as String;
    final weight = _weight(map['weight'] as String);
    final size = (map['size'] as num).toDouble();
    final lineHeight = (map['lineHeight'] as num).toDouble();
    final heightRatio = (lineHeight / size).toStringAsFixed(4);
    final letterSpacingPercent = (map['letterSpacingPercent'] as num)
        .toDouble();
    final letterSpacing = letterSpacingPercent == 0
        ? null
        : (size * letterSpacingPercent / 100.0).toStringAsFixed(3);
    buf
      ..writeln('  static const TextStyle $name = TextStyle(')
      ..writeln("    fontFamily: '$family',")
      ..writeln('    fontWeight: $weight,')
      ..writeln('    fontSize: $size,')
      ..writeln('    height: $heightRatio,');
    if (letterSpacing != null) {
      buf.writeln('    letterSpacing: $letterSpacing,');
    }
    buf
      ..writeln('    fontStyle: FontStyle.normal,')
      ..writeln('  );');
  }
  buf
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class RosidShadowTokens {');

  for (final entry in effects.entries) {
    final name = _camel(entry.key);
    final list = entry.value as List<dynamic>;
    buf.writeln('  static const List<BoxShadow> $name = <BoxShadow>[');
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final x = (m['x'] as num).toDouble();
      final y = (m['y'] as num).toDouble();
      final blur = (m['blur'] as num).toDouble();
      final alpha = ((m['alpha'] as num).toDouble() * 255).round();
      final hexRgb = (m['colour'] as String).replaceFirst('#', '');
      final argb =
          '0x${alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}${hexRgb.toUpperCase()}';
      buf
        ..writeln('    BoxShadow(')
        ..writeln('      color: Color($argb),')
        ..writeln('      offset: Offset($x, $y),')
        ..writeln('      blurRadius: $blur,')
        ..writeln('    ),');
    }
    buf.writeln('  ];');
  }
  buf.writeln('}');

  final out = File('lib/core/theme/tokens.g.dart');
  await out.create(recursive: true);
  await out.writeAsString(buf.toString(), flush: true);
  stdout.writeln('Generated ${out.path}');
}

String _camel(String key) {
  final parts = key.split(RegExp(r'[/\-_]'));
  final sb = StringBuffer(parts.first.toLowerCase());
  for (var i = 1; i < parts.length; i++) {
    final p = parts[i];
    if (p.isEmpty) continue;
    sb.write(p[0].toUpperCase() + p.substring(1).toLowerCase());
  }
  return sb.toString();
}

String _hex(String css) => '0xFF${css.replaceFirst('#', '').toUpperCase()}';

String _weight(String name) => switch (name.toLowerCase()) {
  'regular' => 'FontWeight.w400',
  'medium' => 'FontWeight.w500',
  'semibold' => 'FontWeight.w600',
  'bold' => 'FontWeight.w700',
  _ => 'FontWeight.w400',
};
