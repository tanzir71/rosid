import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ has no hard-coded user-visible string literals in Text(...)', () {
    final libDir = Directory('lib');
    final pattern = RegExp(r'''\bText\s*\(\s*r?['"]([^'"]+)['"]''');
    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (normalizedPath.endsWith('.g.dart') ||
          normalizedPath.contains('lib/core/l10n/')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = pattern.firstMatch(lines[i]);
        if (match != null) {
          final literal = match.group(1)!.trim();
          // Ignore purely empty or punctuation-only separators.
          if (literal.isEmpty ||
              RegExp(r'^[\s·•,:/\-–—]+$').hasMatch(literal)) {
            continue;
          }
          violations.add('$normalizedPath:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Move user-visible Text literals into ARB files:\n${violations.join('\n')}',
    );
  });
}
