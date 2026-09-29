import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/platform_apis.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/example/altinus_ocr/PlatformApis.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.altinus_ocr'),
    swiftOut: 'ios/Runner/PlatformApis.g.swift',
  ),
)
enum NativeOcrStatus { textDetected, noReadableText }

class NativeOcrReply {
  NativeOcrReply({required this.status, this.text});

  NativeOcrStatus status;
  String? text;
}

@HostApi()
abstract class NativeOcrHostApi {
  @asyncCallback
  NativeOcrReply recognizeKorean(String imagePath);
}

@HostApi()
abstract class AppSettingsHostApi {
  @asyncCallback
  bool open();
}
