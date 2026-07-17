import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/features/review/confidence_field.dart';

void main() {
  testWidgets('keeps focus while parent state follows each edit', (
    tester,
  ) async {
    await tester.pumpWidget(const _ConfidenceFieldHarness());

    final field = find.byType(TextFormField);
    await tester.tap(field);
    await tester.showKeyboard(field);
    tester.testTextInput.enterText('R');
    await tester.pump();

    var editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);

    tester.testTextInput.enterText('Rosid');
    await tester.pump();
    editable = tester.widget<EditableText>(find.byType(EditableText));

    expect(editable.controller.text, 'Rosid');
    expect(editable.focusNode.hasFocus, isTrue);
  });
}

class _ConfidenceFieldHarness extends StatefulWidget {
  const _ConfidenceFieldHarness();

  @override
  State<_ConfidenceFieldHarness> createState() =>
      _ConfidenceFieldHarnessState();
}

class _ConfidenceFieldHarnessState extends State<_ConfidenceFieldHarness> {
  var value = '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ConfidenceField(
          label: 'Merchant',
          initialValue: value,
          onChanged: (next) => setState(() => value = next),
        ),
      ),
    );
  }
}
