# Rosid 2.0.0 (রসিদ ২.০.০)

## English

### What is new in 2.0.0
- **Scan any Bangla or English paper**: live edge detection, auto-capture when steady, manual corner adjustment with a magnifier, perspective straightening, lighting cleanup, and both-sides-on-one-page National ID capture.
- **Read and fix words**: on-device PP-OCRv5 + per-line Bangla reading with key details extraction (khatian, plot, owner, land area conversions in sq ft / katha / bigha / decimals), tap-a-line inspection, and word-by-word checking against a photo crop that remembers your corrections.
- **Offline English draft**: Mozilla Firefox Translations Bangla-to-English model + Bergamot WebAssembly running completely on device, with a personal Name Book (passport/NID spellings), legal/land term choices, Bangla calendar date conversion, and a clear `DRAFT` stamp on every screen and export.
- **Export and redaction**: PDF (with optional Translator's signature page, size limit, diagonal watermark, and destructive Cover a detail black-bar/blur redaction), editable Word (`.docx`), plain text (`.txt`), and JPG.
- **Library and bundles**: cross-script search across Bangla text, English drafts, and Name Book spellings; renewal dates; application checklists (Student visa, Visit visa, Land papers, Bank loan, Empty) exported as one numbered PDF with a Contents page or separate numbered files.
- **Expenses, app lock, and encrypted backup**: optional monthly receipt tracking with VAT, payment method, items-add-up verification, and CSV export; optional fingerprint + PIN app lock (`FLAG_SECURE` while locked); single-file Argon2id + AES-256-GCM encrypted backup and atomic restore.

### Privacy & requirements
- **No internet permission**: Rosid requests no `INTERNET` or `ACCESS_NETWORK_STATE` permission, has no accounts, no analytics, and no ads. Verify in Android Settings → Apps → Rosid → Permissions.
- **Android 8.0 (API 26) or newer** is required.
- **Android only for 2.0.0**: iPhone build requires a Mac with Xcode and is not included in this release.

### Which file to download
- **Most phones from the last eight years need `rosid-arm64-v8a.apk`** (99.75 MB).
- Older 32-bit Android phones should use `rosid-armeabi-v7a.apk` (88.53 MB).
- `symbols-2.0.0.zip` contains obfuscated debug symbols for decoding crash traces.

### Upgrading from Version 1
**If you installed version 1, uninstall it first.** Version 2.0.0 is signed with a new release key because the version 1 keystore was not present on the build machine.

### Checksums & signing certificate
- `rosid-arm64-v8a.apk` SHA-256: `4af5a9f041ebdf521013777030adffdcc9c5ea38ba65ed4c8d79daa9e77bd3b4`
- `rosid-armeabi-v7a.apk` SHA-256: `4371d02f47eb1d5c9ecabd9dac0c4b0a01d0e85bffd9e98f105b351528c76735`
- Signing certificate SHA-256: `1B:83:A5:29:55:86:4B:A1:C9:8D:1B:52:36:C2:96:72:57:B3:63:41:3F:40:74:BA:C7:35:68:95:FB:9D:FE:47`

### Not verified by machine
This release was verified automatically on a headless Android 15 emulator (281 unit/widget/golden tests, all 11 end-to-end flows, 5,000-event monkey stress test, 16 KB ELF alignment, DEX package audit, and manifest checks). The following require physical hardware and were not exercised on this machine:
- Installing from a mobile browser download on a physical Android phone.
- Real camera lens, autofocus, and real paper under real lighting.
- Real physical fingerprint sensor hardware (PIN path tested end to end; fingerprint path tested with a fake authenticator).
- External Android system file picker (SAF), third-party share apps, physical printing, and an offline Bangla text-to-speech voice pack.

---

## বাংলা

### ২.০.০ সংস্করণে যা নতুন
- **যেকোনো বাংলা বা ইংরেজি কাগজ স্ক্যান**: ক্যামেরায় কাগজের কিনারা চেনা, স্থির হলে নিজেই ছবি তোলা, ম্যাগনিফায়ারসহ কোণা ঠিক করা, আলো পরিষ্কার করা, এবং জাতীয় পরিচয়পত্রের দুই পিঠ এক পাতায় সাজানো।
- **লেখা পড়া ও শব্দ মিলিয়ে ঠিক করা**: অফলাইন PP-OCRv5 ও বাংলা লাইন রিডিং, খতিয়ান/দাগ/মালিক/জমির মাপ (শতাংশ, কাঠা, বিঘা, বর্গফুট) বের করা, লাইনে ট্যাপ করে মূল ছবি দেখা, এবং সন্দেহজনক শব্দ ঠিক করা যা রসিদ মনে রাখে।
- **অফলাইন ইংরেজি খসড়া**: ফোনের ভেতরেই Mozilla Firefox Translations বাংলা-থেকে-ইংরেজি মডেল, নামের তালিকা (পাসপোর্ট/এনআইডি বানান), আইনি ও জমির শব্দের ধরন পছন্দ, বাংলা তারিখ রূপান্তর, এবং প্রতিটি খসড়ায় স্পষ্ট `DRAFT` সিল।
- **এক্সপোর্ট ও ব্যক্তিগত তথ্য ঢাকা**: PDF (অনুবাদকের স্বাক্ষরের পাতা, ফাইল সাইজ সীমা, জলছাপ, এবং কালো দাগ বা ঝাপসা করে তথ্য স্থায়ীভাবে মোছার সুবিধাসহ), সম্পাদনাযোগ্য Word (`.docx`), টেক্সট (`.txt`), এবং JPG।
- **লাইব্রেরি ও ফাইল গুছানো**: বাংলা লেখা, ইংরেজি খসড়া ও নামের তালিকা জুড়ে দুই ভাষায় খোঁজা; নবায়নের তারিখ; ভিসা/জমি/ব্যাংক লোনের চেকলিস্ট ধরে সূচিপত্রসহ এক PDF বা আলাদা নম্বরযুক্ত ফাইলে এক্সপোর্ট।
- **খরচ, অ্যাপ লক ও এনক্রিপ্টেড ব্যাকআপ**: রসিদ থেকে মাসিক খরচের হিসাব ও CSV এক্সপোর্ট; ফিঙ্গারপ্রিন্ট ও পিন লক; পাসওয়ার্ড-সুরক্ষিত এক ফাইলে সম্পূর্ণ ব্যাকআপ ও পুনরুদ্ধার।

### গোপনীয়তা ও শর্তাবলি
- **ইন্টারনেট অনুমতি নেই**: রসিদ কোনো ইন্টারনেট বা নেটওয়ার্ক অনুমতি চায় না; কোনো অ্যাকাউন্ট, অ্যানালিটিক্স বা বিজ্ঞাপন নেই। অ্যান্ড্রয়েড সেটিংস → অ্যাপস → রসিদ → পারমিশন-এ নিজেই যাচাই করুন।
- **অ্যান্ড্রয়েড ৮.০ (API 26) বা নতুন** সংস্করণ প্রয়োজন।
- **২.০.০ শুধু অ্যান্ড্রয়েডের জন্য**।

### কোন ফাইলটি ডাউনলোড করবেন
- **গত আট বছরের বেশিরভাগ ফোনের জন্য `rosid-arm64-v8a.apk`** (৯৯.৭৫ MB) বেছে নিন।
- পুরোনো ৩২-বিট অ্যান্ড্রয়েড ফোনের জন্য `rosid-armeabi-v7a.apk` (৮৮.৫৩ MB) ব্যবহার করুন।

### সংস্করণ ১ থেকে আপগ্রেড
**সংস্করণ ১ ইনস্টল করা থাকলে আগে সেটি আনইনস্টল করুন।** এই সংস্করণের সাইনিং চাবি আলাদা।

### চেকসাম ও সাইনিং সার্টিফিকেট
- `rosid-arm64-v8a.apk` SHA-256: `4af5a9f041ebdf521013777030adffdcc9c5ea38ba65ed4c8d79daa9e77bd3b4`
- `rosid-armeabi-v7a.apk` SHA-256: `4371d02f47eb1d5c9ecabd9dac0c4b0a01d0e85bffd9e98f105b351528c76735`
- সাইনিং সার্টিফিকেট SHA-256: `1B:83:A5:29:55:86:4B:A1:C9:8D:1B:52:36:C2:96:72:57:B3:63:41:3F:40:74:BA:C7:35:68:95:FB:9D:FE:47`

### যা মেশিনে যাচাই করা যায়নি
এই রিলিজটি হেডলেস অ্যান্ড্রয়েড ১৫ এমুলেটরে স্বয়ংক্রিয়ভাবে যাচাই করা হয়েছে (২৮১টি টেস্ট, ১১টি এন্ড-টু-এন্ড ফ্লো, ৫,০০০-ইভেন্ট মাঙ্কি টেস্ট, ১৬ KB অ্যালাইনমেন্ট ও অফলাইন অডিট)। বাস্তব ফোনে ব্রাউজার থেকে ইনস্টল, আসল ক্যামেরা লেন্স ও আলো, আসল ফিঙ্গারপ্রিন্ট সেন্সর, সিস্টেম ফাইল পিকার/শেয়ার অ্যাপ, বাস্তব প্রিন্টার এবং অফলাইন বাংলা ভয়েস প্যাক বাস্তব যন্ত্র ছাড়া যাচাই করা সম্ভব হয়নি।
