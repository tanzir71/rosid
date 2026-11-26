// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Rosid';

  @override
  String get appWordmarkBn => 'রসিদ';

  @override
  String get offlineTagline => 'Private scanning, entirely on your device';

  @override
  String get worksOfflineStamp => 'WORKS OFFLINE';

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
      'No account. No internet. Your papers stay on this phone.';

  @override
  String get welcomePurposeTitle => 'What do you need Rosid for?';

  @override
  String get welcomePurposeHelp =>
      'Pick any. This only sets your home shortcuts, and you can change it later.';

  @override
  String get purposeVisaTitle => 'Visa and abroad paperwork';

  @override
  String get purposeVisaSub =>
      'Translate papers to English and bundle them for an application';

  @override
  String get purposeLandTitle => 'Land and property papers';

  @override
  String get purposeLandSub => 'Deeds, khatian, mutation and land tax receipts';

  @override
  String get purposeReceiptsTitle => 'Receipts and spending';

  @override
  String get purposeReceiptsSub =>
      'Keep receipts and see what you spend each month';

  @override
  String get purposeStudyTitle => 'Study notes and handouts';

  @override
  String get purposeStudySub => 'Turn pages into text you can edit';

  @override
  String get purposeOfficeTitle => 'Office and shop paperwork';

  @override
  String get purposeOfficeSub => 'Invoices, licences and letters';

  @override
  String get purposeFamilyTitle => 'Family records';

  @override
  String get purposeFamilySub => 'IDs, certificates, prescriptions and bills';

  @override
  String get welcomeCameraTitle => 'Allow the camera to scan';

  @override
  String get welcomeCameraBody =>
      'Rosid uses the camera only while you scan. Pictures are kept inside the app, not in your gallery.';

  @override
  String get welcomeAssuranceOffline =>
      'Rosid has no internet permission, so it cannot upload anything.';

  @override
  String get welcomeAssuranceLock =>
      'Lock the app with your fingerprint or a PIN.';

  @override
  String get welcomeAssuranceBackup =>
      'Back up to a file you keep, such as a memory card or pen drive.';

  @override
  String get allowCamera => 'Allow camera';

  @override
  String get notNowImportPhotos => 'Not now, import photos instead';

  @override
  String get home => 'Home';

  @override
  String get library => 'Library';

  @override
  String get bundles => 'Bundles';

  @override
  String get expenses => 'Expenses';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get scan => 'Scan';

  @override
  String get whatAreYouScanning => 'What are you scanning?';

  @override
  String get idCard => 'ID card';

  @override
  String get translate => 'Translate';

  @override
  String get pickUpWhereYouLeftOff => 'Pick up where you left off';

  @override
  String get checkWords => 'Check words';

  @override
  String wordsToCheckCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words to check',
      one: '1 word to check',
    );
    return '$_temp0';
  }

  @override
  String get seeAll => 'See all';

  @override
  String get recent => 'Recent';

  @override
  String get noPapersYet => 'No papers yet';

  @override
  String get scanFirstPaperPrompt =>
      'Scan a document, ID card or receipt to keep it on this phone.';

  @override
  String get noBundlesYet => 'No bundles yet';

  @override
  String get startBundlePrompt =>
      'Collect papers against a checklist for a visa, land record or bank loan.';

  @override
  String get startFromChecklist => 'Start from a checklist';

  @override
  String bundleProgress(int ready, int total) {
    return '$ready of $total papers ready';
  }

  @override
  String get search => 'Search inside your papers';

  @override
  String get documents => 'Documents';

  @override
  String get ids => 'IDs';

  @override
  String get receipts => 'Receipts';

  @override
  String get land => 'Land';

  @override
  String get recentDocuments => 'Recent documents';

  @override
  String get pinnedDocuments => 'Pinned documents';

  @override
  String get noDocuments => 'No documents yet';

  @override
  String get scanFirstDocument =>
      'Scan your first document to make it searchable.';

  @override
  String get thisMonth => 'This month';

  @override
  String get spentThisMonth => 'Spent this month';

  @override
  String get recentReceipts => 'Recent receipts';

  @override
  String get noReceipts => 'No receipts yet';

  @override
  String get noReceiptsThisMonth =>
      'No receipts this month. Scan a receipt to see your spending by category.';

  @override
  String get expenseTracking => 'Track spending from receipts';

  @override
  String get expenseTrackingDescription =>
      'Show receipt scanning, month view, categories, and CSV export.';

  @override
  String get receipt => 'Receipt';

  @override
  String get document => 'Document';

  @override
  String get landRecord => 'Land record';

  @override
  String get certificate => 'Certificate';

  @override
  String get capture => 'Capture';

  @override
  String get gallery => 'Gallery';

  @override
  String get importPhotos => 'Import';

  @override
  String get flash => 'Flash';

  @override
  String get done => 'Done';

  @override
  String get retake => 'Retake';

  @override
  String get cropEnhance => 'Adjust page';

  @override
  String get original => 'Original';

  @override
  String get enhanced => 'Auto';

  @override
  String get grey => 'Grey';

  @override
  String get blackAndWhite => 'Black and white';

  @override
  String get rotate => 'Rotate';

  @override
  String get continueLabel => 'Continue';

  @override
  String get reviewReceipt => 'Check receipt';

  @override
  String get reviewDocument => 'Review document';

  @override
  String get merchant => 'Shop';

  @override
  String get purchaseDate => 'Date';

  @override
  String get total => 'Total';

  @override
  String get tax => 'VAT';

  @override
  String get paymentMethod => 'Paid with';

  @override
  String get category => 'Category';

  @override
  String get lineItems => 'Items';

  @override
  String get notes => 'Notes';

  @override
  String get title => 'Title';

  @override
  String get body => 'Text';

  @override
  String get englishTab => 'English';

  @override
  String get scanTab => 'Scan';

  @override
  String get tags => 'Tags';

  @override
  String get rawOcrText => 'Raw OCR text';

  @override
  String get verifyLowConfidence => 'Please verify the highlighted fields.';

  @override
  String get verifyHandwriting =>
      'Part of this page is handwritten. Check uncertain words against the photo.';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved on this device';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get share => 'Share';

  @override
  String get export => 'Export';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get filter => 'Filter';

  @override
  String get all => 'All';

  @override
  String get language => 'App language';

  @override
  String get languageAndReading => 'Language and reading';

  @override
  String get whatYouUseRosidFor => 'What you use Rosid for';

  @override
  String get names => 'Names';

  @override
  String get namesEmpty => 'No saved names yet';

  @override
  String get wordChoices => 'Word choices';

  @override
  String get wordChoicesSub => 'How legal and land terms appear in English';

  @override
  String get safety => 'Safety';

  @override
  String get appLock => 'App lock';

  @override
  String get appLockSub => 'Fingerprint or PIN each time you open Rosid';

  @override
  String get backUpAndMove => 'Back up and move';

  @override
  String get backUpNeverSub => 'No backup yet. Keep a locked copy you control.';

  @override
  String get worksOffline => 'Works offline';

  @override
  String get worksOfflineSub =>
      'No internet permission. Check under Android settings, Apps, Rosid';

  @override
  String get currency => 'Currency';

  @override
  String get currencyTaka => '৳ Bangladeshi taka';

  @override
  String get thisPhone => 'This phone';

  @override
  String get storage => 'Storage';

  @override
  String get storageOnDevice => 'Stored privately on this phone';

  @override
  String get english => 'English';

  @override
  String get bangla => 'বাংলা';

  @override
  String get defaultCurrency => 'Currency';

  @override
  String get categories => 'Categories';

  @override
  String get deleteAllData => 'Delete everything';

  @override
  String get deleteAllDataDescription =>
      'Permanently removes every paper, image and bundle from this phone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmDelete => 'Delete everything';

  @override
  String get privacyTitle => 'Works offline';

  @override
  String get privacyDescription =>
      'No internet permission. Your papers stay on this phone.';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get versionUnavailable => 'Version unavailable';

  @override
  String get releasesAndUpdates => 'Releases and updates';

  @override
  String get cameraUnavailable =>
      'Camera is unavailable. Import a photo from your phone instead.';

  @override
  String get cameraPermission =>
      'Camera access is needed to scan. You can also import photos.';

  @override
  String get processing => 'Reading your paper on this phone…';

  @override
  String get addPage => 'Add page';

  @override
  String pagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
      zero: 'No pages',
    );
    return '$_temp0';
  }

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get noResults => 'No matching papers';

  @override
  String get currencyBdt => '৳ BDT';

  @override
  String get scanMode => 'Scan mode';

  @override
  String get languageHint => 'Text language';

  @override
  String get automatic => 'Automatic';

  @override
  String get mixedBanglaEnglish => 'Bangla + English';

  @override
  String get confidence => 'Confidence';

  @override
  String get monthlySpend => 'Spent this month';

  @override
  String get spendByCategory => 'Spending by category';

  @override
  String get untitledDocument => 'Untitled paper';

  @override
  String get documentTitleRequired => 'Enter a title for this paper.';

  @override
  String get receiptFieldsRequired => 'Enter the shop name, date and total.';

  @override
  String get validTotalAndTaxRequired =>
      'Enter valid non-negative total and VAT amounts.';

  @override
  String get validTaxRequired => 'Enter a valid VAT amount.';

  @override
  String get validLineItemRequired =>
      'Each item needs a name, quantity and amount.';

  @override
  String get quantity => 'Quantity';

  @override
  String get unitPrice => 'Unit price';

  @override
  String get lowOcrConfidence => 'Check this word';

  @override
  String get loadFailed => 'Could not open your saved papers. Try again.';

  @override
  String get saveFailed =>
      'Could not save your changes. Check free storage and try again.';

  @override
  String get processingFailed =>
      'Could not read this page. Try a clearer photo or adjust the corners.';

  @override
  String get captureFailed => 'Could not take or import the photo. Try again.';

  @override
  String get exportFailed =>
      'Could not create the file. Check free storage and try again.';

  @override
  String get deleteFailed =>
      'Could not delete the data. Close other screens and try again.';

  @override
  String get offline => 'Offline';

  @override
  String get scannedToday => 'scanned today';

  @override
  String get today => 'today';

  @override
  String get themeLabel => 'Appearance';

  @override
  String get themeSystem => 'Follow phone';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get englishDraftPending =>
      'English draft will appear here once generated for this paper.';

  @override
  String get bundleChecklistComing =>
      'Add papers from your library or scan new ones into this bundle.';

  @override
  String get backupPageTitle => 'Your papers live only on this phone';

  @override
  String get backupPageBody =>
      'Because Rosid never goes online, your papers are not copied to any server. Make a password-locked backup file whenever you want to keep a copy or move phones.';

  @override
  String get makeBackupFile => 'Make a backup file';

  @override
  String get restoreBackupFile => 'Bring papers from a backup file';

  @override
  String get checkWordsEmpty => 'No words need checking on this paper.';

  @override
  String get readingOnPhone => 'Reading your paper';

  @override
  String get happensOnPhone =>
      'This happens on your phone. Nothing is uploaded.';

  @override
  String get coverDetailTitle => 'Cover a detail';

  @override
  String get coverDetailHint => 'Drag over anything you want to hide.';

  @override
  String get scriptGlyphBn => 'অ';

  @override
  String get scriptGlyphEn => 'A';

  @override
  String get autoCapture => 'Auto capture';

  @override
  String get hintNoPaper => 'Place paper inside the frame';

  @override
  String get hintMoveCloser => 'Move closer';

  @override
  String get hintTooDark => 'Too dark. Add light or turn on flash';

  @override
  String get hintGlare => 'Too much glare. Tilt the paper slightly';

  @override
  String get hintHoldSteady => 'Hold steady';

  @override
  String get hintEdgesFound => 'Edges found. Hold steady';

  @override
  String donePages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return 'Done, $_temp0';
  }

  @override
  String get idFront => 'Front';

  @override
  String get idBack => 'Back';

  @override
  String get turnCardOver => 'Turn the card over';

  @override
  String get idBothSidesNote =>
      'Front and back will be placed together on one page, ready to print or send.';

  @override
  String pageOfTotal(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get holdAndDragReorder => 'Hold and drag to reorder';

  @override
  String get readText => 'Read text';

  @override
  String get stepPageCleaned => 'Page straightened and cleaned';

  @override
  String get stepTextFound => 'Bangla and English text found';

  @override
  String get stepReadingText => 'Reading the text';

  @override
  String stepLineProgress(int current, int total) {
    return 'Line $current of $total';
  }

  @override
  String get stepFindingDetails => 'Finding names, dates and numbers';

  @override
  String get handwritingNote =>
      'Part of this page is handwritten. Handwriting is harder to read, so check those words on the next screen.';
}
