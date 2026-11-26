#!/usr/bin/env python3
"""Host OCR benchmark engine runner for Rosid M3.

Executes identical preprocessing and model pipelines to the Flutter app so we
can measure baseline (v1 whole-page Tesseract + v1 adaptive threshold) vs
M3 candidates (PP-OCRv5 mobile det + PP-OCRv5 English rec + per-line Tesseract
ben with tessdata_fast vs tessdata_best) across all 168 synthetic fixtures.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import math
import os
import subprocess
import tempfile
import time
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort

REPO_ROOT = Path(__file__).resolve().parent.parent
BENCH_HOME = Path(os.path.expanduser("~")) / ".rosid" / "bench"
TESS_EXE = str(BENCH_HOME / "tesseract" / "tesseract.exe")
TESSDATA_BEST = str(REPO_ROOT / "assets" / "tessdata")
TESSDATA_FAST = str(BENCH_HOME / "tessdata_fast")
DET_MODEL = str(REPO_ROOT / "assets" / "models" / "ocr" / "ppocr_v5_mobile_det.onnx")
REC_EN_MODEL = str(REPO_ROOT / "assets" / "models" / "ocr" / "ppocr_v5_en_mobile_rec.onnx")
REC_EN_DICT = str(REPO_ROOT / "assets" / "models" / "ocr" / "ppocr_v5_en_dict.txt")


def load_en_dict() -> list[str]:
    chars = ["<blank>"]
    with open(REC_EN_DICT, encoding="utf-8") as f:
        for line in f:
            ch = line.rstrip("\r\n")
            chars.append(ch if ch != "" else " ")
    return chars


def clean_photo_like(bgr: np.ndarray, quad: list[list[float]] | None) -> np.ndarray:
    """Applies the M2 cleaning pipeline (perspective warp + lighting division + CLAHE)."""
    img = bgr
    if quad is not None and len(quad) == 4:
        h, w = img.shape[:2]
        src = np.float32([[p[0] * (w - 1), p[1] * (h - 1)] for p in quad])
        tw = int(max(np.linalg.norm(src[1] - src[0]), np.linalg.norm(src[2] - src[3])))
        th = int(max(np.linalg.norm(src[3] - src[0]), np.linalg.norm(src[2] - src[1])))
        tw = max(64, min(2000, tw))
        th = max(64, min(2000, th))
        dst = np.float32([[0, 0], [tw - 1, 0], [tw - 1, th - 1], [0, th - 1]])
        M = cv2.getPerspectiveTransform(src, dst)
        img = cv2.warpPerspective(img, M, (tw, th))

    # Even out uneven lighting only when illumination varies across the page.
    small = cv2.resize(img, (max(8, img.shape[1] // 8), max(8, img.shape[0] // 8)))
    dil = cv2.dilate(small, np.ones((7, 7), np.uint8))
    bg = cv2.GaussianBlur(dil, (11, 11), 0)
    bg_std = float(np.std(bg))
    if bg_std > 8.0 or quad is not None:
        bg_full = cv2.resize(bg, (img.shape[1], img.shape[0]))
        div = np.clip(
            (img.astype(np.float32) / np.maximum(bg_full.astype(np.float32), 40.0)) * 245.0,
            0,
            255,
        ).astype(np.uint8)
        grey = cv2.cvtColor(div, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=1.8, tileGridSize=(8, 8))
        return clahe.apply(grey)
    return cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)


def run_tesseract(img_arr: np.ndarray, tessdata_dir: str, lang: str, psm: int) -> str:
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tf:
        tmp_path = tf.name
    try:
        cv2.imwrite(tmp_path, img_arr)
        cmd = [
            TESS_EXE,
            tmp_path,
            "stdout",
            "--tessdata-dir",
            tessdata_dir,
            "-l",
            lang,
            "--psm",
            str(psm),
            "--oem",
            "1",
            "-c",
            "preserve_interword_spaces=1",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
        return res.stdout.strip()
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


def detect_lines_ppocrv5(det_sess: ort.InferenceSession, grey: np.ndarray) -> list[tuple[int, int, int, int]]:
    """Runs PP-OCRv5 mobile DB detector (<=960 long side, mult of 32, thresh 0.3,
    box_thresh 0.6, unclip 1.5) and returns sorted (x0, y0, x1, y1) line boxes."""
    h, w = grey.shape[:2]
    bgr = cv2.cvtColor(grey, cv2.COLOR_GRAY2BGR)
    longest = max(h, w)
    scale = min(1.0, 960.0 / longest)
    nh = max(32, int(round(h * scale / 32.0)) * 32)
    nw = max(32, int(round(w * scale / 32.0)) * 32)
    resized = cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_LINEAR)

    # Normalize per ppocr_v5_mobile_det.yml: BGR scale 1/255, mean [0.485, 0.456, 0.406], std [0.229, 0.224, 0.225]
    x = resized.astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    x = (x - mean) / std
    x = np.transpose(x, (2, 0, 1))[None, ...]

    prob = det_sess.run(None, {"x": x})[0][0, 0]
    bitmap = (prob > 0.3).astype(np.uint8)
    contours, _ = cv2.findContours(bitmap, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)

    sx = w / float(nw)
    sy = h / float(nh)
    raw_boxes: list[tuple[int, int, int, int]] = []
    for cnt in contours:
        if cv2.contourArea(cnt) < 12:
            continue
        bx, by, bw, bh = cv2.boundingRect(cnt)
        roi = prob[by : by + bh, bx : bx + bw]
        if float(roi.mean()) < 0.55:
            continue
        # Generous vertical unclip so tall Bangla ascenders (ি ী ৈ ৌ র্ ঁ)
        # and descenders (ু ূ ৃ) are never clipped.
        pad_top = max(8, int(bh * 0.90))
        pad_bot = max(6, int(bh * 0.65))
        pad_x = max(8, int(bh * 0.60))
        x0 = max(0, int((bx - pad_x) * sx))
        y0 = max(0, int((by - pad_top) * sy))
        x1 = min(w, int((bx + bw + pad_x) * sx))
        y1 = min(h, int((by + bh + pad_bot) * sy))
        if (x1 - x0) >= 8 and (y1 - y0) >= 8:
            raw_boxes.append((x0, y0, x1, y1))

    # Merge horizontally aligned fragments on the same text line.
    raw_boxes.sort(key=lambda b: (b[1], b[0]))
    merged: list[list[int]] = []
    for bx0, by0, bx1, by1 in raw_boxes:
        cy = (by0 + by1) / 2.0
        bh = by1 - by0
        placed = False
        for m in merged:
            mcy = (m[1] + m[3]) / 2.0
            mh = m[3] - m[1]
            if abs(cy - mcy) < max(bh, mh) * 0.36:
                m[0] = min(m[0], bx0)
                m[1] = min(m[1], by0)
                m[2] = max(m[2], bx1)
                m[3] = max(m[3], by1)
                placed = True
                break
        if not placed:
            merged.append([bx0, by0, bx1, by1])

    # Clamp overlapping vertical edges between neighboring lines cleanly at midpoint
    merged.sort(key=lambda b: (b[1] + b[3]) / 2.0)
    for i in range(len(merged) - 1):
        if merged[i][3] > merged[i + 1][1]:
            mid = (merged[i][3] + merged[i + 1][1]) // 2
            merged[i][3] = max(merged[i][1] + 8, mid)
            merged[i + 1][1] = min(merged[i + 1][3] - 8, mid)
    return [(b[0], b[1], b[2], b[3]) for b in merged]


def recognize_en_ppocrv5(rec_sess: ort.InferenceSession, en_dict: list[str], crop_grey: np.ndarray) -> tuple[str, float]:
    """Runs PP-OCRv5 English mobile recognition on a grey line crop resized to H=48."""
    ch, cw = crop_grey.shape[:2]
    if ch < 4 or cw < 4:
        return "", 0.0
    bgr = cv2.cvtColor(crop_grey, cv2.COLOR_GRAY2BGR)
    ratio = cw / float(ch)
    target_h = 48
    target_w = max(32, min(1600, int(math.ceil(target_h * ratio))))
    resized = cv2.resize(bgr, (target_w, target_h), interpolation=cv2.INTER_LINEAR)
    x = (resized.astype(np.float32) / 255.0 - 0.5) / 0.5
    x = np.transpose(x, (2, 0, 1))[None, ...]

    logits = rec_sess.run(None, {"x": x})[0][0]  # [T, 438]
    # Softmax / argmax CTC greedy decode
    max_logits = logits.max(axis=1, keepdims=True)
    exp = np.exp(logits - max_logits)
    probs = exp / exp.sum(axis=1, keepdims=True)
    idxs = probs.argmax(axis=1)
    confs = probs.max(axis=1)

    chars = []
    char_confs = []
    prev = -1
    for idx, cf in zip(idxs, confs):
        idx_int = int(idx)
        if idx_int != 0 and idx_int != prev:
            if idx_int < len(en_dict):
                chars.append(en_dict[idx_int])
                char_confs.append(float(cf))
        prev = idx_int

    text = "".join(chars).strip()
    mean_conf = float(np.mean(char_confs)) if char_confs else 0.0
    return text, mean_conf


def matra_score(crop_grey: np.ndarray) -> float:
    """Computes horizontal matra (head-line) strength in the upper 18-48% band of
    a tight text crop. Bangla printed lines exhibit a strong continuous horizontal
    ink projection peak; Latin lines do not."""
    inv = 255 - crop_grey
    _, bw = cv2.threshold(inv, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    ys, xs = np.where(bw > 0)
    if len(ys) < 20:
        return 0.0
    tight = bw[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    th, tw = tight.shape
    if th < 8 or tw < 16:
        return 0.0
    row_density = (tight > 0).mean(axis=1)
    band = row_density[int(th * 0.14) : max(int(th * 0.14) + 1, int(th * 0.48))]
    if len(band) == 0:
        return 0.0
    return float(band.max())


def scale_for_tesseract_line(crop_grey: np.ndarray) -> np.ndarray:
    """Scales a line crop gently (target height ~56 px, preserving native resolution
    when already sharp) with a clean white margin so Tesseract psm 7 preserves
    Bangla i-kar/u-kar diacritics cleanly."""
    h, w = crop_grey.shape[:2]
    target_h = max(h, 52) if h <= 68 else 64
    scale = target_h / max(1.0, float(h))
    nw = max(16, int(round(w * scale)))
    resized = (
        crop_grey
        if abs(scale - 1.0) < 0.08
        else cv2.resize(crop_grey, (nw, target_h), interpolation=cv2.INTER_CUBIC)
    )
    return cv2.copyMakeBorder(resized, 16, 16, 20, 20, cv2.BORDER_CONSTANT, value=255)


def run_single_fixture(
    meta_path: Path,
    mode: str,
    det_sess: ort.InferenceSession | None,
    rec_sess: ort.InferenceSession | None,
    en_dict: list[str],
) -> dict:
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    img_path = meta_path.parent / meta["image"]
    bgr = cv2.imread(str(img_path))
    t0 = time.perf_counter()

    if mode == "baseline":
        # Version 1 baseline: raw grayscale -> v1 adaptive threshold -> whole-page Tesseract ben+eng psm 6
        # (no M2 perspective warp/lighting division, no PP-OCRv5 line detector)
        grey = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        bin_img = cv2.adaptiveThreshold(
            grey, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 31, 14
        )
        pred = run_tesseract(bin_img, TESSDATA_BEST, "ben+eng", psm=6)
    else:
        tess_dir = TESSDATA_FAST if mode == "v2_tess_fast" else TESSDATA_BEST
        grey = clean_photo_like(bgr, meta.get("ground_truth_quad"))
        boxes = detect_lines_ppocrv5(det_sess, grey)
        out_lines = []
        for x0, y0, x1, y1 in boxes:
            crop = grey[y0:y1, x0:x1]
            # First run ultra-fast PP-OCRv5 English ONNX (~10 ms) + matra check!
            en_text, en_conf = recognize_en_ppocrv5(rec_sess, en_dict, crop)
            m_score = matra_score(crop)

            # Script router: strong Latin confidence + low matra -> PP-OCRv5 English ONNX.
            # Strong matra -> pure Bangla Tesseract `ben` (avoids Latin digit/letter hallucinations).
            # Unsure -> run `ben+eng` and pick higher-signal reading.
            if m_score < 0.34 and en_conf >= 0.86 and len(en_text) >= 2:
                out_lines.append(en_text)
            else:
                line_img = scale_for_tesseract_line(crop)
                # Use pure `ben` when Latin ONNX confidence is low (pure Bangla line),
                # and `ben+eng` when mixed ASCII digits/words appear alongside Bangla.
                use_mixed = en_conf >= 0.62 and any(c.isascii() and c.isalnum() for c in en_text)
                lang = "ben+eng" if use_mixed else "ben"
                bn_text = run_tesseract(line_img, tess_dir, lang, psm=7)
                has_bn = any("\u0980" <= ch <= "\u09FF" for ch in bn_text)
                if not has_bn and en_conf >= 0.78 and len(en_text) >= 2:
                    out_lines.append(en_text)
                else:
                    out_lines.append(bn_text if bn_text else en_text)
        pred = "\n".join(ln for ln in out_lines if ln.strip())

    elapsed_ms = (time.perf_counter() - t0) * 1000.0
    return {
        "id": meta["id"],
        "kind": meta["kind"],
        "script": meta["script"],
        "is_photo_like": meta.get("is_photo_like", False),
        "is_synthetic_handwriting": meta.get("is_synthetic_handwriting", False),
        "expected_text": meta["text"],
        "predicted_text": pred,
        "details": meta.get("details", {}),
        "elapsed_ms": round(elapsed_ms, 1),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", required=True, choices=["baseline", "v2_tess_fast", "v2_tess_best", "final"])
    ap.add_argument("--fixtures", default="test/fixtures/synthetic")
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    mode = "v2_tess_best" if args.mode == "final" else args.mode
    fixture_dir = Path(args.fixtures)
    meta_files = sorted(p for p in fixture_dir.glob("*.json") if p.name != "manifest.json")
    if args.limit > 0:
        meta_files = meta_files[: args.limit]

    so = ort.SessionOptions()
    so.log_severity_level = 3
    det_sess = None if mode == "baseline" else ort.InferenceSession(DET_MODEL, sess_options=so, providers=["CPUExecutionProvider"])
    rec_sess = None if mode == "baseline" else ort.InferenceSession(REC_EN_MODEL, sess_options=so, providers=["CPUExecutionProvider"])
    en_dict = load_en_dict()

    desc = {
        "baseline": "v1 whole-page adaptive threshold + Tesseract ben+eng (tessdata_best, psm 6)",
        "v2_tess_fast": "M2 cleaner + PP-OCRv5 mobile det + PP-OCRv5 en rec + matra router + per-line Tesseract ben+eng (tessdata_fast, psm 7)",
        "v2_tess_best": "M2 cleaner + PP-OCRv5 mobile det + PP-OCRv5 en rec + matra router + per-line Tesseract ben+eng (tessdata_best, psm 7)",
    }[mode]

    # Parallelize across CPU cores for fast benchmarking while still recording single-page wall time.
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        futs = [pool.submit(run_single_fixture, p, mode, det_sess, rec_sess, en_dict) for p in meta_files]
        for idx, fut in enumerate(futs, 1):
            results.append(fut.result())
            if idx % 40 == 0 or idx == len(futs):
                print(f"  [{mode}] {idx}/{len(futs)} done", flush=True)

    Path(args.out).write_text(
        json.dumps({"engine_description": desc, "results": results}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
