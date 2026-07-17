# OCR image fixtures

These synthetic, privacy-safe images exercise document edge detection,
preprocessing, and the bundled `ben+eng` Tesseract engine. They contain no real
personal or merchant data.

- `english_receipt.png`: skewed English printed receipt.
- `mixed_bangla_receipt.png`: Bangla/English printed Dhaka-style receipt.
- `handwritten_bangla_note.png`: noisy document-mode handwriting sample.

The native harness is `integration_test/ocr_fixtures_test.dart`. Its generated,
compressed test-only bundle keeps these source images out of production apps.
Regenerate it after editing an image, then run on an Android device or emulator:

```sh
dart run tool/generate_ocr_fixture_bundle.dart
flutter test integration_test/ocr_fixtures_test.dart -d <device-id>
```

The images were generated with the built-in OpenAI image generator from
privacy-safe fixture prompts. Parser text fixtures remain under
`test/fixtures/receipts/`.
