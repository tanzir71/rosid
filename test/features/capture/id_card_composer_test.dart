import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:rosid/features/capture/id_card_composer.dart';

Uint8List _makeSyntheticCard({required bool isFront}) {
  final card = img.Image(width: 514, height: 324);
  img.fill(card, color: img.ColorRgb8(244, 243, 236));
  // Header strip
  img.fillRect(
    card,
    x1: 0,
    y1: 0,
    x2: 513,
    y2: 56,
    color: isFront ? img.ColorRgb8(27, 122, 80) : img.ColorRgb8(67, 51, 176),
  );
  if (isFront) {
    // Portrait photo placeholder on left
    img.fillRect(
      card,
      x1: 28,
      y1: 84,
      x2: 148,
      y2: 240,
      color: img.ColorRgb8(188, 190, 182),
    );
    // Synthetic text bars on right
    for (var row = 0; row < 4; row++) {
      img.fillRect(
        card,
        x1: 176,
        y1: 96 + row * 36,
        x2: 460 - row * 30,
        y2: 112 + row * 36,
        color: img.ColorRgb8(42, 43, 51),
      );
    }
  } else {
    // Back side barcode / address bars
    for (var row = 0; row < 3; row++) {
      img.fillRect(
        card,
        x1: 36,
        y1: 88 + row * 32,
        x2: 440 - row * 40,
        y2: 104 + row * 32,
        color: img.ColorRgb8(64, 66, 78),
      );
    }
    for (var x = 36; x < 476; x += 10) {
      img.fillRect(
        card,
        x1: x,
        y1: 210,
        x2: x + (x % 20 == 0 ? 5 : 3),
        y2: 290,
        color: img.ColorRgb8(26, 27, 46),
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(card, quality: 95));
}

void main() {
  test('composes front and back onto A4 at true ISO ID-1 dimensions', () {
    final front = _makeSyntheticCard(isFront: true);
    final back = _makeSyntheticCard(isFront: false);

    final a4Bytes = const IdCardComposer().composeA4Jpeg(
      frontBytes: front,
      backBytes: back,
      dpi: 200,
    );
    final decoded = img.decodeImage(a4Bytes);
    expect(decoded, isNotNull);
    // A4 at 200 DPI: 210/25.4*200 = 1654, 297/25.4*200 = 2339
    expect(decoded!.width, closeTo(1654, 2));
    expect(decoded.height, closeTo(2339, 2));

    // Verify top card has green front header and bottom card has indigo back header
    final cardW = (85.6 / 25.4 * 200).round();
    final cardH = (54.0 / 25.4 * 200).round();
    final x = (decoded.width - cardW) ~/ 2 + 40;
    final topY = (decoded.height * 0.16).round() + 12;
    final gap = (24.0 / 25.4 * 200).round();
    final botY = (decoded.height * 0.16).round() + cardH + gap + 12;

    final topPixel = decoded.getPixel(x, topY);
    expect(topPixel.g, greaterThan(topPixel.r + 30));

    final botPixel = decoded.getPixel(x, botY);
    expect(botPixel.b, greaterThan(botPixel.g + 30));
  });

  testWidgets('golden of composed A4 ID card sheet (front + back)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 594);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final a4Bytes = const IdCardComposer().composeA4Jpeg(
      frontBytes: _makeSyntheticCard(isFront: true),
      backBytes: _makeSyntheticCard(isFront: false),
      dpi: 100,
    );

    final provider = MemoryImage(a4Bytes);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: Colors.white,
          child: Center(
            child: Image(image: provider, fit: BoxFit.contain),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Image));
      await precacheImage(provider, ctx);
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/m2_id_card_composed_a4.png'),
    );
  });
}
