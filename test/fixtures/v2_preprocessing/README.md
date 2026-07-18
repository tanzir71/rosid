# V2 app preprocessing reference

`app_reference_v1.json` freezes exact raw pixel-plane hashes produced by the
current app preprocessing pipeline for three synthetic, privacy-safe fixtures.
The manifest uses NFC UTF-8, recursively sorted keys, two-space indentation,
and one terminal LF. The paired `.sha256` file commits those exact bytes.

Regenerate only after intentionally reviewing a preprocessing change:

```sh
dart run tool/generate_v2_preprocess_goldens.dart
dart run tool/generate_v2_preprocess_goldens.dart --check
flutter test test/ocr/preprocess/v2_preprocess_golden_test.dart
```

The normative planes are tightly packed, with rows top-to-bottom and pixels
left-to-right. Color bytes use R8,G8,B8,A8 channel order; grayscale uses the Y8
value copied to each RGB channel; binary Y8 is restricted to 0 or 255. Hashes
cover plane payload bytes only. Quads use normalized millionths stored as
integers and divided by 1,000,000 when reconstructed.

Per-channel minima/maxima and Y8 zero/full-scale counts make gross blank or
washed-out regeneration visible and support independent semantic assertions.
One English vector also freezes the shipped JPEG byte hashes solely as a V1
app-code regression marker; JPEG bytes are not part of cross-language parity.

This is the app-side reference half only. It does not prove Python parity,
model tensor preprocessing, line segmentation, runtime inference, or any
P2/P3/P4 gate. A future HTR engine must consume this pre-JPEG boundary or
extend the approved contract to cover its exact JPEG decode round trip. Until
an approved Python implementation independently recomputes matching bytes,
cross-language preprocessing remains unpassed.
