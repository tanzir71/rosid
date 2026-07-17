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

  /// No description provided for @offlineTagline.
  ///
  /// In en, this message translates to:
  /// **'Private scanning, entirely on your device'**
  String get offlineTagline;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

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

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search documents and receipts'**
  String get search;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

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

  /// No description provided for @expenseTracking.
  ///
  /// In en, this message translates to:
  /// **'Expense tracking'**
  String get expenseTracking;

  /// No description provided for @expenseTrackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Show receipt scanning, dashboard, categories, and CSV export.'**
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
  /// **'Crop & enhance'**
  String get cropEnhance;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @enhanced.
  ///
  /// In en, this message translates to:
  /// **'Enhanced'**
  String get enhanced;

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
  /// **'Review receipt'**
  String get reviewReceipt;

  /// No description provided for @reviewDocument.
  ///
  /// In en, this message translates to:
  /// **'Review document'**
  String get reviewDocument;

  /// No description provided for @merchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchant;

  /// No description provided for @purchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase date'**
  String get purchaseDate;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @lineItems.
  ///
  /// In en, this message translates to:
  /// **'Line items'**
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
  /// **'Handwriting detected — please verify the text.'**
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
  /// **'Export expenses as CSV'**
  String get exportCsv;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Share document as PDF'**
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
  /// **'Language'**
  String get language;

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
  /// **'Default currency'**
  String get defaultCurrency;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get deleteAllData;

  /// No description provided for @deleteAllDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Permanently removes every scan and image from this device.'**
  String get deleteAllDataDescription;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get confirmDelete;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'100% offline'**
  String get privacyTitle;

  /// No description provided for @privacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your documents never leave your phone. Rosid has no account, analytics, or network access.'**
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

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is unavailable. You can import an image from the gallery.'**
  String get cameraUnavailable;

  /// No description provided for @cameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to scan.'**
  String get cameraPermission;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing on your device…'**
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
  /// **'No matching scans'**
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
  /// **'Monthly spend'**
  String get monthlySpend;

  /// No description provided for @spendByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spend by category'**
  String get spendByCategory;
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
