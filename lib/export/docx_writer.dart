import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Writes a valid WordprocessingML `.docx` zip archive directly with `archive`.
///
/// Follows `handover/milestones/M6-export.md` step 6:
/// - Paragraphs and a clean two-column side-by-side table when both Bangla and
///   English draft are included.
/// - On every Bangla run sets `<w:rFonts w:cs="Nirmala UI"/>` and
///   `<w:lang w:bidi="bn-BD"/>` so Word shapes Bangla properly without embedding fonts.
/// - Places the `DRAFT TRANSLATION` notice in the running header of every page
///   whenever English draft text is included.
abstract final class DocxWriter {
  static Uint8List build({
    required String title,
    required List<String> banglaLines,
    required List<DraftLineView> englishLines,
    required bool includeBangla,
    required bool includeEnglish,
    required bool includeTranslatorPage,
    String? watermarkText,
  }) {
    final hasDraft = includeEnglish && englishLines.isNotEmpty;
    final archive = Archive();

    void addXml(String path, String xmlContent) {
      final bytes = utf8.encode(xmlContent);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addXml('[Content_Types].xml', _contentTypesXml(hasHeader: hasDraft));
    addXml('_rels/.rels', _rootRelsXml());
    addXml(
      'word/_rels/document.xml.rels',
      _documentRelsXml(hasHeader: hasDraft),
    );

    if (hasDraft) {
      addXml('word/header1.xml', _headerXml(watermarkText: watermarkText));
    }

    addXml(
      'word/document.xml',
      _documentXml(
        title: title,
        banglaLines: banglaLines,
        englishLines: englishLines,
        includeBangla: includeBangla,
        includeEnglish: includeEnglish,
        includeTranslatorPage: includeTranslatorPage,
        hasHeader: hasDraft,
        watermarkText: watermarkText,
      ),
    );

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static bool _containsBangla(String text) =>
      RegExp(r'[\u0980-\u09FF]').hasMatch(text);

  static String _runXml(
    String text, {
    bool bold = false,
    int? halfPointsSize,
    String? colorHex,
    bool forceBanglaFont = false,
  }) {
    final isBn = forceBanglaFont || _containsBangla(text);
    final rPr = StringBuffer('<w:rPr>');
    if (isBn) {
      rPr.write(
        '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Nirmala UI"/>',
      );
      rPr.write('<w:lang w:val="en-US" w:bidi="bn-BD"/>');
    } else {
      rPr.write('<w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>');
    }
    if (bold) rPr.write('<w:b/><w:bCs/>');
    if (halfPointsSize != null) {
      rPr.write(
        '<w:sz w:val="$halfPointsSize"/><w:szCs w:val="$halfPointsSize"/>',
      );
    }
    if (colorHex != null) {
      rPr.write('<w:color w:val="$colorHex"/>');
    }
    rPr.write('</w:rPr>');
    return '<w:r>$rPr<w:t xml:space="preserve">${_escape(text)}</w:t></w:r>';
  }

  static String _paragraphXml(
    String text, {
    bool bold = false,
    int? halfPointsSize,
    String? colorHex,
    int spaceAfter = 120,
    bool forceBanglaFont = false,
  }) {
    return '<w:p>'
        '<w:pPr><w:spacing w:after="$spaceAfter"/></w:pPr>'
        '${_runXml(text, bold: bold, halfPointsSize: halfPointsSize, colorHex: colorHex, forceBanglaFont: forceBanglaFont)}'
        '</w:p>';
  }

  static String _tableCellXml(
    String text, {
    bool bold = false,
    int widthDxa = 4500,
    bool forceBanglaFont = false,
    String? shadingHex,
  }) {
    final shd = shadingHex == null
        ? ''
        : '<w:shd w:val="clear" w:color="auto" w:fill="$shadingHex"/>';
    return '<w:tc>'
        '<w:tcPr><w:tcW w:w="$widthDxa" w:type="dxa"/>$shd</w:tcPr>'
        '${_paragraphXml(text, bold: bold, halfPointsSize: 22, spaceAfter: 80, forceBanglaFont: forceBanglaFont)}'
        '</w:tc>';
  }

  static String _documentXml({
    required String title,
    required List<String> banglaLines,
    required List<DraftLineView> englishLines,
    required bool includeBangla,
    required bool includeEnglish,
    required bool includeTranslatorPage,
    required bool hasHeader,
    String? watermarkText,
  }) {
    final body = StringBuffer();

    body.write(
      _paragraphXml(
        title,
        bold: true,
        halfPointsSize: 32,
        colorHex: '1A1B2E',
        spaceAfter: 160,
      ),
    );

    if (hasHeader) {
      body.write(
        _paragraphXml(
          'DRAFT TRANSLATION — Made on phone with Rosid. Check names and numbers before you use it.',
          bold: true,
          halfPointsSize: 18,
          colorHex: '4333B0',
          spaceAfter: 200,
        ),
      );
    }

    if (watermarkText != null && watermarkText.trim().isNotEmpty) {
      body.write(
        _paragraphXml(
          'Purpose: ${watermarkText.trim()}',
          halfPointsSize: 18,
          colorHex: '55586A',
          spaceAfter: 180,
        ),
      );
    }

    // Side-by-side two-column table when both Bangla and English are chosen.
    if (includeBangla && includeEnglish && englishLines.isNotEmpty) {
      body.write('<w:tbl>');
      body.write(
        '<w:tblPr>'
        '<w:tblW w:w="9000" w:type="dxa"/>'
        '<w:tblBorders>'
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="DCE0D3"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="DCE0D3"/>'
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="DCE0D3"/>'
        '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="DCE0D3"/>'
        '<w:left w:val="none"/><w:right w:val="none"/>'
        '</w:tblBorders>'
        '</w:tblPr>',
      );
      body.write(
        '<w:tr>'
        '${_tableCellXml('Original (Bangla)', bold: true, shadingHex: 'F2F4EE')}'
        '${_tableCellXml('English draft (DRAFT)', bold: true, shadingHex: 'F2F4EE')}'
        '</w:tr>',
      );
      for (final row in englishLines) {
        body.write(
          '<w:tr>'
          '${_tableCellXml(row.sourceText, forceBanglaFont: true)}'
          '${_tableCellXml(row.englishText)}'
          '</w:tr>',
        );
      }
      body.write('</w:tbl>');
    } else if (includeEnglish && englishLines.isNotEmpty) {
      for (final row in englishLines) {
        body.write(_paragraphXml(row.englishText, halfPointsSize: 22));
      }
    } else if (includeBangla) {
      for (final line in banglaLines) {
        body.write(
          _paragraphXml(line, halfPointsSize: 22, forceBanglaFont: true),
        );
      }
    }

    if (includeTranslatorPage) {
      body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      body.write(
        _paragraphXml(
          "Translator's Certification",
          bold: true,
          halfPointsSize: 28,
          colorHex: '1A1B2E',
          spaceAfter: 200,
        ),
      );
      body.write(
        _paragraphXml(
          'I certify that I am competent in Bangla and English, and that the attached English translation is a true and accurate translation of the original Bangla document.',
          halfPointsSize: 22,
          spaceAfter: 320,
        ),
      );
      body.write(
        _paragraphXml(
          'Translator full name: ________________________________________',
          halfPointsSize: 22,
          spaceAfter: 240,
        ),
      );
      body.write(
        _paragraphXml(
          'Signature: ___________________________________________________',
          halfPointsSize: 22,
          spaceAfter: 240,
        ),
      );
      body.write(
        _paragraphXml(
          'Date: ________________________________________________________',
          halfPointsSize: 22,
          spaceAfter: 240,
        ),
      );
      body.write(
        _paragraphXml(
          'Official seal / Notary registration:',
          halfPointsSize: 22,
          spaceAfter: 480,
        ),
      );
    }

    final headerRef = hasHeader
        ? '<w:headerReference w:type="default" r:id="rId1"/>'
        : '';

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:body>'
        '$body'
        '<w:sectPr>'
        '$headerRef'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="567" w:footer="567"/>'
        '</w:sectPr>'
        '</w:body>'
        '</w:document>';
  }

  static String _headerXml({String? watermarkText}) {
    final extra = (watermarkText != null && watermarkText.trim().isNotEmpty)
        ? '  |  ${watermarkText.trim()}'
        : '';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '${_paragraphXml('DRAFT TRANSLATION — Draft translation from Bangla$extra', bold: true, halfPointsSize: 16, colorHex: '4333B0', spaceAfter: 40)}'
        '</w:hdr>';
  }

  static String _contentTypesXml({required bool hasHeader}) {
    final hdrOverride = hasHeader
        ? '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
        : '';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '$hdrOverride'
        '</Types>';
  }

  static String _rootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';
  }

  static String _documentRelsXml({required bool hasHeader}) {
    final rel = hasHeader
        ? '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>'
        : '';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rel'
        '</Relationships>';
  }
}
