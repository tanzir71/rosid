import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/features/review/receipt_review_controller.dart';
import 'package:rosid/features/review/receipt_review_screen.dart';

void main() {
  testWidgets('removing an earlier item preserves the remaining field state', (
    tester,
  ) async {
    await tester.pumpWidget(const _LineItemHarness());

    final secondName = find.byKey(const ValueKey('line-item-name-second'));
    await tester.enterText(secondName, 'Edited second item');
    await tester.tap(find.byKey(const ValueKey('line-item-delete-first')));
    await tester.pump();

    expect(find.byKey(const ValueKey('line-item-name-first')), findsNothing);
    expect(secondName, findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: secondName,
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Edited second item',
    );
  });
}

class _LineItemHarness extends StatefulWidget {
  const _LineItemHarness();

  @override
  State<_LineItemHarness> createState() => _LineItemHarnessState();
}

class _LineItemHarnessState extends State<_LineItemHarness> {
  var _items = const [
    EditableLineItem(
      id: 'first',
      name: 'First item',
      quantity: '1',
      amount: '10',
    ),
    EditableLineItem(
      id: 'second',
      name: 'Second item',
      quantity: '1',
      amount: '20',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          children: [
            for (final item in _items)
              ReceiptLineItemEditor(
                key: ValueKey(item.id),
                item: item,
                onChanged: (changed) {
                  setState(() {
                    _items = [
                      for (final candidate in _items)
                        if (candidate.id == changed.id) changed else candidate,
                    ];
                  });
                },
                onRemove: () {
                  setState(() {
                    _items = [
                      for (final candidate in _items)
                        if (candidate.id != item.id) candidate,
                    ];
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}
