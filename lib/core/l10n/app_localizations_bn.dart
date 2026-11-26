// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'রসিদ';

  @override
  String get appWordmarkBn => 'রসিদ';

  @override
  String get offlineTagline => 'সম্পূর্ণ আপনার ফোনে ব্যক্তিগত স্ক্যানিং';

  @override
  String get worksOfflineStamp => 'অফলাইনে চলে';

  @override
  String get welcomeHeadlineBn =>
      'যেকোনো কাগজ স্ক্যান করুন, পড়ুন, ইংরেজিতে নিন';

  @override
  String get welcomeSublineEn =>
      'Scan any Bangla paper. Read it, fix it, and get it in English.';

  @override
  String get welcomeBanglaSubtitle => 'অ্যাপ বাংলায় ব্যবহার করুন';

  @override
  String get welcomeEnglishSubtitle => 'Use the app in English';

  @override
  String get welcomePrivacyLine =>
      'অ্যাকাউন্ট নেই। ইন্টারনেট নেই। আপনার কাগজ এই ফোনেই থাকে।';

  @override
  String get welcomePurposeTitle => 'রসিদ কী কাজে লাগবে?';

  @override
  String get welcomePurposeHelp =>
      'যেকোনোটি বেছে নিন। এতে শুধু হোমের শর্টকাট সাজানো হবে, পরে বদলাতে পারবেন।';

  @override
  String get purposeVisaTitle => 'ভিসা ও বিদেশের কাগজপত্র';

  @override
  String get purposeVisaSub =>
      'কাগজ ইংরেজিতে নিন এবং আবেদনের জন্য এক ফাইলে গুছিয়ে নিন';

  @override
  String get purposeLandTitle => 'জমি ও সম্পত্তির কাগজ';

  @override
  String get purposeLandSub => 'দলিল, খতিয়ান, নামজারি ও দাখিলা';

  @override
  String get purposeReceiptsTitle => 'রসিদ ও খরচের হিসাব';

  @override
  String get purposeReceiptsSub => 'রসিদ রাখুন এবং প্রতি মাসের খরচ দেখুন';

  @override
  String get purposeStudyTitle => 'পড়াশোনার নোট ও হ্যান্ডআউট';

  @override
  String get purposeStudySub => 'পাতা থেকে সম্পাদনাযোগ্য লেখা তৈরি করুন';

  @override
  String get purposeOfficeTitle => 'অফিস ও দোকানের কাগজপত্র';

  @override
  String get purposeOfficeSub => 'চালান, লাইসেন্স ও চিঠি';

  @override
  String get purposeFamilyTitle => 'পারিবারিক কাগজপত্র';

  @override
  String get purposeFamilySub => 'পরিচয়পত্র, সনদ, প্রেসক্রিপশন ও বিল';

  @override
  String get welcomeCameraTitle => 'স্ক্যান করতে ক্যামেরার অনুমতি দিন';

  @override
  String get welcomeCameraBody =>
      'শুধু স্ক্যান করার সময় রসিদ ক্যামেরা ব্যবহার করে। ছবি আপনার গ্যালারিতে নয়, অ্যাপের ভেতরেই থাকে।';

  @override
  String get welcomeAssuranceOffline =>
      'রসিদের ইন্টারনেট অনুমতি নেই, তাই কিছুই আপলোড করতে পারে না।';

  @override
  String get welcomeAssuranceLock =>
      'ফিঙ্গারপ্রিন্ট বা পিন দিয়ে অ্যাপ লক করে রাখুন।';

  @override
  String get welcomeAssuranceBackup =>
      'মেমোরি কার্ড বা পেনড্রাইভে নিরাপদ ব্যাকআপ ফাইল রাখুন।';

  @override
  String get allowCamera => 'ক্যামেরার অনুমতি দিন';

  @override
  String get notNowImportPhotos => 'এখন নয়, ফোনের ছবি আনুন';

  @override
  String get home => 'হোম';

  @override
  String get library => 'কাগজপত্র';

  @override
  String get bundles => 'ফাইল';

  @override
  String get expenses => 'খরচ';

  @override
  String get history => 'কাগজপত্র';

  @override
  String get settings => 'সেটিংস';

  @override
  String get scan => 'স্ক্যান';

  @override
  String get whatAreYouScanning => 'কী স্ক্যান করবেন?';

  @override
  String get idCard => 'পরিচয়পত্র';

  @override
  String get translate => 'অনুবাদ';

  @override
  String get pickUpWhereYouLeftOff => 'যেখানে থেমেছিলেন';

  @override
  String get checkWords => 'শব্দ দেখুন';

  @override
  String wordsToCheckCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি শব্দ দেখে নিন',
      one: '১টি শব্দ দেখে নিন',
    );
    return '$_temp0';
  }

  @override
  String get seeAll => 'সব দেখুন';

  @override
  String get recent => 'সাম্প্রতিক';

  @override
  String get noPapersYet => 'এখনও কোনো কাগজ নেই';

  @override
  String get scanFirstPaperPrompt =>
      'এই ফোনে রাখতে প্রথম কাগজ, পরিচয়পত্র বা রসিদ স্ক্যান করুন।';

  @override
  String get noBundlesYet => 'এখনও কোনো ফাইল নেই';

  @override
  String get startBundlePrompt =>
      'ভিসা, জমির কাগজ বা ব্যাংক ঋণের চেকলিস্ট ধরে কাগজ জমান।';

  @override
  String get startFromChecklist => 'চেকলিস্ট থেকে শুরু করুন';

  @override
  String bundleProgress(int ready, int total) {
    return '$totalটির মধ্যে $readyটি কাগজ তৈরি';
  }

  @override
  String get search => 'কাগজপত্রের ভেতরে খুঁজুন';

  @override
  String get documents => 'কাগজ';

  @override
  String get ids => 'পরিচয়পত্র';

  @override
  String get receipts => 'রসিদ';

  @override
  String get land => 'জমি';

  @override
  String get recentDocuments => 'সাম্প্রতিক কাগজ';

  @override
  String get pinnedDocuments => 'পিন করা কাগজ';

  @override
  String get noDocuments => 'এখনও কোনো কাগজ নেই';

  @override
  String get scanFirstDocument =>
      'খোঁজার সুবিধার জন্য প্রথম কাগজ স্ক্যান করুন।';

  @override
  String get thisMonth => 'এই মাস';

  @override
  String get spentThisMonth => 'এই মাসে খরচ';

  @override
  String get recentReceipts => 'সাম্প্রতিক রসিদ';

  @override
  String get noReceipts => 'এখনও কোনো রসিদ নেই';

  @override
  String get noReceiptsThisMonth =>
      'এই মাসে কোনো রসিদ নেই। বিভাগ অনুযায়ী খরচ দেখতে রসিদ স্ক্যান করুন।';

  @override
  String get expenseTracking => 'রসিদ থেকে খরচের হিসাব';

  @override
  String get expenseTrackingDescription =>
      'রসিদ স্ক্যান, মাসের হিসাব, বিভাগ ও CSV এক্সপোর্ট দেখান।';

  @override
  String get receipt => 'রসিদ';

  @override
  String get document => 'কাগজ';

  @override
  String get landRecord => 'জমির রেকর্ড';

  @override
  String get certificate => 'সনদ';

  @override
  String get capture => 'ছবি তুলুন';

  @override
  String get gallery => 'গ্যালারি';

  @override
  String get importPhotos => 'ছবি আনুন';

  @override
  String get flash => 'ফ্ল্যাশ';

  @override
  String get done => 'শেষ';

  @override
  String get retake => 'আবার তুলুন';

  @override
  String get cropEnhance => 'পাতা ঠিক করুন';

  @override
  String get original => 'আসল';

  @override
  String get enhanced => 'স্বয়ংক্রিয়';

  @override
  String get grey => 'ধূসর';

  @override
  String get blackAndWhite => 'সাদা-কালো';

  @override
  String get rotate => 'ঘোরান';

  @override
  String get continueLabel => 'এগিয়ে যান';

  @override
  String get reviewReceipt => 'রসিদ মিলিয়ে নিন';

  @override
  String get reviewDocument => 'কাগজ যাচাই';

  @override
  String get merchant => 'দোকান';

  @override
  String get purchaseDate => 'তারিখ';

  @override
  String get total => 'মোট';

  @override
  String get tax => 'ভ্যাট';

  @override
  String get paymentMethod => 'পরিশোধ';

  @override
  String get category => 'বিভাগ';

  @override
  String get lineItems => 'পণ্য';

  @override
  String get notes => 'নোট';

  @override
  String get title => 'শিরোনাম';

  @override
  String get body => 'লেখা';

  @override
  String get englishTab => 'ইংরেজি';

  @override
  String get scanTab => 'স্ক্যান';

  @override
  String get tags => 'ট্যাগ';

  @override
  String get rawOcrText => 'মূল OCR লেখা';

  @override
  String get verifyLowConfidence => 'চিহ্নিত তথ্যগুলো যাচাই করুন।';

  @override
  String get verifyHandwriting =>
      'এই পাতার কিছু অংশ হাতের লেখা। ছবির সঙ্গে মিলিয়ে শব্দগুলো ঠিক করুন।';

  @override
  String get save => 'সংরক্ষণ';

  @override
  String get saved => 'এই ফোনে সংরক্ষিত';

  @override
  String get edit => 'সম্পাদনা';

  @override
  String get delete => 'মুছুন';

  @override
  String get share => 'শেয়ার';

  @override
  String get export => 'এক্সপোর্ট';

  @override
  String get exportCsv => 'CSV এক্সপোর্ট';

  @override
  String get exportPdf => 'PDF এক্সপোর্ট';

  @override
  String get filter => 'ফিল্টার';

  @override
  String get all => 'সব';

  @override
  String get language => 'অ্যাপের ভাষা';

  @override
  String get languageAndReading => 'ভাষা ও পড়া';

  @override
  String get whatYouUseRosidFor => 'রসিদ কী কাজে ব্যবহার করেন';

  @override
  String get names => 'নামের তালিকা';

  @override
  String get namesEmpty => 'এখনও কোনো নাম যোগ করা হয়নি';

  @override
  String get wordChoices => 'শব্দের ব্যবহার';

  @override
  String get wordChoicesSub => 'আইনি ও জমির শব্দ ইংরেজিতে কীভাবে দেখাবে';

  @override
  String get safety => 'নিরাপত্তা';

  @override
  String get appLock => 'অ্যাপ লক';

  @override
  String get appLockSub => 'প্রতিবার রসিদ খোলার সময় ফিঙ্গারপ্রিন্ট বা পিন';

  @override
  String get backUpAndMove => 'ব্যাকআপ ও ফোন বদল';

  @override
  String get backUpNeverSub =>
      'এখনও ব্যাকআপ নেওয়া হয়নি। নিরাপদ কপি নিজের কাছে রাখুন।';

  @override
  String get worksOffline => 'অফলাইনে চলে';

  @override
  String get worksOfflineSub =>
      'ইন্টারনেট অনুমতি নেই। অ্যান্ড্রয়েড সেটিংস, অ্যাপস, রসিদে দেখে নিন';

  @override
  String get currency => 'মুদ্রা';

  @override
  String get currencyTaka => '৳ বাংলাদেশি টাকা';

  @override
  String get thisPhone => 'এই ফোন';

  @override
  String get storage => 'স্টোরেজ';

  @override
  String get storageOnDevice => 'এই ফোনে ব্যক্তিগতভাবে সংরক্ষিত';

  @override
  String get english => 'English';

  @override
  String get bangla => 'বাংলা';

  @override
  String get defaultCurrency => 'মুদ্রা';

  @override
  String get categories => 'বিভাগসমূহ';

  @override
  String get deleteAllData => 'সবকিছু মুছুন';

  @override
  String get deleteAllDataDescription =>
      'এই ফোন থেকে সব কাগজ, ছবি ও ফাইল স্থায়ীভাবে মুছে দেয়।';

  @override
  String get cancel => 'বাতিল';

  @override
  String get confirmDelete => 'সবকিছু মুছুন';

  @override
  String get privacyTitle => 'অফলাইনে চলে';

  @override
  String get privacyDescription =>
      'ইন্টারনেট অনুমতি নেই। আপনার কাগজ এই ফোনেই থাকে।';

  @override
  String get about => 'সম্পর্কে';

  @override
  String get version => 'সংস্করণ';

  @override
  String get versionUnavailable => 'সংস্করণ পাওয়া যায়নি';

  @override
  String get releasesAndUpdates => 'রিলিজ ও আপডেট';

  @override
  String get cameraUnavailable =>
      'ক্যামেরা পাওয়া যাচ্ছে না। ফোনের ছবি এনে স্ক্যান করুন।';

  @override
  String get cameraPermission =>
      'স্ক্যান করতে ক্যামেরার অনুমতি দরকার। চাইলে ফোনের ছবিও আনতে পারেন।';

  @override
  String get processing => 'এই ফোনেই কাগজ পড়া হচ্ছে…';

  @override
  String get addPage => 'পাতা যোগ করুন';

  @override
  String pagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count পৃষ্ঠা',
      one: '১ পৃষ্ঠা',
      zero: 'কোনো পৃষ্ঠা নেই',
    );
    return '$_temp0';
  }

  @override
  String get pin => 'পিন করুন';

  @override
  String get unpin => 'পিন সরান';

  @override
  String get noResults => 'কোনো কাগজ মেলেনি';

  @override
  String get currencyBdt => '৳ BDT';

  @override
  String get scanMode => 'স্ক্যানের ধরন';

  @override
  String get languageHint => 'লেখার ভাষা';

  @override
  String get automatic => 'স্বয়ংক্রিয়';

  @override
  String get mixedBanglaEnglish => 'বাংলা + English';

  @override
  String get confidence => 'নির্ভরযোগ্যতা';

  @override
  String get monthlySpend => 'এই মাসে খরচ';

  @override
  String get spendByCategory => 'বিভাগ অনুযায়ী খরচ';

  @override
  String get untitledDocument => 'শিরোনামহীন কাগজ';

  @override
  String get documentTitleRequired => 'এই কাগজের একটি শিরোনাম দিন।';

  @override
  String get receiptFieldsRequired => 'দোকানের নাম, তারিখ ও মোট পরিমাণ দিন।';

  @override
  String get validTotalAndTaxRequired => 'মোট ও ভ্যাটের সঠিক পরিমাণ লিখুন।';

  @override
  String get validTaxRequired => 'ভ্যাটের সঠিক পরিমাণ লিখুন।';

  @override
  String get validLineItemRequired => 'প্রতিটি পণ্যের নাম, পরিমাণ ও মূল্য দিন।';

  @override
  String get quantity => 'পরিমাণ';

  @override
  String get unitPrice => 'একক মূল্য';

  @override
  String get lowOcrConfidence => 'শব্দটি দেখে নিন';

  @override
  String get loadFailed => 'সংরক্ষিত কাগজ খোলা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get saveFailed =>
      'পরিবর্তন সংরক্ষণ করা যায়নি। ফোনের জায়গা দেখে আবার চেষ্টা করুন।';

  @override
  String get processingFailed =>
      'পাতাটি পড়া যায়নি। পরিষ্কার ছবি তুলুন বা কিনারা ঠিক করুন।';

  @override
  String get captureFailed => 'ছবি তোলা বা আনা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get exportFailed =>
      'ফাইল তৈরি করা যায়নি। ফোনের জায়গা দেখে আবার চেষ্টা করুন।';

  @override
  String get deleteFailed => 'তথ্য মুছা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get offline => 'অফলাইন';

  @override
  String get scannedToday => 'আজ স্ক্যান করা';

  @override
  String get today => 'আজ';

  @override
  String get themeLabel => 'থিম';

  @override
  String get themeSystem => 'ফোনের মতো';

  @override
  String get themeLight => 'হালকা';

  @override
  String get themeDark => 'গাঢ়';

  @override
  String get englishDraftPending =>
      'এই কাগজের ইংরেজি খসড়া তৈরি হলে এখানে দেখাবে।';

  @override
  String get bundleChecklistComing =>
      'এই ফাইলে কাগজপত্র থেকে যোগ করুন বা নতুন স্ক্যান করুন।';

  @override
  String get backupPageTitle => 'আপনার কাগজ শুধু এই ফোনেই থাকে';

  @override
  String get backupPageBody =>
      'রসিদ কখনো অনলাইনে যায় না, তাই আপনার কাগজ কোনো সার্ভারে জমা হয় না। কপি রাখতে বা ফোন বদলাতে পাসওয়ার্ড-লক করা ব্যাকআপ ফাইল তৈরি করুন।';

  @override
  String get makeBackupFile => 'ব্যাকআপ ফাইল তৈরি করুন';

  @override
  String get restoreBackupFile => 'ব্যাকআপ ফাইল থেকে কাগজ আনুন';

  @override
  String get checkWordsEmpty => 'এই কাগজে কোনো শব্দ দেখার বাকি নেই।';

  @override
  String get readingOnPhone => 'কাগজ পড়া হচ্ছে';

  @override
  String get happensOnPhone => 'সবকিছু আপনার ফোনেই হচ্ছে। কিছুই আপলোড হয় না।';

  @override
  String get coverDetailTitle => 'তথ্য ঢেকে দিন';

  @override
  String get coverDetailHint => 'যে অংশ লুকাতে চান তার ওপর টানুন।';

  @override
  String get scriptGlyphBn => 'অ';

  @override
  String get scriptGlyphEn => 'A';

  @override
  String get autoCapture => 'স্বয়ংক্রিয় ছবি';

  @override
  String get hintNoPaper => 'কাগজটি ফ্রেমের ভেতরে ধরুন';

  @override
  String get hintMoveCloser => 'আরেকটু কাছে আনুন';

  @override
  String get hintTooDark => 'আলো কম। ফ্ল্যাশ চালু করুন';

  @override
  String get hintGlare => 'আলো প্রতিফলিত হচ্ছে। কাগজ একটু কাত করুন';

  @override
  String get hintHoldSteady => 'স্থির হয়ে ধরুন';

  @override
  String get hintEdgesFound => 'কিনারা পাওয়া গেছে। স্থির ধরুন';

  @override
  String donePages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count পৃষ্ঠা',
      one: '১ পৃষ্ঠা',
    );
    return 'শেষ, $_temp0';
  }

  @override
  String get idFront => 'সামনের পিঠ';

  @override
  String get idBack => 'পেছনের পিঠ';

  @override
  String get turnCardOver => 'কার্ডটি উল্টে দিন';

  @override
  String get idBothSidesNote =>
      'সামনে ও পেছনের পিঠ এক পাতায় বসানো হবে, প্রিন্ট বা পাঠানোর জন্য তৈরি।';

  @override
  String pageOfTotal(int current, int total) {
    return 'পৃষ্ঠা $current / $total';
  }

  @override
  String get holdAndDragReorder => 'সাজাতে চেপে ধরে টানুন';

  @override
  String get readText => 'লেখা পড়ুন';

  @override
  String get stepPageCleaned => 'পাতা সোজা ও পরিষ্কার করা হয়েছে';

  @override
  String get stepTextFound => 'বাংলা ও ইংরেজি লেখা পাওয়া গেছে';

  @override
  String get stepReadingText => 'লেখা পড়া হচ্ছে';

  @override
  String stepLineProgress(int current, int total) {
    return 'লাইন $current / $total';
  }

  @override
  String get stepFindingDetails => 'নাম, তারিখ ও সংখ্যা খোঁজা হচ্ছে';

  @override
  String get handwritingNote =>
      'এই পাতার কিছু অংশ হাতের লেখা। হাতের লেখা পড়া কঠিন, তাই পরের পর্দায় শব্দগুলো মিলিয়ে নিন।';

  @override
  String wordsNeedALook(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি শব্দ দেখে নিন',
      one: '১টি শব্দ দেখে নিন',
    );
    return '$_temp0';
  }

  @override
  String get checkThem => 'মিলিয়ে নিন';

  @override
  String get keyDetails => 'মূল তথ্য';

  @override
  String get khatianNo => 'খতিয়ান নং';

  @override
  String get plotDagNo => 'দাগ নং';

  @override
  String get ownerLabel => 'মালিক';

  @override
  String get fatherLabel => 'পিতা';

  @override
  String get mouzaLabel => 'মৌজা';

  @override
  String get jlNoLabel => 'জে.এল. নং';

  @override
  String get areaLabel => 'জমির পরিমাণ';

  @override
  String wordProgress(int current, int total) {
    return 'শব্দ $current / $total';
  }

  @override
  String get fromYourScan => 'আপনার স্ক্যান থেকে';

  @override
  String get rosidReadThisAs => 'রসিদ এটি পড়েছে';

  @override
  String get pickAnotherReading => 'অথবা অন্য পাঠ বাছুন';

  @override
  String get rememberNamesNote =>
      'আপনি যে নাম ও স্থানের বানান ঠিক করেন, রসিদ তা মনে রাখে এবং পরের বার সঠিকভাবে পড়ে।';

  @override
  String get skip => 'এড়িয়ে যান';

  @override
  String get looksRight => 'ঠিক আছে';

  @override
  String get areaOfLand => 'জমির পরিমাণ';

  @override
  String get sameAreaOtherUnits => 'একই জমি অন্যান্য এককে';

  @override
  String get fixText => 'লেখা ঠিক করুন';

  @override
  String get copy => 'কপি';

  @override
  String get copied => 'কপি হয়েছে';

  @override
  String get listen => 'শুনুন';

  @override
  String get addToNamesBook => 'নামের খাতায়ও রাখুন';

  @override
  String get changePaperKind => 'কাগজের ধরন';

  @override
  String get paperKindDeed => 'দলিল';

  @override
  String get paperKindLicence => 'লাইসেন্স';

  @override
  String get paperKindBill => 'বিল';

  @override
  String get paperKindLetter => 'চিঠি';

  @override
  String get paperKindNotes => 'নোট';

  @override
  String get editFullText => 'লেখা সম্পাদনা';

  @override
  String get originalTextKept => 'মূল পাঠ আলাদাভাবে সংরক্ষিত থাকবে।';

  @override
  String get tapALineHint => 'যেকোনো লাইনে ট্যাপ করে লেখা দেখুন বা ঠিক করুন।';

  @override
  String get makeEnglishDraft => 'ইংরেজি খসড়া তৈরি করুন';

  @override
  String get draftStamp => 'খসড়া';

  @override
  String get englishDraftBanner =>
      'এই খসড়া আপনার ফোনেই তৈরি হয়েছে। ব্যবহারের আগে নাম ও সংখ্যা মিলিয়ে নিন।';

  @override
  String get spellingFromNameBook => 'আপনার নামের তালিকা থেকে বানান';

  @override
  String get newNameCheckSpelling => 'নতুন নাম। বানানটি মিলিয়ে নিন';

  @override
  String get terms => 'শব্দকোষ';

  @override
  String get howShouldTermAppear => 'ইংরেজিতে কীভাবে দেখাবে?';

  @override
  String get termBothDesc => 'বাংলা শব্দটি রাখে এবং একবার অর্থ ব্যাখ্যা করে';

  @override
  String get termEnglishOnlyDesc => 'শুধু সহজ ইংরেজি';

  @override
  String get termBanglaOnlyDesc => 'শুধু বাংলা শব্দ';

  @override
  String get termChoiceAppliesAll =>
      'আপনার পছন্দ প্রতিটি জমির কাগজের অনুবাদে ব্যবহৃত হবে।';

  @override
  String get useThis => 'এটি ব্যবহার করুন';

  @override
  String get namesIntro =>
      'এখানে ঠিক করা বানান সব অনুবাদে ব্যবহৃত হবে, যাতে আপনার কাগজ পাসপোর্টের সাথে মেলে।';

  @override
  String get people => 'ব্যক্তি';

  @override
  String get places => 'স্থান';

  @override
  String get asInPassport => 'পাসপোর্ট অনুযায়ী';

  @override
  String get asInNid => 'এনআইডি অনুযায়ী';

  @override
  String get suggestedCheck => 'প্রস্তাবিত, দেখে নিন';

  @override
  String get confirmedSpelling => 'নিশ্চিত';

  @override
  String get namesFooterNote =>
      'নতুন নাম দেখলে রসিদ প্রথমবার বানান প্রস্তাব করে। চূড়ান্ত বানান আপনি ঠিক করেন।';

  @override
  String get addName => 'নাম যোগ করুন';

  @override
  String get editName => 'নাম সম্পাদনা';

  @override
  String get banglaSpelling => 'বাংলা বানান';

  @override
  String get englishSpelling => 'ইংরেজি বানান';

  @override
  String get whereSpellingFrom => 'এই বানানের উৎস';

  @override
  String get makingEnglishDraft => 'আপনার ফোনেই ইংরেজি খসড়া তৈরি হচ্ছে…';

  @override
  String get editEnglishDraft => 'ইংরেজি খসড়া সম্পাদনা';

  @override
  String get editEnglishLineHint =>
      'বাংলা লাইন না বদলালে খসড়া আবার তৈরি করলেও আপনার পরিবর্তন থাকবে।';

  @override
  String get remakeDraft => 'খসড়া আবার তৈরি করুন';

  @override
  String get editedLabel => 'সম্পাদিত';

  @override
  String get whatGoesIn => 'কী কী থাকবে';

  @override
  String get englishDraftLabel => 'ইংরেজি খসড়া';

  @override
  String get banglaTextLabel => 'বাংলা লেখা';

  @override
  String get fileType => 'ফাইলের ধরন';

  @override
  String get fileTypePdf => 'PDF';

  @override
  String get fileTypePdfDesc => 'কাগজের মতো দেখতে। প্রিন্ট ও আপলোডের জন্য সেরা';

  @override
  String get fileTypeDocx => 'Word (.docx)';

  @override
  String get fileTypeDocxDesc => 'সম্পাদনা ও নতুন করে সাজানোর উপযোগী লেখা';

  @override
  String get fileTypeDocxFontNote =>
      'বাংলা লেখা দেখার জন্য Word-এ বাংলা ফন্ট থাকা দরকার।';

  @override
  String get fileTypeTxt => 'সাধারণ লেখা (.txt)';

  @override
  String get fileTypeTxtDesc => 'শুধু শব্দগুলো';

  @override
  String get fileTypeJpg => 'ছবি (.jpg)';

  @override
  String get fileTypeJpgDesc => 'প্রতিটি পাতার জন্য একটি ছবি';

  @override
  String get fileTypeCsv => 'স্প্রেডশিট (.csv)';

  @override
  String get fileTypeCsvDesc => 'রসিদের মোট, ভ্যাট ও পরিশোধের তথ্য';

  @override
  String get options => 'বিকল্পসমূহ';

  @override
  String get pageSize => 'পাতার মাপ';

  @override
  String get pageSizeA4 => 'A4';

  @override
  String get pageSizeLetter => 'Letter';

  @override
  String get pageSizeAsScanned => 'স্ক্যান অনুযায়ী';

  @override
  String get keepFileUnder => 'ফাইলের আকার সীমা';

  @override
  String get keepFileUnderSub => 'আপলোড ফর্মে সাধারণত সীমা থাকে';

  @override
  String get noSizeLimit => 'সীমা নেই';

  @override
  String sizeLimitMb(int mb) {
    return '$mb এমবি';
  }

  @override
  String get sizeLimitCannotFit =>
      'পড়ার যোগ্য মান রেখে এই সীমার ভেতর কাগজটি আঁটানো যায়নি।';

  @override
  String get watermark => 'জলছাপ';

  @override
  String get watermarkDefaultPurpose => 'শুধু ভিসা আবেদনের জন্য';

  @override
  String get watermarkPurposeHint => 'জলছাপের লেখা';

  @override
  String get translatorSignPage => 'অনুবাদকের স্বাক্ষরের পাতা';

  @override
  String get translatorSignPageSub => 'নাম, স্বাক্ষর, তারিখ ও সিল';

  @override
  String get preview => 'প্রিভিউ';

  @override
  String get saveToPhone => 'ফোনে সংরক্ষণ';

  @override
  String get print => 'প্রিন্ট';

  @override
  String get draftTranslationStamp => 'খসড়া অনুবাদ';

  @override
  String get draftTranslationFooter => 'বাংলা থেকে খসড়া অনুবাদ';

  @override
  String get toSignTab => 'স্বাক্ষর';

  @override
  String get nextGetCertified => 'এরপর সত্যায়ন করিয়ে নিন';

  @override
  String get nextGetCertifiedBody =>
      'একজন অনুবাদক বা নোটারি এই খসড়া যাচাই করে শেষ পাতায় স্বাক্ষর ও সিল দেবেন। বেশিরভাগ দূতাবাস ও অফিস কেবল সত্যায়িত অনুবাদ গ্রহণ করে।';

  @override
  String get idBothSidesTitle => 'জাতীয় পরিচয়পত্র, দুই পিঠ';

  @override
  String get coverDetailSub => 'পাঠানোর আগে নম্বর বা ঠিকানা ঢেকে দিন';

  @override
  String get blackAndWhiteCopy => 'সাদা-কালো কপি';

  @override
  String copyMadeOn(String date) {
    return 'কপি তৈরি $date';
  }

  @override
  String get savedStamp => 'সংরক্ষিত';

  @override
  String get savedToYourPhone => 'আপনার ফোনে সংরক্ষিত হয়েছে';

  @override
  String get shareSub => 'হোয়াটসঅ্যাপ, ইমেইল, ব্লুটুথ ও আরও অনেক কিছু';

  @override
  String get addToABundle => 'ফাইলে যোগ করুন';

  @override
  String get openTheFolder => 'ফোল্ডার খুলুন';

  @override
  String get coverToolBlackBar => 'কালো দাগ';

  @override
  String get coverToolBlur => 'ঝাপসা';

  @override
  String get undo => 'পূর্বাবস্থায়';

  @override
  String get coverDetailSafeNote =>
      'ঢাকা অংশটি এক্সপোর্ট করা কপি থেকে মুছে ফেলা হয়। আপনার মূল স্ক্যান অক্ষত থাকে।';

  @override
  String get translatorCertTitle => 'Translator\'s Certification';

  @override
  String get translatorCertBody =>
      'I certify that I am competent in Bangla and English, and that this is a true and accurate translation of the attached document.';

  @override
  String foundInPapers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি কাগজে পাওয়া গেছে',
      one: '১টি কাগজে পাওয়া গেছে',
    );
    return '$_temp0। নামের তালিকার নাম দুই ভাষাতেই খোঁজা হয়।';
  }

  @override
  String pageBanglaText(int page) {
    return 'পৃষ্ঠা $page, বাংলা লেখা';
  }

  @override
  String renewByDate(String date) {
    return 'নবায়ন $date-এর মধ্যে';
  }

  @override
  String get setRenewByDate => 'নবায়নের তারিখ দিন';

  @override
  String get clearRenewByDate => 'নবায়নের তারিখ মুছুন';

  @override
  String get bundlesIntro =>
      'এক কাজের সব কাগজ একসাথে গুছিয়ে রাখুন, তারপর এক ক্লিকে এক্সপোর্ট করুন।';

  @override
  String neededByDate(String date) {
    return '$date-এর মধ্যে দরকার';
  }

  @override
  String byDueDate(String date) {
    return '$date-এর মধ্যে';
  }

  @override
  String get setDueDate => 'শেষ তারিখ দিন';

  @override
  String itemIsMissing(String item) {
    return '$item এখনো নেই';
  }

  @override
  String bundleChecklistSummary(int ready, int needsWork, int missing) {
    return '$readyটি তৈরি, $needsWorkটিতে কাজ বাকি, $missingটি নেই';
  }

  @override
  String get checklistDisclaimer =>
      'আপনার আবেদনের জন্য অফিসিয়াল তালিকাটি মিলিয়ে নিন।';

  @override
  String get notScannedYet => 'এখনো স্ক্যান হয়নি';

  @override
  String scannedPagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count পৃষ্ঠা',
      one: '১ পৃষ্ঠা',
    );
    return 'স্ক্যান করা, $_temp0';
  }

  @override
  String get draftNeedsCertifying => 'ইংরেজি খসড়া সত্যায়িত করা বাকি';

  @override
  String wordsToCheckBeforeTranslating(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি শব্দ',
      one: '১টি শব্দ',
    );
    return 'অনুবাদের আগে $_temp0 দেখে নিন';
  }

  @override
  String get openAction => 'খুলুন';

  @override
  String get checkAction => 'দেখুন';

  @override
  String get addAction => 'যোগ করুন';

  @override
  String get exportBundle => 'ফাইল এক্সপোর্ট';

  @override
  String get linkExistingPaper => 'সংরক্ষিত কাগজ যুক্ত করুন';

  @override
  String get scanNewPaper => 'নতুন কাগজ স্ক্যান করুন';

  @override
  String get addChecklistItem => 'নতুন কাগজ যোগ করুন';

  @override
  String get itemNameHint => 'কাগজের নাম';

  @override
  String get bundleTitleHint => 'ফাইলের নাম';

  @override
  String get createBundle => 'ফাইল তৈরি করুন';

  @override
  String get howToPackIt => 'কীভাবে গুছিয়ে নেবেন';

  @override
  String get onePdfWithContents => 'সূচিপত্রসহ একটি PDF';

  @override
  String get onePdfWithContentsSub => 'তালিকার ক্রমে সব কাগজ, পৃষ্ঠা নম্বরসহ';

  @override
  String get separateFiles => 'আলাদা আলাদা ফাইল';

  @override
  String get separateFilesSub =>
      '01-Passport.pdf, 02-National-ID.pdf এভাবে নামকরণ';

  @override
  String get orderHeading => 'ক্রম';

  @override
  String readyPapersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি কাগজ তৈরি',
      one: '১টি কাগজ তৈরি',
    );
    return '$_temp0';
  }

  @override
  String bundleDraftWarning(String title) {
    return '$title-এর অনুবাদ এখনো খসড়া। সত্যায়িত কপি পেলে যুক্ত করুন।';
  }

  @override
  String get keepEachFileUnder => 'প্রতিটি ফাইলের আকার সীমা';

  @override
  String get watermarkEveryPage => 'প্রতিটি পাতায় জলছাপ';
}
