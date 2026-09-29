import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text result rejects blank text', () {
    expect(() => OcrResult.textDetected('  \n'), throwsArgumentError);
  });

  test('direct text result rejects blank text', () {
    expect(() => TextDetected('  \n'), throwsArgumentError);
  });

  test('text result preserves nonblank text', () {
    final result = OcrResult.textDetected('Invoice 42');

    expect(result, isA<TextDetected>());
    expect((result as TextDetected).text, 'Invoice 42');
  });

  test('only explicit transport failure retries', () {
    expect(OcrFailure.transportTransient().isRetryable, isTrue);
    expect(OcrFailure.quota().isRetryable, isFalse);
    expect(OcrFailure.invalidResponse().isRetryable, isFalse);
    for (final kind in OcrFailureKind.values) {
      expect(
        OcrFailure.of(kind).isRetryable,
        kind == OcrFailureKind.transportTransient,
        reason: '$kind retryability must be conservative',
      );
    }
  });
}
