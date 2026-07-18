import 'dart:io';

import 'v2_preprocess_goldens.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.any((argument) => argument != '--check') ||
      arguments.where((argument) => argument == '--check').length > 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_v2_preprocess_goldens.dart [--check]',
    );
    exitCode = 64;
    return;
  }

  final manifest = buildV2AppPreprocessGoldenManifest();
  final digest = buildV2AppPreprocessGoldenDigestRecord(manifest);
  final manifestFile = File(v2AppPreprocessGoldenManifestPath);
  final digestFile = File(v2AppPreprocessGoldenDigestPath);

  if (arguments.contains('--check')) {
    if (!manifestFile.existsSync() || !digestFile.existsSync()) {
      stderr.writeln('V2 app preprocessing golden files are missing.');
      exitCode = 1;
      return;
    }
    if (manifestFile.readAsStringSync() != manifest ||
        digestFile.readAsStringSync() != digest) {
      stderr.writeln(
        'V2 app preprocessing goldens are stale; regenerate and review them.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln('V2 app preprocessing goldens match the tracked reference.');
    return;
  }

  await manifestFile.parent.create(recursive: true);
  await manifestFile.writeAsString(manifest, flush: true);
  await digestFile.writeAsString(digest, flush: true);
  stdout.writeln('Wrote $v2AppPreprocessGoldenManifestPath');
  stdout.writeln('Wrote $v2AppPreprocessGoldenDigestPath');
}
