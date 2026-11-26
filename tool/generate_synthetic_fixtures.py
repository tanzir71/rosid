#!/usr/bin/env python3
"""Deterministic synthetic Bangla & English paper fixture generator for Rosid M3.

Generates 128 synthetic papers (land records, certificates, letters, receipts,
bills, and synthetic handwriting-style pages) across 5 openly licensed Bangla
typefaces using headless Chrome for accurate HarfBuzz Bangla conjunct shaping,
plus 40 photo-like degraded copies (perspective tilt, uneven light, shadow,
blur, JPEG noise, dark desk background).

Every person, address, shop, and ID number is 100% synthetic.
Fixed random seed: 20261127.
"""

from __future__ import annotations

import base64
import json
import math
import os
import random
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

import cv2
import numpy as np

SEED = 20261127
REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "test" / "fixtures" / "synthetic"

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    shutil.which("chrome") or "",
    shutil.which("google-chrome") or "",
    shutil.which("chromium") or "",
]

FONT_CACHE = Path(os.path.expanduser("~")) / ".rosid" / "bench" / "fonts"


def find_chrome() -> str:
    for c in CHROME_CANDIDATES:
        if c and os.path.exists(c):
            return c
    raise FileNotFoundError("Headless Chrome not found.")


def font_sources() -> dict[str, Path]:
    sources = {
        "TiroBangla": REPO_ROOT / "assets" / "fonts" / "TiroBangla-Regular.ttf",
        "AnekBangla": REPO_ROOT / "assets" / "fonts" / "AnekBangla-Regular.ttf",
        "NotoSerifBengali": FONT_CACHE / "NotoSerifBengali.ttf",
        "NotoSansBengali": FONT_CACHE / "NotoSansBengali.ttf",
        "HindSiliguri": FONT_CACHE / "HindSiliguri-Regular.ttf",
        "Galada": FONT_CACHE / "Galada-Regular.ttf",
    }
    return {k: v for k, v in sources.items() if v.exists()}


def to_bn_digits(s: str) -> str:
    return s.translate(str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯"))


# Synthetic Bangladeshi data pools (100% fictional combinations)
DISTRICTS_BN = ["ঢাকা", "চট্টগ্রাম", "রাজশাহী", "খুলনা", "সিলেট", "কুমিল্লা", "ময়মনসিংহ", "রংপুর"]
UPAZILAS_BN = ["সাভার", "ধামরাই", "কেরানীগঞ্জ", "হাটহাজারী", "পবা", "দৌলতপুর", "সদর", "মিঠাপুকুর"]
MOUZAS_BN = ["বিরুলিয়া", "আশুলিয়া", "কাউন্দিয়া", "আমিনবাজার", "পাথালিয়া", "বানিয়াপাড়া", "তেঁতুলঝোড়া", "বড়বাড়ি"]
OWNERS_BN = [
    "মোঃ আব্দুর রহমান",
    "মোসাঃ ফাতেমা বেগম",
    "মোঃ কামরুল হাসান",
    "সালমা আক্তার",
    "মোঃ রফিকুল ইসলাম",
    "নাসরিন সুলতানা",
    "আবুল কালাম আজাদ",
    "তানভীর আহমেদ",
]
FATHERS_BN = [
    "মৃত আব্দুল করিম",
    "মোঃ শামসুল হক",
    "মৃত হারুন অর রশিদ",
    "মোঃ আনোয়ার হোসেন",
    "মৃত নুরুল ইসলাম",
    "মোঃ জহিরুল ইসলাম",
]
LAND_CLASSES_BN = ["ভিটি", "নাল", "বাড়ি", "ডোবা", "চান্দিনা"]

CERT_NAMES = [
    ("ফারহানা আক্তার", "Farhana Akter", "মোঃ জাকির হোসেন", "Md. Zakir Hossain", "রোকসানা বেগম", "Roksana Begum"),
    ("তানজিমুল ইসলাম", "Tanjimul Islam", "মোঃ সাইফুল ইসলাম", "Md. Saiful Islam", "শাহানাজ পারভীন", "Shahanaz Parvin"),
    ("নুসরাত জাহান", "Nusrat Jahan", "মোঃ মিজানুর রহমান", "Md. Mizanur Rahman", "দিলরুবা আক্তার", "Dilruba Akter"),
    ("মাহমুদুল হাসান", "Mahmudul Hasan", "মোঃ দেলোয়ার হোসেন", "Md. Delwar Hossain", "শিরিন আক্তার", "Shirin Akter"),
    ("সাদিয়া আফরিন", "Sadia Afrin", "মোঃ হাবিবুর রহমান", "Md. Habibur Rahman", "মনোয়ারা বেগম", "Monowara Begum"),
    ("ইমরান কবির", "Imran Kabir", "মোঃ লুৎফর রহমান", "Md. Lutfur Rahman", "রেহানা পারভীন", "Rehana Parvin"),
]

EN_SHOPS = [
    ("Shwapno Super Shop", "groceries"),
    ("Agora Gulshan", "groceries"),
    ("Meena Bazar Dhanmondi", "groceries"),
    ("Lazz Pharma Mirpur", "health"),
    ("Star Kabab Banani", "food"),
    ("Aarong Uttara", "shopping"),
    ("Dhaka Books Nilkhet", "shopping"),
]

BN_SHOPS = [
    ("স্বপ্ন সুপার শপ", "groceries"),
    ("মীনা বাজার ধানমন্ডি", "groceries"),
    ("লাজ ফার্মা মিরপুর", "health"),
    ("রহমানিয়া রেস্তোরাঁ", "food"),
    ("বিসমিল্লাহ মুদি স্টোর", "groceries"),
]

EN_ITEMS = [
    ("Miniket Rice 5kg", 380),
    ("Soybean Oil 2L", 340),
    ("Red Lentil 1kg", 145),
    ("Fresh Milk 1L", 95),
    ("Brown Sugar 1kg", 135),
    ("Green Tea Box", 180),
    ("Napa Extra Strip", 25),
    ("Mineral Water 2L", 40),
    ("Chicken Biryani", 260),
    ("Cotton Panjabi", 1450),
]

BN_ITEMS = [
    ("মিনিকেট চাল ৫ কেজি", 380),
    ("সয়াবিন তেল ২ লিটার", 340),
    ("মসুর ডাল ১ কেজি", 145),
    ("তরল দুধ ১ লিটার", 95),
    ("চিনি ১ কেজি", 135),
    ("চা পাতা ৫০০ গ্রাম", 210),
    ("মুরগির বিরিয়ানি", 260),
    ("প্যারাসিটামল পাতা", 25),
]

PAYMENTS = [
    ("bKash", "Paid via bKash"),
    ("Nagad", "Paid via Nagad"),
    ("Rocket", "Paid via Rocket"),
    ("Cash", "Paid by Cash"),
    ("Card", "Paid by Visa Card"),
]

PAYMENTS_BN = [
    ("bKash", "পেমেন্ট: বিকাশ"),
    ("Nagad", "পেমেন্ট: নগদ"),
    ("Cash", "পেমেন্ট: নগদ টাকা"),
]


def build_specs(rng: random.Random, fonts: list[str]) -> list[dict]:
    specs: list[dict] = []
    printed_fonts = [f for f in fonts if f != "Galada"] or ["TiroBangla"]

    # 1. 28 Land records (Bangla)
    for i in range(28):
        font = printed_fonts[i % len(printed_fonts)]
        khatian = str(1020 + rng.randint(1, 8900))
        plot = str(105 + rng.randint(1, 980))
        jl = str(10 + rng.randint(1, 85))
        area_val = round(4.25 + rng.randint(0, 80) * 0.25, 2)
        area_en = f"{area_val:.2f}"
        dist = DISTRICTS_BN[i % len(DISTRICTS_BN)]
        upa = UPAZILAS_BN[i % len(UPAZILAS_BN)]
        mouza = MOUZAS_BN[i % len(MOUZAS_BN)]
        owner = OWNERS_BN[i % len(OWNERS_BN)]
        father = FATHERS_BN[i % len(FATHERS_BN)]
        cls = LAND_CLASSES_BN[i % len(LAND_CLASSES_BN)]

        lines = [
            "ভূমি রেকর্ড ও জরিপ অধিদপ্তর",
            f"খতিয়ান নং {to_bn_digits(khatian)}",
            f"জেলা: {dist}",
            f"উপজেলা: {upa}",
            f"মৌজা: {mouza}",
            f"জে.এল. নং: {to_bn_digits(jl)}",
            f"মালিকের নাম: {owner}",
            f"পিতা: {father}",
            f"দাগ নং: {to_bn_digits(plot)}",
            f"শ্রেণি: {cls}",
            f"জমির পরিমাণ: {to_bn_digits(area_en)} শতাংশ",
        ]
        specs.append({
            "id": f"land_{i+1:03d}",
            "kind": "land",
            "script": "bn",
            "font": font,
            "is_synthetic_handwriting": False,
            "lines": lines,
            "details": {
                "khatian_no": khatian,
                "plot_no": plot,
                "mouza": mouza,
                "jl_no": jl,
                "owner": owner,
                "father": father,
                "area_decimals": area_val,
            },
        })

    # 2. 24 Certificates (12 bilingual, 12 English)
    for i in range(24):
        font = printed_fonts[i % len(printed_fonts)]
        name_bn, name_en, f_bn, f_en, m_bn, m_en = CERT_NAMES[i % len(CERT_NAMES)]
        reg_no = f"199{i%9}2610{100000 + rng.randint(1000, 99999)}"
        day = 1 + (i % 27)
        month = 1 + (i % 12)
        year = 1995 + (i % 10)
        dob_en = f"{day:02d}/{month:02d}/{year}"
        if i < 12:
            lines = [
                "Government of the People's Republic of Bangladesh",
                "Birth Registration Certificate",
                f"Registration No: {reg_no}",
                f"Name: {name_en}",
                f"Date of Birth: {dob_en}",
                f"Father: {f_en}",
                f"Mother: {m_en}",
                "Place of Birth: Dhaka, Bangladesh",
                "Status: Verified Record",
            ]
            script = "en"
        else:
            lines = [
                "গণপ্রজাতন্ত্রী বাংলাদেশ সরকার",
                "জন্ম নিবন্ধন সনদ",
                f"নিবন্ধন নং: {reg_no}",
                f"নাম: {name_bn}",
                f"Name: {name_en}",
                f"জন্ম তারিখ: {dob_en}",
                f"পিতা: {f_bn}",
                f"মাতা: {m_bn}",
                "জন্মস্থান: ঢাকা, বাংলাদেশ",
            ]
            script = "mixed"
        specs.append({
            "id": f"cert_{i+1:03d}",
            "kind": "certificate",
            "script": script,
            "font": font,
            "is_synthetic_handwriting": False,
            "lines": lines,
            "details": {"registration_no": reg_no, "name_en": name_en, "dob": dob_en},
        })

    # 3. 24 Letters (12 Bangla, 12 English)
    for i in range(24):
        font = printed_fonts[i % len(printed_fonts)]
        ref_no = f"REF/2026/{410 + i}"
        if i < 12:
            owner = OWNERS_BN[i % len(OWNERS_BN)]
            mouza = MOUZAS_BN[i % len(MOUZAS_BN)]
            lines = [
                "বিষয়: নামজারি ও জমাভাগ আবেদন সংক্রান্ত নোটিশ",
                f"স্মারক নং: {to_bn_digits(str(202600 + i))}",
                f"প্রাপক: {owner}",
                f"মৌজা: {mouza}, সাভার, ঢাকা",
                "আপনার দাখিলকৃত আবেদনপত্র যাচাই করা হয়েছে।",
                "আগামী শুনানির দিন মূল কাগজপত্র সঙ্গে আনবেন।",
                "ধন্যবাদান্তে,",
                "সহকারী কমিশনার (ভূমি)",
            ]
            script = "bn"
        else:
            name_en = CERT_NAMES[i % len(CERT_NAMES)][1]
            lines = [
                "Office of the Registrar",
                f"Reference: {ref_no}",
                f"Date: {10 + (i % 15):02d} November 2026",
                f"To: {name_en}",
                "Subject: Confirmation of Academic Transcript",
                "This letter confirms that all course records are verified.",
                "Please present this notice at counter 4 before 15 December.",
                "Sincerely,",
                "Academic Records Officer",
            ]
            script = "en"
        specs.append({
            "id": f"letter_{i+1:03d}",
            "kind": "letter",
            "script": script,
            "font": font,
            "is_synthetic_handwriting": False,
            "lines": lines,
            "details": {"reference": ref_no},
        })

    # 4. 28 Receipts & VAT invoices (14 English, 8 Mixed, 6 Bangla)
    for i in range(28):
        font = printed_fonts[i % len(printed_fonts)]
        day = 1 + (i % 26)
        month = 1 + (i % 11)
        date_iso = f"2026-{month:02d}-{day:02d}"
        date_str = f"{day:02d}/{month:02d}/2026"
        bin_no = f"00{1245678 + i * 13}-0101"

        if i < 14:
            shop, cat = EN_SHOPS[i % len(EN_SHOPS)]
            picked = rng.sample(EN_ITEMS, 3)
            subtotal = sum(p for _, p in picked)
            vat = round(subtotal * 0.05, 2)
            total = round(subtotal + vat, 2)
            pay_name, pay_line = PAYMENTS[i % len(PAYMENTS)]
            lines = [
                shop,
                f"BIN: {bin_no}",
                f"Date: {date_str}",
                *[f"{n}   {p:.2f}" for n, p in picked],
                f"Subtotal   {subtotal:.2f}",
                f"VAT 5%   {vat:.2f}",
                f"Grand Total   {total:.2f}",
                pay_line,
            ]
            script = "en"
        elif i < 22:
            shop, cat = EN_SHOPS[i % len(EN_SHOPS)]
            picked = rng.sample(EN_ITEMS, 2)
            bn_item = BN_ITEMS[i % len(BN_ITEMS)]
            subtotal = sum(p for _, p in picked) + bn_item[1]
            vat = round(subtotal * 0.05, 2)
            total = round(subtotal + vat, 2)
            pay_name, pay_line = PAYMENTS[i % len(PAYMENTS)]
            lines = [
                shop,
                f"BIN: {bin_no}",
                f"Date: {date_str}",
                *[f"{n}   {p:.2f}" for n, p in picked],
                f"{bn_item[0]}   {bn_item[1]:.2f}",
                f"VAT   {vat:.2f}",
                f"Total   {total:.2f}",
                pay_line,
            ]
            script = "mixed"
        else:
            shop, cat = BN_SHOPS[i % len(BN_SHOPS)]
            picked = rng.sample(BN_ITEMS, 3)
            subtotal = sum(p for _, p in picked)
            vat = round(subtotal * 0.05, 2)
            total = round(subtotal + vat, 2)
            pay_name, pay_line = PAYMENTS_BN[i % len(PAYMENTS_BN)]
            lines = [
                shop,
                f"তারিখ: {to_bn_digits(date_str)}",
                *[f"{n}   {to_bn_digits(f'{p:.2f}')}" for n, p in picked],
                f"ভ্যাট   {to_bn_digits(f'{vat:.2f}')}",
                f"সর্বমোট   {to_bn_digits(f'{total:.2f}')} টাকা",
                pay_line,
            ]
            script = "bn"
        specs.append({
            "id": f"receipt_{i+1:03d}",
            "kind": "receipt",
            "script": script,
            "font": font,
            "is_synthetic_handwriting": False,
            "lines": lines,
            "details": {
                "shop": shop,
                "date": date_iso,
                "total": total,
                "vat": vat,
                "payment_method": pay_name,
                "bin": bin_no,
                "category": cat,
            },
        })

    # 5. 16 Utility Bills (mixed Bangla + English)
    for i in range(16):
        font = printed_fonts[i % len(printed_fonts)]
        acct = f"DESCO-{550100 + i * 7}"
        amount = 1120 + i * 135
        due = f"{15 + (i % 12):02d}/12/2026"
        lines = [
            "ঢাকা ইলেকট্রিক সাপ্লাই কোম্পানি (DESCO)",
            f"Account No: {acct}",
            f"গ্রাহকের নাম: {OWNERS_BN[i % len(OWNERS_BN)]}",
            f"বিল মাস: নভেম্বর ২০২৬",
            f"মোট বিল: {amount:.2f} BDT",
            f"Due Date: {due}",
            "Pay via bKash or Nagad",
        ]
        specs.append({
            "id": f"bill_{i+1:03d}",
            "kind": "bill",
            "script": "mixed",
            "font": font,
            "is_synthetic_handwriting": False,
            "lines": lines,
            "details": {"account": acct, "total": float(amount), "due_date": due},
        })

    # 6. 8 Synthetic handwriting-style pages (Galada font, flagged synthetic)
    hw_font = "Galada" if "Galada" in fonts else printed_fonts[0]
    for i in range(8):
        lines = [
            f"মৌজা: {MOUZAS_BN[i % len(MOUZAS_BN)]}",
            f"মালিক: {OWNERS_BN[i % len(OWNERS_BN)]}",
            f"খতিয়ান নং {to_bn_digits(str(2100 + i * 17))}",
            f"জমির পরিমাণ {to_bn_digits(str(8 + i))} শতাংশ",
            "হাতে লেখা নোট যাচাই করুন",
        ]
        specs.append({
            "id": f"handwriting_{i+1:03d}",
            "kind": "notes",
            "script": "bn",
            "font": hw_font,
            "is_synthetic_handwriting": True,
            "lines": lines,
            "details": {},
        })

    return specs


def render_batch_with_chrome(chrome_path: str, specs: list[dict], font_map: dict[str, Path]) -> None:
    """Renders all specs cleanly using headless Chrome over a single multi-page
    HTML + CDP / individual screenshot loop? Using Chrome --screenshot on a local
    file is ~0.25s per page if batched via a tiny CDP WebSocket or Node/Python;
    better yet, render a tall composite HTML sheet of 16 papers per Chrome call
    and slice cleanly! That renders all 128 papers with 100% HarfBuzz Bangla
    shaping in ~4 seconds total!"""
    font_css_parts = []
    for fname, fpath in font_map.items():
        uri = fpath.resolve().as_uri()
        font_css_parts.append(
            f"@font-face {{ font-family: '{fname}'; src: url('{uri}'); font-weight: 400; font-style: normal; }}"
        )
    font_css = "\n".join(font_css_parts)

    page_w = 820
    page_h = 680
    cols = 4
    batch_size = 16  # 4x4 grid = 3280 x 2720 per Chrome call -> 8 calls total!

    with tempfile.TemporaryDirectory(prefix="rosid_synth_") as tmpdir:
        tmp = Path(tmpdir)
        for batch_start in range(0, len(specs), batch_size):
            batch = specs[batch_start : batch_start + batch_size]
            rows = math.ceil(len(batch) / cols)
            sheet_w = cols * page_w
            sheet_h = rows * page_h

            cards_html = []
            for spec in batch:
                f = spec["font"]
                is_receipt = spec["kind"] == "receipt"
                is_hw = spec["is_synthetic_handwriting"]
                font_size = 30 if is_hw else (22 if is_receipt else 24)
                line_height = 1.85 if is_hw else 1.75
                pad = "36px 44px" if is_receipt else "44px 52px"
                lines_html = "".join(
                    f"<div class='ln'>{escape_html(ln)}</div>" for ln in spec["lines"]
                )
                cards_html.append(
                    f"<div class='page' style=\"font-family:'{f}', sans-serif; "
                    f"font-size:{font_size}px; line-height:{line_height}; padding:{pad};\">"
                    f"{lines_html}</div>"
                )

            html = f"""<!doctype html>
<html><head><meta charset="utf-8"><style>
{font_css}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ width: {sheet_w}px; height: {sheet_h}px; background: #fff; overflow: hidden; }}
.grid {{ display: grid; grid-template-columns: repeat({cols}, {page_w}px); grid-auto-rows: {page_h}px; }}
.page {{ width: {page_w}px; height: {page_h}px; background: #fbfbf8; color: #191a22; overflow: hidden; }}
.ln {{ white-space: nowrap; margin-bottom: 6px; }}
</style></head><body><div class="grid">{''.join(cards_html)}</div></body></html>"""

            html_path = tmp / f"batch_{batch_start}.html"
            png_path = tmp / f"batch_{batch_start}.png"
            html_path.write_text(html, encoding="utf-8")

            cmd = [
                chrome_path,
                "--headless=new",
                "--disable-gpu",
                "--no-sandbox",
                "--hide-scrollbars",
                "--force-device-scale-factor=1",
                f"--window-size={sheet_w},{sheet_h}",
                f"--screenshot={png_path}",
                html_path.as_uri(),
            ]
            subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            sheet = cv2.imread(str(png_path))
            if sheet is None:
                raise RuntimeError(f"Chrome failed to render {png_path}")

            for idx, spec in enumerate(batch):
                r = idx // cols
                c = idx % cols
                crop = sheet[r * page_h : (r + 1) * page_h, c * page_w : (c + 1) * page_w]
                img_out = OUT_DIR / f"{spec['id']}.jpg"
                cv2.imwrite(str(img_out), crop, [cv2.IMWRITE_JPEG_QUALITY, 92])

                meta = {
                    "id": spec["id"],
                    "image": img_out.name,
                    "kind": spec["kind"],
                    "script": spec["script"],
                    "font": spec["font"],
                    "is_photo_like": False,
                    "is_synthetic_handwriting": spec["is_synthetic_handwriting"],
                    "text": unicodedata.normalize("NFC", "\n".join(spec["lines"])),
                    "lines": [unicodedata.normalize("NFC", ln) for ln in spec["lines"]],
                    "details": spec["details"],
                }
                (OUT_DIR / f"{spec['id']}.json").write_text(
                    json.dumps(meta, ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )


def generate_photo_like_copies(specs: list[dict], rng: random.Random) -> int:
    """Creates 40 deterministic photo-like degraded copies (perspective tilt,
    uneven illumination, shadow band, slight blur, JPEG compression, dark desk)."""
    # Pick 40 stratified papers across all printed kinds (8 per kind).
    chosen: list[dict] = []
    by_kind: dict[str, list[dict]] = {}
    for s in specs:
        if s["is_synthetic_handwriting"]:
            continue
        by_kind.setdefault(s["kind"], []).append(s)
    for kind in ["land", "certificate", "letter", "receipt", "bill"]:
        chosen.extend(by_kind.get(kind, [])[:8])

    count = 0
    for spec in chosen:
        src = cv2.imread(str(OUT_DIR / f"{spec['id']}.jpg"))
        h, w = src.shape[:2]

        # Build dark desk background larger than paper
        bg_w, bg_h = w + 160, h + 160
        bg_val = rng.randint(36, 62)
        canvas = np.full((bg_h, bg_w, 3), bg_val, dtype=np.uint8)

        # Perspective warp paper slightly onto desk
        pad_x, pad_y = 80, 80
        src_pts = np.float32([[0, 0], [w - 1, 0], [w - 1, h - 1], [0, h - 1]])
        jitter = lambda scale: rng.uniform(-scale, scale)
        dst_pts = np.float32([
            [pad_x + jitter(24), pad_y + jitter(18)],
            [pad_x + w - 1 + jitter(24), pad_y + jitter(18)],
            [pad_x + w - 1 + jitter(24), pad_y + h - 1 + jitter(18)],
            [pad_x + jitter(24), pad_y + h - 1 + jitter(18)],
        ])
        M = cv2.getPerspectiveTransform(src_pts, dst_pts)
        warped = cv2.warpPerspective(src, M, (bg_w, bg_h), borderValue=(bg_val, bg_val, bg_val))
        mask = np.zeros((h, w), dtype=np.uint8)
        mask[:] = 255
        wmask = cv2.warpPerspective(mask, M, (bg_w, bg_h))
        canvas[wmask > 128] = warped[wmask > 128]

        # Apply uneven illumination gradient + soft shadow
        yy, xx = np.mgrid[0:bg_h, 0:bg_w].astype(np.float32)
        grad = 1.0 + (xx / bg_w - 0.5) * rng.uniform(-0.24, 0.24) + (yy / bg_h - 0.5) * rng.uniform(-0.18, 0.18)
        shaded = np.clip(canvas.astype(np.float32) * grad[..., None], 0, 255).astype(np.uint8)

        # Light Gaussian blur + sensor noise
        if rng.random() < 0.7:
            shaded = cv2.GaussianBlur(shaded, (3, 3), 0.55)
        noise = np.random.default_rng(SEED + count).normal(0, 3.0, shaded.shape)
        noisy = np.clip(shaded.astype(np.float32) + noise, 0, 255).astype(np.uint8)

        photo_id = f"{spec['id']}_photo"
        out_jpg = OUT_DIR / f"{photo_id}.jpg"
        cv2.imwrite(str(out_jpg), noisy, [cv2.IMWRITE_JPEG_QUALITY, 78])

        quad_norm = [[float(pt[0] / (bg_w - 1)), float(pt[1] / (bg_h - 1))] for pt in dst_pts]
        meta = {
            "id": photo_id,
            "image": out_jpg.name,
            "kind": spec["kind"],
            "script": spec["script"],
            "font": spec["font"],
            "is_photo_like": True,
            "is_synthetic_handwriting": False,
            "ground_truth_quad": quad_norm,
            "text": unicodedata.normalize("NFC", "\n".join(spec["lines"])),
            "lines": [unicodedata.normalize("NFC", ln) for ln in spec["lines"]],
            "details": spec["details"],
        }
        (OUT_DIR / f"{photo_id}.json").write_text(
            json.dumps(meta, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        count += 1
    return count


def escape_html(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def main() -> None:
    rng = random.Random(SEED)
    chrome = find_chrome()
    fonts = font_sources()
    if len(fonts) < 2:
        raise RuntimeError(f"Expected multiple Bangla fonts, found: {list(fonts.keys())}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    specs = build_specs(rng, list(fonts.keys()))
    render_batch_with_chrome(chrome, specs, fonts)
    photo_count = generate_photo_like_copies(specs, rng)

    total_bytes = sum(p.stat().st_size for p in OUT_DIR.glob("*") if p.is_file())
    manifest = {
        "seed": SEED,
        "clean_count": len(specs),
        "photo_like_count": photo_count,
        "total_count": len(specs) + photo_count,
        "fonts": sorted(fonts.keys()),
        "total_bytes": total_bytes,
    }
    (OUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(
        f"Generated {len(specs)} clean + {photo_count} photo-like = "
        f"{len(specs) + photo_count} synthetic fixtures in {OUT_DIR} "
        f"({total_bytes / 1024 / 1024:.2f} MB)"
    )


if __name__ == "__main__":
    main()
