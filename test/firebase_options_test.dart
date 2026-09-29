import 'package:altinus_ocr/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated mobile options belong to the dedicated project', () {
    expect(
      DefaultFirebaseOptions.android.projectId,
      'artinus-ocr-bongjae-202609',
    );
    expect(
      DefaultFirebaseOptions.android.appId,
      '1:867285305627:android:b00b0c0a36bcd8780f6bbe',
    );
    expect(DefaultFirebaseOptions.ios.projectId, 'artinus-ocr-bongjae-202609');
    expect(DefaultFirebaseOptions.ios.iosBundleId, 'dev.bongjae.artinusocr');
    expect(
      DefaultFirebaseOptions.ios.appId,
      '1:867285305627:ios:f03ea9c48ae6ee7a0f6bbe',
    );
  });
}
