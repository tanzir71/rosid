# Landing page

The landing page is part of the deliverable. It is a static site in `docs/` on `main`, served by GitHub Pages at `https://tanzir71.github.io/rosid/`.

Design: Figma file "Rosid", page "Landing page". Frames `19:2100` (desktop, English, 1440 wide) and `19:2577` (mobile, বাংলা, 390 wide). Pictures: `design/landing/landing-desktop-en.png` and `design/landing/landing-mobile-bn.png`. Paper illustrations: `design/landing/papers/*.svg`.

## Pages and files

```
docs/
  .nojekyll
  index.html          বাংলা (default)
  en/index.html       English
  assets/
    site.css
    fonts/            anek-bangla-*.woff2, tiro-bangla-regular.woff2, jetbrains-mono-regular.woff2 (subset)
    papers/           the six SVGs from design/landing/papers/
    screens/          app screenshots, bn and en, WebP or PNG
    icons/            the few icons used, inline SVG preferred
  og-bn.png, og-en.png   1200 x 630
  favicon.svg, favicon.png
  404.html
```

## Hard rules

1. **No external requests on load.** No web fonts from Google, no CDN, no analytics, no trackers, no embeds. Fonts are self-hosted and subset. Check with a headless browser in `tool/verify` (see "Checks").
2. **Works without JavaScript.** Language switching is a plain link between `/rosid/` and `/rosid/en/`. Small enhancements in JavaScript are allowed, not required.
3. **Release values are written into the HTML** by a script at release time (see "Release values"). The page does not fetch them.
4. **Download links point to the real file.** Until 2.0.0 is published, they point to the version 1 release page. Never to a file that does not exist yet.
5. **Same rules as the app:** the copy below is final. No claims that are not true for the shipped build. If a feature was cut (for example free-text translation), remove or reword its line, on both pages.
6. **No italics** anywhere. Emphasis is by weight or colour only.
7. Use `lang="bn"` on the Bangla page and `lang="en"` on the English page; mark any phrase in the other script with its own `lang`.
8. Mobile first. Readable at 320 px wide. Keyboard focus visible. `prefers-reduced-motion` respected. Contrast at least 4.5:1 for text.

## Tokens

Use `design/tokens.json`, light values only (the site has no dark mode in 2.0). Key ones:

| Token | Value | Use |
|---|---|---|
| `bg/canvas` | `#F2F4EE` | Page background, odd sections |
| `bg/sheet` | `#FFFFFF` | Even sections (how it works, honest, install) |
| `bg/inverse` | `#1A1B2E` | Closing band |
| `ink/primary` | `#1A1B2E` | Text |
| `ink/secondary` | `#55586A` | Lead and body text |
| `ink/tertiary` | `#8A8D9C` | Small print |
| `accent/base` | `#4333B0` | Primary button, links, step numbers |
| `accent/soft` | `#E7E3FA` | Active language chip |
| `good/base` | `#1B7A50` | Check marks in the trust row |
| `warn/soft` | `#FBEBCB` | Highlighter behind a word |
| `paper/*` | `#FFFFFF`, `#2A2B33`, `#D4D6CE` | Paper illustrations |

Type (family, weight, size/line height in px):

| Style | Desktop | Mobile |
|---|---|---|
| Display (hero) | Anek Bangla SemiBold 64/76 | 38/50 |
| H2 | Anek Bangla SemiBold 40/52 | 28/38 |
| H3 | Anek Bangla SemiBold 22/32 | 22/32 |
| Lead | Anek Bangla Regular 20/32 | 17/28 (body) |
| Body | Anek Bangla Regular 17/28 | 17/28 |
| Small | Anek Bangla Regular 14/22 | 14/22 |
| Mono (file name, hashes) | JetBrains Mono Regular 13/20 | 13/20 |
| Paper text | Tiro Bangla Regular, title 19/28, body 15/24, small 11/17 | same |

Radii: paper 4, controls 12, pill 999. Buttons are 52 px high, 12 radius, 24 px side padding, icon 20 px with 8 px gap.

Layout: content width 1200 px with 120 px side margins on desktop; 20 px margins on mobile. Section padding 96 px top and bottom on desktop, 48 on mobile. Switch from mobile to desktop layout at 960 px. Between 600 and 960, use the mobile order with wider margins (40 px).

## Sections

The order is the same on both pages. Anchor ids are the same in both languages.

### 1. Header

Desktop: wordmark left (রসিদ in title-lg, then "Rosid" in title, ink/secondary), right: nav links (How it works → `#how`, Privacy → `#privacy`, Install → `#install`), the language pair (বাংলা and English as pills; the current language uses `accent/soft`, the other an outline), primary button "Download" with the download icon.
Mobile: wordmark and the language pair only.

### 2. Hero (`bg/canvas`)

Left column (584 px): headline, lead, two buttons (primary "Download for Android" with icon, ghost "How to install" → `#install`), a trust row of three items each with a green check icon, and a small line with the version.

Right column: **the paper pair**, built in HTML and CSS, not as a picture, so the text is real:

- A Bangla khatian sheet, rotated 4 degrees, 316 by 288, white, 4 radius, paper shadow. The word বিরুলিয়া has the highlighter behind it (`warn/soft`, 4 radius).
- Its English draft on top, offset right and down, rotated −3 degrees, with the DRAFT stamp in the bottom right (rotated −8 degrees, 2 px double border in `accent/base`, letter spacing 6%).
- Paper text in Tiro Bangla. Sheet content is below in "Copy".
- Mobile: the pair goes below the pitch, sheets stacked with the English one overlapping lower right.

### 3. How it works (`#how`, `bg/sheet`)

H2, then four steps. Each step: a phone frame (26 radius outer, 6 px bezel in `ink/primary`, 20 radius screen) holding a real app screenshot, then a number badge (accent circle) with the H3 title, then a small description.

| Step | Screenshot |
|---|---|
| 1 | Scan camera with edges found |
| 2 | Check words |
| 3 | English draft |
| 4 | Bundle checklist |

Use screenshots of the built app, from the M9 integration test run, in the page's language. Do not use the design pictures on the live site; they show what was planned, not what was built.

Desktop: four columns. Mobile: a horizontal row with scroll snap, each step 218 px wide, the next one partly visible.

### 4. Papers (`bg/canvas`)

Left: H2 and lead. Right: a three-column grid (two on mobile) of the six paper illustrations, each with a small caption. Use the SVGs from `design/landing/papers/` at their natural size; give them empty `alt` text because the caption says what they are.

### 5. Honest (`bg/sheet`)

H2, then two columns (stacked on mobile), each an H3 and a body paragraph.

### 6. Privacy (`#privacy`, `bg/canvas`)

Left: H2, lead, and a line with the shield icon. Right: the **release slip**, a white card with 4 radius and the paper shadow, four rows separated by `line/subtle`: Version, File (mono), File SHA-256 (mono, wraps), Signing certificate SHA-256 (mono, wraps). Values come from the release script.

### 7. Install (`#install`, `bg/sheet`)

H2, three numbered steps in a row (stacked on mobile), each with H3 and body, then the small note.

If the release is signed with a new key (see `04-repo-and-release.md`), add a fourth line before the note, in both languages: "If you installed version 1, uninstall it first. This version is signed differently." / "সংস্করণ ১ ইনস্টল করা থাকলে আগে সেটি আনইনস্টল করুন। এই সংস্করণের সই আলাদা।"

### 8. Closing (`bg/inverse`)

H2 in `ink/on-inverse`, tonal button "Download for Android", small version line.

### 9. Footer (`bg/canvas`)

Wordmark, then links: Source code (repository), All versions (releases page), Report a problem (new issue page).

## Copy

Final copy from the design. `{version}` and the other braces are filled by the release script.

| Place | English (`/en/`) | বাংলা (`/`) |
|---|---|---|
| Page title | Rosid: scan, read and translate Bangla papers, offline | রসিদ: বাংলা কাগজ স্ক্যান, পড়া ও অনুবাদ, অফলাইনে |
| Meta description | A free Android app that scans any Bangla or English paper, reads it, and makes an English draft. Works without the internet. | একটি ফ্রি অ্যান্ড্রয়েড অ্যাপ, যেকোনো বাংলা বা ইংরেজি কাগজ স্ক্যান করে পড়ে, ইংরেজি খসড়া বানায়। ইন্টারনেট ছাড়াই চলে। |
| Nav | How it works · Privacy · Install · Download | কীভাবে কাজ করে · গোপনীয়তা · ইনস্টল · ডাউনলোড |
| Hero headline | Any Bangla paper, scanned, read and in English. | যেকোনো বাংলা কাগজ স্ক্যান করুন, পড়ুন, ইংরেজিতে নিন। |
| Hero lead | Rosid is a free Android app that works without the internet. Your papers never leave your phone. | রসিদ একটি ফ্রি অ্যান্ড্রয়েড অ্যাপ। ইন্টারনেট ছাড়াই চলে, আপনার কাগজ ফোনের বাইরে যায় না। |
| Buttons | Download for Android · How to install | অ্যান্ড্রয়েডের জন্য ডাউনলোড · কীভাবে ইনস্টল করবেন |
| Trust row | No account · No internet permission · No ads | অ্যাকাউন্ট লাগে না · ইন্টারনেট অনুমতি নেই · বিজ্ঞাপন নেই |
| Version line | Version {version} for Android 8 or newer | সংস্করণ {version_bn}, অ্যান্ড্রয়েড ৮ বা নতুন |
| How it works H2 | From paper to a finished file | কাগজ থেকে তৈরি ফাইল |
| Step 1 | Scan. The camera finds the edges of the paper and takes the picture itself. | স্ক্যান করুন। ক্যামেরা নিজেই কাগজের কিনারা খুঁজে ছবি তোলে। |
| Step 2 | Check. Words Rosid was unsure of are marked. Fix them against the photo. | মিলিয়ে নিন। যে শব্দে রসিদের সন্দেহ, সেগুলো ছবির সঙ্গে মিলিয়ে ঠিক করুন। |
| Step 3 | Get an English draft. Names keep their passport spelling. Land units and Bangla dates are converted. | ইংরেজি খসড়া নিন। নামের বানান পাসপোর্টের মতো থাকে। জমির মাপ ও বাংলা তারিখ বদলে যায়। |
| Step 4 | Pack the file. Collect papers against a checklist, then export one PDF. | ফাইল গুছিয়ে নিন। চেকলিস্ট ধরে কাগজ জমান, তারপর এক পিডিএফে এক্সপোর্ট করুন। |
| Papers H2 | Made for the papers you actually have | আপনার হাতের কাগজগুলোর জন্যই |
| Papers lead | Old deeds, new certificates, shop receipts. If it is on paper, in Bangla or English, Rosid can keep it, read it and find it again. | পুরোনো দলিল, নতুন সনদ, দোকানের রসিদ। কাগজে থাকলে, বাংলা বা ইংরেজিতে হলে, রসিদ সেটি রাখতে, পড়তে আর খুঁজে দিতে পারে। |
| Paper captions | Deeds and khatian · Certificates · ID cards, both sides on one page · Receipts and bills · Licences and letters · Notes and handouts | দলিল ও খতিয়ান · সনদ · পরিচয়পত্র, দুই পিঠ এক পাতায় · রসিদ ও বিল · লাইসেন্স ও চিঠি · নোট ও হ্যান্ডআউট |
| Honest H2 | What Rosid will not pretend | যা রসিদ দাবি করে না |
| Honest 1 | A draft is not a certified translation. Embassies and offices usually want a translation signed by a translator or notary. Rosid gives them a clean draft to check and a page to sign. | খসড়া মানে সত্যায়িত অনুবাদ নয়। দূতাবাস ও অফিস সাধারণত অনুবাদক বা নোটারির সই করা অনুবাদ চায়। রসিদ তাঁদের জন্য একটি পরিষ্কার খসড়া আর সই করার পাতা তৈরি করে দেয়। |
| Honest 2 | Handwriting is hard to read. Printed Bangla reads well. With handwriting, Rosid marks every word it is unsure of, and you fix it against the photo. | হাতের লেখা পড়া কঠিন। ছাপা বাংলা ভালো পড়া যায়। হাতের লেখায় যেখানে সন্দেহ, রসিদ সেটি দাগিয়ে দেয়, আপনি ছবির সঙ্গে মিলিয়ে ঠিক করে নেন। |
| Privacy H2 | Private, and you can check | গোপন থাকে, নিজেই যাচাই করুন |
| Privacy lead | Rosid has no internet permission. It cannot upload a paper even if it tried. | রসিদের ইন্টারনেট ব্যবহারের অনুমতিই নেই। তাই চাইলেও কোনো কাগজ আপলোড করতে পারে না। |
| Privacy check line | Check it yourself in Android settings, under Apps, Rosid, Permissions. | নিজে দেখে নিন: অ্যান্ড্রয়েড সেটিংস, অ্যাপস, রসিদ, পারমিশন। |
| Slip labels | Version · File · File SHA-256 · Signing certificate SHA-256 | সংস্করণ · ফাইল · ফাইলের SHA-256 · সাইনিং সার্টিফিকেটের SHA-256 |
| Slip values | Rosid {version} · {apk_name} · {apk_sha256} · {cert_sha256} | রসিদ {version_bn} · {apk_name} · {apk_sha256} · {cert_sha256} |
| Install H2 | Install in three steps | তিন ধাপে ইনস্টল |
| Install 1 | Download the file. Tap the download button on this page. | ফাইলটি ডাউনলোড করুন। এই পাতার ডাউনলোড বোতামে চাপ দিন। |
| Install 2 | Allow the install. Android asks once to let your browser install apps. | ইনস্টলের অনুমতি দিন। অ্যান্ড্রয়েড একবারই জিজ্ঞেস করে, ব্রাউজার অ্যাপ ইনস্টল করতে পারবে কি না। |
| Install 3 | Open Rosid. Pick your language and scan your first paper. | রসিদ খুলুন। ভাষা বেছে নিন, তারপর প্রথম কাগজটি স্ক্যান করুন। |
| Install note | Rosid never goes online, so it cannot update itself. New versions appear on this page. | রসিদ অনলাইনে যায় না, তাই নিজে আপডেট হয় না। নতুন সংস্করণ এই পাতাতেই পাবেন। |
| Closing H2 | Scan your first paper | প্রথম কাগজটি স্ক্যান করুন |
| Footer | Source code · All versions · Report a problem | সোর্স কোড · সব সংস্করণ · সমস্যা জানান |
| Older phones | (small line under the download button) Older 32-bit phone? Get the other file. | (ডাউনলোড বোতামের নিচে ছোট লেখা) পুরোনো ৩২-বিট ফোন? অন্য ফাইলটি নিন। |

The "Older phones" line is new (not in Figma) because the release has two files. It links to the `armeabi-v7a` file. Keep it small, in `ink/tertiary`.

### Paper pair content

Bangla sheet: small heading "ভূমি রেকর্ড ও জরিপ অধিদপ্তর", title "খতিয়ান নং ১২৪৫", a rule, then rows: "জেলা: ঢাকা" and "উপজেলা: সাভার"; "মৌজা: বিরুলিয়া" (highlighted word) and "জে.এল. নং: ৩৫"; "মালিকের নাম: মোঃ আব্দুর রহমান"; "পিতা: মৃত আব্দুল করিম"; "দাগ নং: ৩০২" and "শ্রেণি: ভিটি"; "জমির পরিমাণ: ১২.৫০ শতাংশ".

English sheet: "Directorate of Land Records and Surveys", "Khatian No. 1245", rule, "District: Dhaka" and "Upazila: Savar"; "Mouza: Birulia" and "J.L. No. 35"; "Owner: MD ABDUR RAHMAN"; "Father: Late Abdul Karim"; "Plot (Dag) No. 302" and "Class: Homestead"; "Area: 12.50 decimals". Stamp: "DRAFT" (on the Bangla page: "খসড়া").

These are invented sample values. Give the pair `role="img"` with an `aria-label`: "A Bangla land record and its English draft" / "একটি বাংলা খতিয়ান ও তার ইংরেজি খসড়া".

## Release values

Rewrite `tool/prepare_site.py` (or replace it with `tool/prepare_site.dart`) so it:

- Reads the version, APK file names, SHA-256 values and certificate fingerprint from `SHA256SUMS.txt` and `apksigner` output.
- Writes them into `docs/index.html` and `docs/en/index.html` between marker comments such as `<!-- release:apk_sha256 -->…<!-- /release -->`.
- Converts the version to Bangla numerals for `{version_bn}`.
- Sets download links to `https://github.com/tanzir71/rosid/releases/download/v{version}/rosid-arm64-v8a.apk` (and the 32-bit file).
- Fails if any marker is left unfilled.

Before a 2.0.0 release exists, the slip shows: "written here when the release is built" / "রিলিজ তৈরির সময় এখানে বসবে", and download buttons go to `https://github.com/tanzir71/rosid/releases/tag/v1.0.0`, with the version line reading "Version 2 is on its way. Version 1.0.0 is available now." / "সংস্করণ ২ আসছে। এখন সংস্করণ ১.০.০ পাওয়া যাচ্ছে।"

## Open Graph

`og-en.png` and `og-bn.png`, 1200 by 630: the hero headline on `bg/canvas` beside the paper pair. Render them from the built page with headless Chromium at 1200 by 630. If no headless browser is available, crop from `design/landing/landing-desktop-en.png` for both and record it.

## Checks (in `tool/verify`)

1. HTML validates (use `html5validator` or the Nu checker jar locally if available; otherwise a parser check that tags balance).
2. Every local link and asset resolves (a small script over `docs/`).
3. No external request on load: serve `docs/` locally (`python -m http.server`), open both pages in headless Chromium with request interception, fail on any request to another host. If no headless browser is available, grep built HTML and CSS for `http://` and `https://` outside `<a href>` and fail on any.
4. Total page weight under 600 KB per language, excluding screenshots loaded lazily below the fold.
5. Lighthouse accessibility score of 95 or more if Lighthouse can run locally. Otherwise record "not run".
6. Screenshots of both pages at 390 and 1440 wide to `evidence/M9/site/`, next to the design pictures.
7. After pushing, `curl -s https://tanzir71.github.io/rosid/` and `/en/` return 200 and contain the version string.
