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
  String get noReceiptsThisMonth => 'No receipts this month';

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

  @override
  String wordsNeedALook(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words need a look',
      one: '1 word needs a look',
    );
    return '$_temp0';
  }

  @override
  String get checkThem => 'Check them';

  @override
  String get keyDetails => 'Key details';

  @override
  String get khatianNo => 'Khatian no.';

  @override
  String get plotDagNo => 'Plot (dag) no.';

  @override
  String get ownerLabel => 'Owner';

  @override
  String get fatherLabel => 'Father';

  @override
  String get mouzaLabel => 'Mouza';

  @override
  String get jlNoLabel => 'J.L. no.';

  @override
  String get areaLabel => 'Area';

  @override
  String wordProgress(int current, int total) {
    return 'Word $current of $total';
  }

  @override
  String get fromYourScan => 'From your scan';

  @override
  String get rosidReadThisAs => 'Rosid read this as';

  @override
  String get pickAnotherReading => 'Or pick another reading';

  @override
  String get rememberNamesNote =>
      'Rosid remembers names and places you correct, and reads them right next time.';

  @override
  String get skip => 'Skip';

  @override
  String get looksRight => 'Looks right';

  @override
  String get areaOfLand => 'Area of land';

  @override
  String get sameAreaOtherUnits => 'The same area in other units';

  @override
  String get fixText => 'Fix text';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get listen => 'Listen';

  @override
  String get addToNamesBook => 'Also save to Names book';

  @override
  String get changePaperKind => 'Kind of paper';

  @override
  String get paperKindDeed => 'Deed';

  @override
  String get paperKindLicence => 'Licence';

  @override
  String get paperKindBill => 'Bill';

  @override
  String get paperKindLetter => 'Letter';

  @override
  String get paperKindNotes => 'Notes';

  @override
  String get editFullText => 'Edit text';

  @override
  String get originalTextKept => 'Your original reading is kept safely.';

  @override
  String get tapALineHint =>
      'Tap any highlighted line on the scan to inspect or fix it.';

  @override
  String get makeEnglishDraft => 'Make an English draft';

  @override
  String get draftStamp => 'DRAFT';

  @override
  String get englishDraftBanner =>
      'This draft was made on your phone. Check names and numbers before you use it.';

  @override
  String get spellingFromNameBook => 'Spelling from your name book';

  @override
  String get newNameCheckSpelling => 'New name. Check the spelling';

  @override
  String get terms => 'Terms';

  @override
  String get howShouldTermAppear => 'How should it appear in English?';

  @override
  String get termBothDesc => 'Keeps the Bangla word and explains it once';

  @override
  String get termEnglishOnlyDesc => 'Plain English only';

  @override
  String get termBanglaOnlyDesc => 'Bangla word only';

  @override
  String get termChoiceAppliesAll =>
      'Your choice is used for every land paper you translate.';

  @override
  String get useThis => 'Use this';

  @override
  String get namesIntro =>
      'Spellings you set here are used in every translation, so your papers match your passport.';

  @override
  String get people => 'People';

  @override
  String get places => 'Places';

  @override
  String get asInPassport => 'As in passport';

  @override
  String get asInNid => 'As in NID';

  @override
  String get suggestedCheck => 'Suggested, check';

  @override
  String get confirmedSpelling => 'Confirmed';

  @override
  String get namesFooterNote =>
      'Rosid suggests a spelling the first time it sees a name. You decide the final one.';

  @override
  String get addName => 'Add name';

  @override
  String get editName => 'Edit name';

  @override
  String get banglaSpelling => 'Bangla spelling';

  @override
  String get englishSpelling => 'English spelling';

  @override
  String get whereSpellingFrom => 'Where this spelling comes from';

  @override
  String get makingEnglishDraft => 'Making English draft on this phone…';

  @override
  String get editEnglishDraft => 'Edit English draft';

  @override
  String get editEnglishLineHint =>
      'Your edits are kept even if you remake the draft, unless the Bangla line changes.';

  @override
  String get remakeDraft => 'Remake draft';

  @override
  String get editedLabel => 'Edited';

  @override
  String get whatGoesIn => 'What goes in';

  @override
  String get englishDraftLabel => 'English draft';

  @override
  String get banglaTextLabel => 'Bangla text';

  @override
  String get fileType => 'File type';

  @override
  String get fileTypePdf => 'PDF';

  @override
  String get fileTypePdfDesc =>
      'Looks like the paper. Best for printing and uploading';

  @override
  String get fileTypeDocx => 'Word (.docx)';

  @override
  String get fileTypeDocxDesc => 'Text you can edit and lay out again';

  @override
  String get fileTypeDocxFontNote =>
      'Word needs a Bangla font to show Bangla text.';

  @override
  String get fileTypeTxt => 'Plain text (.txt)';

  @override
  String get fileTypeTxtDesc => 'Only the words';

  @override
  String get fileTypeJpg => 'Pictures (.jpg)';

  @override
  String get fileTypeJpgDesc => 'One picture for each page';

  @override
  String get fileTypeCsv => 'Spreadsheet (.csv)';

  @override
  String get fileTypeCsvDesc => 'Receipt totals, VAT and payment details';

  @override
  String get options => 'Options';

  @override
  String get pageSize => 'Page size';

  @override
  String get pageSizeA4 => 'A4';

  @override
  String get pageSizeLetter => 'Letter';

  @override
  String get pageSizeAsScanned => 'As scanned';

  @override
  String get keepFileUnder => 'Keep the file under';

  @override
  String get keepFileUnderSub => 'Upload forms often set a limit';

  @override
  String get noSizeLimit => 'No limit';

  @override
  String sizeLimitMb(int mb) {
    return '$mb MB';
  }

  @override
  String get sizeLimitCannotFit =>
      'This paper cannot fit under that limit at readable quality.';

  @override
  String get watermark => 'Watermark';

  @override
  String get watermarkDefaultPurpose => 'For visa application only';

  @override
  String get watermarkPurposeHint => 'Watermark text';

  @override
  String get translatorSignPage => 'Page for the translator to sign';

  @override
  String get translatorSignPageSub => 'Name, signature, date and seal';

  @override
  String get preview => 'Preview';

  @override
  String get saveToPhone => 'Save to phone';

  @override
  String get print => 'Print';

  @override
  String get draftTranslationStamp => 'DRAFT TRANSLATION';

  @override
  String get draftTranslationFooter => 'Draft translation from Bangla';

  @override
  String get toSignTab => 'To sign';

  @override
  String get nextGetCertified => 'Next, get it certified';

  @override
  String get nextGetCertifiedBody =>
      'A translator or notary checks this draft, then signs and seals the last page. Most embassies and offices only accept a certified translation.';

  @override
  String get idBothSidesTitle => 'National ID, both sides';

  @override
  String get coverDetailSub => 'Hide a number or address before you share';

  @override
  String get blackAndWhiteCopy => 'Black and white copy';

  @override
  String copyMadeOn(String date) {
    return 'Copy made $date';
  }

  @override
  String get savedStamp => 'SAVED';

  @override
  String get savedToYourPhone => 'Saved to your phone';

  @override
  String get shareSub => 'WhatsApp, email, Bluetooth and more';

  @override
  String get addToABundle => 'Add to a bundle';

  @override
  String get openTheFolder => 'Open the folder';

  @override
  String get coverToolBlackBar => 'Black bar';

  @override
  String get coverToolBlur => 'Blur';

  @override
  String get undo => 'Undo';

  @override
  String get coverDetailSafeNote =>
      'The covered part is removed from the copy you export. Your saved scan stays whole.';

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
      other: '$count papers',
      one: '1 paper',
    );
    return 'Found in $_temp0. Names in your name book match in both languages.';
  }

  @override
  String pageBanglaText(int page) {
    return 'Page $page, Bangla text';
  }

  @override
  String renewByDate(String date) {
    return 'Renew by $date';
  }

  @override
  String get setRenewByDate => 'Set renewal date';

  @override
  String get clearRenewByDate => 'Clear renewal date';

  @override
  String get bundlesIntro =>
      'Keep the papers for one purpose together, then export them in one go.';

  @override
  String neededByDate(String date) {
    return 'Needed by $date';
  }

  @override
  String byDueDate(String date) {
    return 'By $date';
  }

  @override
  String get setDueDate => 'Set due date';

  @override
  String itemIsMissing(String item) {
    return '$item is missing';
  }

  @override
  String bundleChecklistSummary(int ready, int needsWork, int missing) {
    return '$ready ready, $needsWork need work, $missing missing';
  }

  @override
  String get checklistDisclaimer =>
      'Check the official list for your application.';

  @override
  String get notScannedYet => 'Not scanned yet';

  @override
  String scannedPagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return 'Scanned, $_temp0';
  }

  @override
  String get draftNeedsCertifying => 'English draft still needs certifying';

  @override
  String wordsToCheckBeforeTranslating(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words to check before translating',
      one: '1 word to check before translating',
    );
    return '$_temp0';
  }

  @override
  String get openAction => 'Open';

  @override
  String get checkAction => 'Check';

  @override
  String get addAction => 'Add';

  @override
  String get exportBundle => 'Export bundle';

  @override
  String get linkExistingPaper => 'Link an existing paper';

  @override
  String get scanNewPaper => 'Scan a new paper';

  @override
  String get addChecklistItem => 'Add checklist item';

  @override
  String get itemNameHint => 'Paper name';

  @override
  String get bundleTitleHint => 'Bundle name';

  @override
  String get createBundle => 'Create bundle';

  @override
  String get howToPackIt => 'How to pack it';

  @override
  String get onePdfWithContents => 'One PDF with a contents page';

  @override
  String get onePdfWithContentsSub =>
      'Papers in checklist order, with page numbers';

  @override
  String get separateFiles => 'Separate files';

  @override
  String get separateFilesSub =>
      'Named 01-Passport.pdf, 02-National-ID.pdf and so on';

  @override
  String get orderHeading => 'Order';

  @override
  String readyPapersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ready papers',
      one: '1 ready paper',
    );
    return '$_temp0';
  }

  @override
  String bundleDraftWarning(String title) {
    return 'The $title translation is still a draft. Add the certified copy when you have it.';
  }

  @override
  String get keepEachFileUnder => 'Keep each file under';

  @override
  String get watermarkEveryPage => 'Watermark every page';

  @override
  String lessThanMonth(String amount, String month) {
    return '$amount less than $month';
  }

  @override
  String moreThanMonth(String amount, String month) {
    return '$amount more than $month';
  }

  @override
  String sameAsMonth(String month) {
    return 'Same as $month';
  }

  @override
  String get receiptsThisMonth => 'Receipts this month';

  @override
  String get exportCsvAction => 'Export CSV';

  @override
  String get noReceiptsThisMonthSub =>
      'Scan a receipt to track monthly spending.';

  @override
  String get checkReceiptTitle => 'Check receipt';

  @override
  String itemsAddUpToTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items add up to the total',
      one: '1 item adds up to the total',
    );
    return '$_temp0';
  }

  @override
  String itemsDoNotAddUp(int count, String sum) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items add up to $sum, not the total',
      one: '1 item adds up to $sum, not the total',
    );
    return '$_temp0';
  }

  @override
  String get tapFieldToSeeSource =>
      'Tap a field to see where it was read on the receipt.';

  @override
  String get shopLabel => 'Shop';

  @override
  String get dateFieldLabel => 'Date';

  @override
  String get vatLabel => 'VAT';

  @override
  String get paidWithLabel => 'Paid with';

  @override
  String get paidCash => 'Cash';

  @override
  String get paidCard => 'Card';

  @override
  String get paidBkash => 'bKash';

  @override
  String get paidNagad => 'Nagad';

  @override
  String get paidRocket => 'Rocket';

  @override
  String itemsCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String andMoreItems(String preview, int count) {
    return '$preview and $count more';
  }

  @override
  String get saveReceiptAction => 'Save receipt';

  @override
  String csvExported(String fileName) {
    return 'CSV exported: $fileName';
  }

  @override
  String get categoriesLabel => 'Categories';

  @override
  String get categoriesSub => 'Edit receipt categories';

  @override
  String get addCategoryAction => 'Add category';

  @override
  String get categoryNameEnHint => 'Category name (English)';

  @override
  String get categoryNameBnHint => 'Category name (Bangla)';

  @override
  String get backupHeroTitle => 'Your papers live only on this phone';

  @override
  String get backupHeroBody =>
      'A backup is one locked file with all your papers, their text and your settings. Keep it on a memory card, a pen drive or another phone.';

  @override
  String get lastBackupLabel => 'Last backup';

  @override
  String get lastBackupNever => 'Never';

  @override
  String lastBackupSummary(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count papers',
      one: '1 paper',
    );
    return '$date, $_temp0';
  }

  @override
  String papersNotBackedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count papers are not backed up yet',
      one: '1 paper is not backed up yet',
    );
    return '$_temp0';
  }

  @override
  String get allPapersBackedUp => 'All papers are backed up';

  @override
  String lastBackupShortSub(String date, int count) {
    return 'Last backup $date. $count papers not backed up';
  }

  @override
  String get remindMeEveryMonth => 'Remind me every month';

  @override
  String get backupPasswordWarning =>
      'You choose a password for the file. Without it nobody can open the backup, and Rosid cannot recover it for you.';

  @override
  String get bringFromBackupFile => 'Bring papers from a backup file';

  @override
  String get backupReminderBanner =>
      'Time for a monthly backup. Your papers live only on this phone.';

  @override
  String get chooseBackupPassword => 'Choose a backup password';

  @override
  String get enterBackupPassword => 'Enter backup password';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get passwordTooShort => 'Use at least 4 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get backupCreated => 'Backup saved';

  @override
  String get backupRestored => 'Papers restored from backup';

  @override
  String get backupWrongPassword =>
      'Wrong password. Your current papers were not changed.';

  @override
  String get backupDamagedFile =>
      'This backup file is damaged or not from Rosid. Your current papers were not changed.';

  @override
  String get backupFailed => 'Could not complete backup';

  @override
  String get appLockTitle => 'Unlock Rosid';

  @override
  String get appLockEnterPin => 'Enter your PIN';

  @override
  String get appLockWrongPin => 'Wrong PIN. Try again.';

  @override
  String get appLockUseFingerprint => 'Use fingerprint';

  @override
  String get appLockSetPinTitle => 'Set a PIN';

  @override
  String get appLockConfirmPinTitle => 'Confirm your PIN';

  @override
  String get appLockPinMismatch => 'PINs did not match. Try again.';

  @override
  String get appLockPinHint => '4 to 6 digits';

  @override
  String get appLockChangePin => 'Change PIN';

  @override
  String get appLockEnabledSub => 'Locked with fingerprint or PIN';

  @override
  String storageUsedMb(String size) {
    return '$size on this phone';
  }

  @override
  String namesPeoplePlacesCount(int people, int places) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: '1 person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      places,
      locale: localeName,
      other: '$places places',
      one: '1 place',
    );
    return '$_temp0, $_temp1';
  }
}
