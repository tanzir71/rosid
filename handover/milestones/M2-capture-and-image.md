# M2: Capture and image

Goal: scanning feels like a modern document scanner: live edges, auto capture, useful hints, ID card mode, a precise adjust screen, and clean page images.

Read first: `01-product.md` (Scan), `02-architecture.md` (Capturing, Cleaning the image), `design/screens.md` section 03.

## Steps

1. Add `opencv_dart`. Confirm it builds for arm64, armeabi-v7a and x86_64, adds no network permission, and its native libraries pass the 16 KB alignment check. Record the APK size change.
2. **Image isolate**: a long-lived isolate that receives small grey frames and returns corners and quality hints. Never block the UI thread; measure frame handling time.
3. **Edge detection** on frames, with smoothing. Draw the outline over the preview as in the design (accent outline, corner handles).
4. **Quality hints**: one at a time, in order of importance: no paper found, move closer, too dark, glare, hold steady.
5. **Auto capture** with the steadiness rule; a switch in the top bar; manual shutter always available.
6. **Multi-page tray** with count and "Done, n pages".
7. **Import** from the gallery through `image_picker`; imported pictures go through the same outline detection.
8. **ID card mode**: front, then the "Turn the card over" step, then back. Store `side` on each page. Compose both onto one A4 page at true card size (85.6 by 54 mm) for export.
9. **Adjust page**: corner and edge handles, magnifier under the finger, filters (Auto, Original, Grey, Black and white), rotate, delete, reorder by dragging thumbnails, add page, retake. Store the quad, rotation and filter per page; never overwrite the original photo.
10. **Clean image** pipeline in OpenCV as in `02`. Keep the original, a colour-corrected version and a grey version.
11. **Reading progress screen** shell (steps appear as M3 wires them).
12. Replace the pure-Dart heavy steps in `lib/ocr/preprocess/` with OpenCV calls; keep the old code only where tests prove it is still needed.
13. Fake capture source now drives the camera screen in tests: it plays a fixture "video" (a list of frames moving into place) so edge detection and auto capture can be tested.

## Done when (Level B)

- [ ] On the synthetic photo-like set, detected corners are within 2% of the frame diagonal of the ground truth for 90% or more of pictures with a visible paper. Measured by a host test.
- [ ] Edge detection on a frame takes 40 ms or less median on `rosid_test` (log timings in the isolate).
- [ ] Auto capture fires in the fake-camera test when the fixture paper is steady, and not while it moves.
- [ ] ID card flow produces one page with both sides; golden of the composed page.
- [ ] Adjust page: unit tests for quad editing, reorder, rotate; widget test for the magnifier.
- [ ] End-to-end flows 2 (capture part) and 3 (capture part) pass.
- [ ] Screens 03 match the design; comparisons in `evidence/M2/compare/`.
- [ ] STATUS updated, pushed.

## Fallbacks

- `opencv_dart` fails to build or breaks the size limit: keep edge detection on frames in pure Dart at 320 px (it is cheap there) and do the heavy cleaning steps in Kotlin through a method channel using Android's own bitmap APIs, or keep the current pure-Dart steps with a lower working resolution (2,000 px). Record which.
- Camera image stream format differs on the emulator: test edge logic on the host with fixture frames; mark live camera behaviour "not verified by machine".
