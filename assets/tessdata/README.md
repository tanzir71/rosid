# Tesseract language data

Rosid bundles `eng.traineddata` and `ben.traineddata` so English and Bangla OCR
work offline on the first launch. Both files are pinned to `tessdata_best`
revision `e12c65a915945e4c28e237a9b52bc4a8f39a0cec`.

| File | Bytes | SHA-256 |
|---|---:|---|
| `eng.traineddata` | 15,400,601 | `8280AED0782FE27257A68EA10FE7EF324CA0F8D85BD2FD145D1C2B560BCB66BA` |
| `ben.traineddata` | 11,045,427 | `1CD0129288D1F74F6661C35E638E487BD146A66BB732ECD9E011E48DCB0DF623` |

The release workflow verifies these checked-in pinned files against the hashes
before building. It does not download or replace OCR language data.
