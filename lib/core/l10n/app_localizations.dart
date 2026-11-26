import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Rosid'**
  String get appName;

  /// No description provided for @appWordmarkBn.
  ///
  /// In en, this message translates to:
  /// **'রসিদ'**
  String get appWordmarkBn;

  /// No description provided for @offlineTagline.
  ///
  /// In en, this message translates to:
  /// **'Private scanning, entirely on your device'**
  String get offlineTagline;

  /// No description provided for @worksOfflineStamp.
  ///
  /// In en, this message translates to:
  /// **'WORKS OFFLINE'**
  String get worksOfflineStamp;

  /// No description provided for @welcomeHeadlineBn.
  ///
  /// In en, this message translates to:
  /// **'যেকোনো কাগজ স্ক্যান করুন, পড়ুন, ইংরেজিতে নিন'**
  String get welcomeHeadlineBn;

  /// No description provided for @welcomeSublineEn.
  ///
  /// In en, this message translates to:
  /// **'Scan any Bangla paper. Read it, fix it, and get it in English.'**
  String get welcomeSublineEn;

  /// No description provided for @welcomeBanglaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'অ্যাপ বাংলায় ব্যবহার করুন'**
  String get welcomeBanglaSubtitle;

  /// No description provided for @welcomeEnglishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the app in English'**
  String get welcomeEnglishSubtitle;

  /// No description provided for @welcomePrivacyLine.
  ///
  /// In en, this message translates to:
  /// **'No account. No internet. Your papers stay on this phone.'**
  String get welcomePrivacyLine;

  /// No description provided for @welcomePurposeTitle.
  ///
  /// In en, this message translates to:
  /// **'What do you need Rosid for?'**
  String get welcomePurposeTitle;

  /// No description provided for @welcomePurposeHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick any. This only sets your home shortcuts, and you can change it later.'**
  String get welcomePurposeHelp;

  /// No description provided for @purposeVisaTitle.
  ///
  /// In en, this message translates to:
  /// **'Visa and abroad paperwork'**
  String get purposeVisaTitle;

  /// No description provided for @purposeVisaSub.
  ///
  /// In en, this message translates to:
  /// **'Translate papers to English and bundle them for an application'**
  String get purposeVisaSub;

  /// No description provided for @purposeLandTitle.
  ///
  /// In en, this message translates to:
  /// **'Land and property papers'**
  String get purposeLandTitle;

  /// No description provided for @purposeLandSub.
  ///
  /// In en, this message translates to:
  /// **'Deeds, khatian, mutation and land tax receipts'**
  String get purposeLandSub;

  /// No description provided for @purposeReceiptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipts and spending'**
  String get purposeReceiptsTitle;

  /// No description provided for @purposeReceiptsSub.
  ///
  /// In en, this message translates to:
  /// **'Keep receipts and see what you spend each month'**
  String get purposeReceiptsSub;

  /// No description provided for @purposeStudyTitle.
  ///
  /// In en, this message translates to:
  /// **'Study notes and handouts'**
  String get purposeStudyTitle;

  /// No description provided for @purposeStudySub.
  ///
  /// In en, this message translates to:
  /// **'Turn pages into text you can edit'**
  String get purposeStudySub;

  /// No description provided for @purposeOfficeTitle.
  ///
  /// In en, this message translates to:
  /// **'Office and shop paperwork'**
  String get purposeOfficeTitle;

  /// No description provided for @purposeOfficeSub.
  ///
  /// In en, this message translates to:
  /// **'Invoices, licences and letters'**
  String get purposeOfficeSub;

  /// No description provided for @purposeFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family records'**
  String get purposeFamilyTitle;

  /// No description provided for @purposeFamilySub.
  ///
  /// In en, this message translates to:
  /// **'IDs, certificates, prescriptions and bills'**
  String get purposeFamilySub;

  /// No description provided for @welcomeCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow the camera to scan'**
  String get welcomeCameraTitle;

  /// No description provided for @welcomeCameraBody.
  ///
  /// In en, this message translates to:
  /// **'Rosid uses the camera only while you scan. Pictures are kept inside the app, not in your gallery.'**
  String get welcomeCameraBody;

  /// No description provided for @welcomeAssuranceOffline.
  ///
  /// In en, this message translates to:
  /// **'Rosid has no internet permission, so it cannot upload anything.'**
  String get welcomeAssuranceOffline;

  /// No description provided for @welcomeAssuranceLock.
  ///
  /// In en, this message translates to:
  /// **'Lock the app with your fingerprint or a PIN.'**
  String get welcomeAssuranceLock;

  /// No description provided for @welcomeAssuranceBackup.
  ///
  /// In en, this message translates to:
  /// **'Back up to a file you keep, such as a memory card or pen drive.'**
  String get welcomeAssuranceBackup;

  /// No description provided for @allowCamera.
  ///
  /// In en, this message translates to:
  /// **'Allow camera'**
  String get allowCamera;

  /// No description provided for @notNowImportPhotos.
  ///
  /// In en, this message translates to:
  /// **'Not now, import photos instead'**
  String get notNowImportPhotos;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @bundles.
  ///
  /// In en, this message translates to:
  /// **'Bundles'**
  String get bundles;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @whatAreYouScanning.
  ///
  /// In en, this message translates to:
  /// **'What are you scanning?'**
  String get whatAreYouScanning;

  /// No description provided for @idCard.
  ///
  /// In en, this message translates to:
  /// **'ID card'**
  String get idCard;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @pickUpWhereYouLeftOff.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off'**
  String get pickUpWhereYouLeftOff;

  /// No description provided for @checkWords.
  ///
  /// In en, this message translates to:
  /// **'Check words'**
  String get checkWords;

  /// No description provided for @wordsToCheckCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word to check} other{{count} words to check}}'**
  String wordsToCheckCount(int count);

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @noPapersYet.
  ///
  /// In en, this message translates to:
  /// **'No papers yet'**
  String get noPapersYet;

  /// No description provided for @scanFirstPaperPrompt.
  ///
  /// In en, this message translates to:
  /// **'Scan a document, ID card or receipt to keep it on this phone.'**
  String get scanFirstPaperPrompt;

  /// No description provided for @noBundlesYet.
  ///
  /// In en, this message translates to:
  /// **'No bundles yet'**
  String get noBundlesYet;

  /// No description provided for @startBundlePrompt.
  ///
  /// In en, this message translates to:
  /// **'Collect papers against a checklist for a visa, land record or bank loan.'**
  String get startBundlePrompt;

  /// No description provided for @startFromChecklist.
  ///
  /// In en, this message translates to:
  /// **'Start from a checklist'**
  String get startFromChecklist;

  /// No description provided for @bundleProgress.
  ///
  /// In en, this message translates to:
  /// **'{ready} of {total} papers ready'**
  String bundleProgress(int ready, int total);

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search inside your papers'**
  String get search;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @ids.
  ///
  /// In en, this message translates to:
  /// **'IDs'**
  String get ids;

  /// No description provided for @receipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get receipts;

  /// No description provided for @land.
  ///
  /// In en, this message translates to:
  /// **'Land'**
  String get land;

  /// No description provided for @recentDocuments.
  ///
  /// In en, this message translates to:
  /// **'Recent documents'**
  String get recentDocuments;

  /// No description provided for @pinnedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Pinned documents'**
  String get pinnedDocuments;

  /// No description provided for @noDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get noDocuments;

  /// No description provided for @scanFirstDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan your first document to make it searchable.'**
  String get scanFirstDocument;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @spentThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent this month'**
  String get spentThisMonth;

  /// No description provided for @recentReceipts.
  ///
  /// In en, this message translates to:
  /// **'Recent receipts'**
  String get recentReceipts;

  /// No description provided for @noReceipts.
  ///
  /// In en, this message translates to:
  /// **'No receipts yet'**
  String get noReceipts;

  /// No description provided for @noReceiptsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No receipts this month. Scan a receipt to see your spending by category.'**
  String get noReceiptsThisMonth;

  /// No description provided for @expenseTracking.
  ///
  /// In en, this message translates to:
  /// **'Track spending from receipts'**
  String get expenseTracking;

  /// No description provided for @expenseTrackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Show receipt scanning, month view, categories, and CSV export.'**
  String get expenseTrackingDescription;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @document.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get document;

  /// No description provided for @landRecord.
  ///
  /// In en, this message translates to:
  /// **'Land record'**
  String get landRecord;

  /// No description provided for @certificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get certificate;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @importPhotos.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importPhotos;

  /// No description provided for @flash.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get flash;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @cropEnhance.
  ///
  /// In en, this message translates to:
  /// **'Adjust page'**
  String get cropEnhance;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @enhanced.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get enhanced;

  /// No description provided for @grey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get grey;

  /// No description provided for @blackAndWhite.
  ///
  /// In en, this message translates to:
  /// **'Black and white'**
  String get blackAndWhite;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @reviewReceipt.
  ///
  /// In en, this message translates to:
  /// **'Check receipt'**
  String get reviewReceipt;

  /// No description provided for @reviewDocument.
  ///
  /// In en, this message translates to:
  /// **'Review document'**
  String get reviewDocument;

  /// No description provided for @merchant.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get merchant;

  /// No description provided for @purchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get purchaseDate;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get tax;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Paid with'**
  String get paymentMethod;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @lineItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get lineItems;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @body.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get body;

  /// No description provided for @englishTab.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishTab;

  /// No description provided for @scanTab.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanTab;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @rawOcrText.
  ///
  /// In en, this message translates to:
  /// **'Raw OCR text'**
  String get rawOcrText;

  /// No description provided for @verifyLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Please verify the highlighted fields.'**
  String get verifyLowConfidence;

  /// No description provided for @verifyHandwriting.
  ///
  /// In en, this message translates to:
  /// **'Part of this page is handwritten. Check uncertain words against the photo.'**
  String get verifyHandwriting;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get saved;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get language;

  /// No description provided for @languageAndReading.
  ///
  /// In en, this message translates to:
  /// **'Language and reading'**
  String get languageAndReading;

  /// No description provided for @whatYouUseRosidFor.
  ///
  /// In en, this message translates to:
  /// **'What you use Rosid for'**
  String get whatYouUseRosidFor;

  /// No description provided for @names.
  ///
  /// In en, this message translates to:
  /// **'Names'**
  String get names;

  /// No description provided for @namesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved names yet'**
  String get namesEmpty;

  /// No description provided for @wordChoices.
  ///
  /// In en, this message translates to:
  /// **'Word choices'**
  String get wordChoices;

  /// No description provided for @wordChoicesSub.
  ///
  /// In en, this message translates to:
  /// **'How legal and land terms appear in English'**
  String get wordChoicesSub;

  /// No description provided for @safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @appLockSub.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint or PIN each time you open Rosid'**
  String get appLockSub;

  /// No description provided for @backUpAndMove.
  ///
  /// In en, this message translates to:
  /// **'Back up and move'**
  String get backUpAndMove;

  /// No description provided for @backUpNeverSub.
  ///
  /// In en, this message translates to:
  /// **'No backup yet. Keep a locked copy you control.'**
  String get backUpNeverSub;

  /// No description provided for @worksOffline.
  ///
  /// In en, this message translates to:
  /// **'Works offline'**
  String get worksOffline;

  /// No description provided for @worksOfflineSub.
  ///
  /// In en, this message translates to:
  /// **'No internet permission. Check under Android settings, Apps, Rosid'**
  String get worksOfflineSub;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @currencyTaka.
  ///
  /// In en, this message translates to:
  /// **'৳ Bangladeshi taka'**
  String get currencyTaka;

  /// No description provided for @thisPhone.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get thisPhone;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @storageOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Stored privately on this phone'**
  String get storageOnDevice;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @bangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get bangla;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get defaultCurrency;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteAllData;

  /// No description provided for @deleteAllDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Permanently removes every paper, image and bundle from this phone.'**
  String get deleteAllDataDescription;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get confirmDelete;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Works offline'**
  String get privacyTitle;

  /// No description provided for @privacyDescription.
  ///
  /// In en, this message translates to:
  /// **'No internet permission. Your papers stay on this phone.'**
  String get privacyDescription;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @versionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Version unavailable'**
  String get versionUnavailable;

  /// No description provided for @releasesAndUpdates.
  ///
  /// In en, this message translates to:
  /// **'Releases and updates'**
  String get releasesAndUpdates;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is unavailable. Import a photo from your phone instead.'**
  String get cameraUnavailable;

  /// No description provided for @cameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to scan. You can also import photos.'**
  String get cameraPermission;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Reading your paper on this phone…'**
  String get processing;

  /// No description provided for @addPage.
  ///
  /// In en, this message translates to:
  /// **'Add page'**
  String get addPage;

  /// No description provided for @pagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pages} =1{1 page} other{{count} pages}}'**
  String pagesCount(int count);

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No matching papers'**
  String get noResults;

  /// No description provided for @currencyBdt.
  ///
  /// In en, this message translates to:
  /// **'৳ BDT'**
  String get currencyBdt;

  /// No description provided for @scanMode.
  ///
  /// In en, this message translates to:
  /// **'Scan mode'**
  String get scanMode;

  /// No description provided for @languageHint.
  ///
  /// In en, this message translates to:
  /// **'Text language'**
  String get languageHint;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @mixedBanglaEnglish.
  ///
  /// In en, this message translates to:
  /// **'Bangla + English'**
  String get mixedBanglaEnglish;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @monthlySpend.
  ///
  /// In en, this message translates to:
  /// **'Spent this month'**
  String get monthlySpend;

  /// No description provided for @spendByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get spendByCategory;

  /// No description provided for @untitledDocument.
  ///
  /// In en, this message translates to:
  /// **'Untitled paper'**
  String get untitledDocument;

  /// No description provided for @documentTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title for this paper.'**
  String get documentTitleRequired;

  /// No description provided for @receiptFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the shop name, date and total.'**
  String get receiptFieldsRequired;

  /// No description provided for @validTotalAndTaxRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter valid non-negative total and VAT amounts.'**
  String get validTotalAndTaxRequired;

  /// No description provided for @validTaxRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid VAT amount.'**
  String get validTaxRequired;

  /// No description provided for @validLineItemRequired.
  ///
  /// In en, this message translates to:
  /// **'Each item needs a name, quantity and amount.'**
  String get validLineItemRequired;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get unitPrice;

  /// No description provided for @lowOcrConfidence.
  ///
  /// In en, this message translates to:
  /// **'Check this word'**
  String get lowOcrConfidence;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open your saved papers. Try again.'**
  String get loadFailed;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your changes. Check free storage and try again.'**
  String get saveFailed;

  /// No description provided for @processingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read this page. Try a clearer photo or adjust the corners.'**
  String get processingFailed;

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not take or import the photo. Try again.'**
  String get captureFailed;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the file. Check free storage and try again.'**
  String get exportFailed;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the data. Close other screens and try again.'**
  String get deleteFailed;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @scannedToday.
  ///
  /// In en, this message translates to:
  /// **'scanned today'**
  String get scannedToday;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow phone'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @englishDraftPending.
  ///
  /// In en, this message translates to:
  /// **'English draft will appear here once generated for this paper.'**
  String get englishDraftPending;

  /// No description provided for @bundleChecklistComing.
  ///
  /// In en, this message translates to:
  /// **'Add papers from your library or scan new ones into this bundle.'**
  String get bundleChecklistComing;

  /// No description provided for @backupPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Your papers live only on this phone'**
  String get backupPageTitle;

  /// No description provided for @backupPageBody.
  ///
  /// In en, this message translates to:
  /// **'Because Rosid never goes online, your papers are not copied to any server. Make a password-locked backup file whenever you want to keep a copy or move phones.'**
  String get backupPageBody;

  /// No description provided for @makeBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Make a backup file'**
  String get makeBackupFile;

  /// No description provided for @restoreBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Bring papers from a backup file'**
  String get restoreBackupFile;

  /// No description provided for @checkWordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No words need checking on this paper.'**
  String get checkWordsEmpty;

  /// No description provided for @readingOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Reading your paper'**
  String get readingOnPhone;

  /// No description provided for @happensOnPhone.
  ///
  /// In en, this message translates to:
  /// **'This happens on your phone. Nothing is uploaded.'**
  String get happensOnPhone;

  /// No description provided for @coverDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Cover a detail'**
  String get coverDetailTitle;

  /// No description provided for @coverDetailHint.
  ///
  /// In en, this message translates to:
  /// **'Drag over anything you want to hide.'**
  String get coverDetailHint;

  /// No description provided for @scriptGlyphBn.
  ///
  /// In en, this message translates to:
  /// **'অ'**
  String get scriptGlyphBn;

  /// No description provided for @scriptGlyphEn.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get scriptGlyphEn;

  /// No description provided for @autoCapture.
  ///
  /// In en, this message translates to:
  /// **'Auto capture'**
  String get autoCapture;

  /// No description provided for @hintNoPaper.
  ///
  /// In en, this message translates to:
  /// **'Place paper inside the frame'**
  String get hintNoPaper;

  /// No description provided for @hintMoveCloser.
  ///
  /// In en, this message translates to:
  /// **'Move closer'**
  String get hintMoveCloser;

  /// No description provided for @hintTooDark.
  ///
  /// In en, this message translates to:
  /// **'Too dark. Add light or turn on flash'**
  String get hintTooDark;

  /// No description provided for @hintGlare.
  ///
  /// In en, this message translates to:
  /// **'Too much glare. Tilt the paper slightly'**
  String get hintGlare;

  /// No description provided for @hintHoldSteady.
  ///
  /// In en, this message translates to:
  /// **'Hold steady'**
  String get hintHoldSteady;

  /// No description provided for @hintEdgesFound.
  ///
  /// In en, this message translates to:
  /// **'Edges found. Hold steady'**
  String get hintEdgesFound;

  /// No description provided for @donePages.
  ///
  /// In en, this message translates to:
  /// **'Done, {count, plural, =1{1 page} other{{count} pages}}'**
  String donePages(int count);

  /// No description provided for @idFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get idFront;

  /// No description provided for @idBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get idBack;

  /// No description provided for @turnCardOver.
  ///
  /// In en, this message translates to:
  /// **'Turn the card over'**
  String get turnCardOver;

  /// No description provided for @idBothSidesNote.
  ///
  /// In en, this message translates to:
  /// **'Front and back will be placed together on one page, ready to print or send.'**
  String get idBothSidesNote;

  /// No description provided for @pageOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageOfTotal(int current, int total);

  /// No description provided for @holdAndDragReorder.
  ///
  /// In en, this message translates to:
  /// **'Hold and drag to reorder'**
  String get holdAndDragReorder;

  /// No description provided for @readText.
  ///
  /// In en, this message translates to:
  /// **'Read text'**
  String get readText;

  /// No description provided for @stepPageCleaned.
  ///
  /// In en, this message translates to:
  /// **'Page straightened and cleaned'**
  String get stepPageCleaned;

  /// No description provided for @stepTextFound.
  ///
  /// In en, this message translates to:
  /// **'Bangla and English text found'**
  String get stepTextFound;

  /// No description provided for @stepReadingText.
  ///
  /// In en, this message translates to:
  /// **'Reading the text'**
  String get stepReadingText;

  /// No description provided for @stepLineProgress.
  ///
  /// In en, this message translates to:
  /// **'Line {current} of {total}'**
  String stepLineProgress(int current, int total);

  /// No description provided for @stepFindingDetails.
  ///
  /// In en, this message translates to:
  /// **'Finding names, dates and numbers'**
  String get stepFindingDetails;

  /// No description provided for @handwritingNote.
  ///
  /// In en, this message translates to:
  /// **'Part of this page is handwritten. Handwriting is harder to read, so check those words on the next screen.'**
  String get handwritingNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
