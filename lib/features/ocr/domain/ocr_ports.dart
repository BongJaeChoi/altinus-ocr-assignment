import 'ocr_result.dart';

abstract interface class CloudOcrService {
  bool get configurationPending;

  Future<OcrResult> recognize(String imagePath);
}

abstract interface class LocalOcrService {
  Future<OcrResult> recognize(String imagePath);
}

abstract interface class ImagePreparer {
  Future<PreparedImage> prepare(String canonicalPath);
}

abstract interface class TransactionFiles {
  Future<void> cleanup(Iterable<String> paths);
  Future<void> cleanupOrphans();
}

abstract interface class AppSettingsLauncher {
  Future<bool> open();
}

final class PreparedImage {
  const PreparedImage({required this.canonicalPath, required this.cloudPath});

  final String canonicalPath;
  final String cloudPath;
}
