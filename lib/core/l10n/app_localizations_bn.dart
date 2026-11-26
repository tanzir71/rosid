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
}
