sealed class OcrResult {
  const OcrResult();

  factory OcrResult.textDetected(String text) => TextDetected(text);

  const factory OcrResult.noReadableText() = NoReadableText;
}

final class TextDetected extends OcrResult {
  factory TextDetected(String text) {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text');
    }
    return TextDetected._(text);
  }

  const TextDetected._(this.text);

  final String text;
}

final class NoReadableText extends OcrResult {
  const NoReadableText();
}
