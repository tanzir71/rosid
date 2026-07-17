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
  String get offlineTagline => 'Private scanning, entirely on your device';

  @override
  String get home => 'Home';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get scan => 'Scan';

  @override
  String get search => 'Search documents and receipts';

  @override
  String get documents => 'Documents';

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
  String get recentReceipts => 'Recent receipts';

  @override
  String get noReceipts => 'No receipts yet';

  @override
  String get expenseTracking => 'Expense tracking';

  @override
  String get expenseTrackingDescription =>
      'Show receipt scanning, dashboard, categories, and CSV export.';

  @override
  String get receipt => 'Receipt';

  @override
  String get document => 'Document';

  @override
  String get capture => 'Capture';

  @override
  String get gallery => 'Gallery';

  @override
  String get flash => 'Flash';

  @override
  String get done => 'Done';

  @override
  String get retake => 'Retake';

  @override
  String get cropEnhance => 'Crop & enhance';

  @override
  String get original => 'Original';

  @override
  String get enhanced => 'Enhanced';

  @override
  String get rotate => 'Rotate';

  @override
  String get continueLabel => 'Continue';

  @override
  String get reviewReceipt => 'Review receipt';

  @override
  String get reviewDocument => 'Review document';

  @override
  String get merchant => 'Merchant';

  @override
  String get purchaseDate => 'Purchase date';

  @override
  String get total => 'Total';

  @override
  String get tax => 'Tax';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get category => 'Category';

  @override
  String get lineItems => 'Line items';

  @override
  String get notes => 'Notes';

  @override
  String get title => 'Title';

  @override
  String get body => 'Text';

  @override
  String get tags => 'Tags';

  @override
  String get rawOcrText => 'Raw OCR text';

  @override
  String get verifyLowConfidence => 'Please verify the highlighted fields.';

  @override
  String get verifyHandwriting =>
      'Handwriting detected — please verify the text.';

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
  String get exportCsv => 'Export expenses as CSV';

  @override
  String get exportPdf => 'Share document as PDF';

  @override
  String get filter => 'Filter';

  @override
  String get all => 'All';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get bangla => 'বাংলা';

  @override
  String get defaultCurrency => 'Default currency';

  @override
  String get categories => 'Categories';

  @override
  String get deleteAllData => 'Delete all data';

  @override
  String get deleteAllDataDescription =>
      'Permanently removes every scan and image from this device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmDelete => 'Delete permanently';

  @override
  String get privacyTitle => '100% offline';

  @override
  String get privacyDescription =>
      'Your documents never leave your phone. Rosid has no account, analytics, or network access.';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get cameraUnavailable =>
      'Camera is unavailable. You can import an image from the gallery.';

  @override
  String get cameraPermission => 'Camera access is needed to scan.';

  @override
  String get processing => 'Processing on your device…';

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
  String get noResults => 'No matching scans';

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
  String get monthlySpend => 'Monthly spend';

  @override
  String get spendByCategory => 'Spend by category';
}
