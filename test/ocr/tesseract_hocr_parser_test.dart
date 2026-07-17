import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/ocr/engines/tesseract_hocr_parser.dart';

void main() {
  test('preserves hOCR geometry and character-weighted confidence', () {
    const hocr = '''
      <span class="ocr_line" title="bbox 10 20 190 50">
        <span class="ocrx_word" title="bbox 10 20 70 50; x_wconf 90">মোট</span>
        <span class="ocrx_word" title="bbox 85 21 190 49; x_wconf 80">৳১২৫</span>
      </span>
    ''';

    final blocks = TesseractHocrParser.parse(
      hocr,
      engineId: 'tesseract',
      pageIndex: 2,
      imageWidth: 200,
      imageHeight: 100,
    );

    expect(blocks, hasLength(1));
    expect(blocks.single.text, 'মোট ৳১২৫');
    expect(blocks.single.boundingBox.left, 10);
    expect(blocks.single.boundingBox.right, 190);
    expect(blocks.single.confidence, closeTo(0.84, 0.02));
    expect(blocks.single.pageIndex, 2);
  });

  test('separates words on different text lines', () {
    const hocr = '''
      <span class='ocrx_word' title='bbox 5 5 45 20; x_wconf 92'>First</span>
      <span class='ocrx_word' title='bbox 5 35 55 52; x_wconf 75'>Second</span>
    ''';

    final blocks = TesseractHocrParser.parse(
      hocr,
      engineId: 'tesseract',
      pageIndex: 0,
      imageWidth: 100,
      imageHeight: 80,
    );

    expect(blocks.map((block) => block.text), ['First', 'Second']);
    expect(blocks.last.confidence, 0.75);
  });

  test('returns an honest low-confidence fallback without word metadata', () {
    final blocks = TesseractHocrParser.parse(
      '<div class="ocr_page"><p>Unboxed &amp; text</p></div>',
      engineId: 'tesseract',
      pageIndex: 0,
      imageWidth: 100,
      imageHeight: 80,
    );

    expect(blocks.single.text, 'Unboxed & text');
    expect(blocks.single.confidence, 0.25);
  });
}
