import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/features/review/receipt_input_validation.dart';

void main() {
  test('strict amounts accept supported wrappers and Bangla digits', () {
    for (final value in const [
      (input: '৳ ১,২৫০.৫০', expected: 1250.5),
      (input: '+12.50 BDT', expected: 12.5),
      (input: 'BDT 12.50', expected: 12.5),
      (input: '১২.৫০ Taka', expected: 12.5),
      (input: 'TK. ৫০', expected: 50.0),
      (input: '50 Tk', expected: 50.0),
      (input: '৫০ টাকা', expected: 50.0),
    ]) {
      expect(
        ReceiptInputValidation.requiredNonNegativeAmount(value.input),
        value.expected,
        reason: value.input,
      );
    }
  });

  test('line items accept strict Bangla numeric input', () {
    final item = ReceiptInputValidation.lineItem(
      name: 'Rice',
      quantity: '+২',
      unitPrice: 'Tk. ৫০.২৫',
      amount: '১০০.৫০ টাকা',
    );

    expect(item!.quantity, 2);
    expect(item.unitPrice, 50.25);
    expect(item.amount, 100.5);
  });

  test('strict amounts reject embedded garbage and malformed grouping', () {
    for (final input in const [
      '1abc2',
      '1/2',
      '12x34',
      '1,23',
      '12,34,567',
      '1,234,',
      '1.2.3',
      '৳ 1,000 BDT',
      'USD 12',
    ]) {
      expect(
        () => ReceiptInputValidation.requiredNonNegativeAmount(input),
        throwsA(isA<ReceiptInputValidationException>()),
        reason: input,
      );
    }
  });

  test('blank quantity defaults to one', () {
    final item = ReceiptInputValidation.lineItem(
      name: 'Rice',
      quantity: '',
      unitPrice: '50',
      amount: '100',
    );

    expect(item!.quantity, 1);
  });

  for (final input in const ['abc', '-1']) {
    test('rejects invalid quantity $input', () {
      expect(
        () => ReceiptInputValidation.lineItem(
          name: 'Rice',
          quantity: input,
          unitPrice: '50',
          amount: '100',
        ),
        throwsA(isA<ReceiptInputValidationException>()),
      );
    });

    test('rejects invalid unit price $input', () {
      expect(
        () => ReceiptInputValidation.lineItem(
          name: 'Rice',
          quantity: '1',
          unitPrice: input,
          amount: '100',
        ),
        throwsA(isA<ReceiptInputValidationException>()),
      );
    });
  }

  test('rejects negative and malformed optional tax', () {
    for (final input in ['-0.01', 'abc', '1/2', '1,23']) {
      expect(
        () => ReceiptInputValidation.optionalNonNegativeAmount(input),
        throwsA(isA<ReceiptInputValidationException>()),
      );
    }
  });

  test('line items reject malformed numeric fields independently', () {
    for (final values in const [
      (quantity: '1abc2', unitPrice: '50', amount: '100'),
      (quantity: '1,23', unitPrice: '50', amount: '100'),
      (quantity: '1', unitPrice: '12x34', amount: '100'),
      (quantity: '1', unitPrice: '50', amount: '1/2'),
    ]) {
      expect(
        () => ReceiptInputValidation.lineItem(
          name: 'Rice',
          quantity: values.quantity,
          unitPrice: values.unitPrice,
          amount: values.amount,
        ),
        throwsA(isA<ReceiptInputValidationException>()),
        reason: values.toString(),
      );
    }
  });

  test('line item quantity does not accept currency wrappers', () {
    expect(
      () => ReceiptInputValidation.lineItem(
        name: 'Rice',
        quantity: '৳ 2',
        unitPrice: '50',
        amount: '100',
      ),
      throwsA(isA<ReceiptInputValidationException>()),
    );
  });
}
