import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:image/image.dart' as image;

import '../domain/ocr_failure.dart';
import '../domain/ocr_ports.dart';
import '../domain/ocr_result.dart';

abstract interface class FirebaseModelGateway {
  bool get configurationPending;

  Future<FirebaseModelResponse> generate(FirebaseModelRequest request);
}

final class FirebaseModelRequest {
  const FirebaseModelRequest({
    required this.imageBytes,
    required this.mimeType,
  });

  final Uint8List imageBytes;
  final String mimeType;
}

enum FirebaseModelFinishReason { safety, recitation }

final class FirebaseModelResponse {
  const FirebaseModelResponse({this.text, this.finishReason});

  final String? text;
  final FirebaseModelFinishReason? finishReason;
}

final class FirebaseModelTransientException implements Exception {}

/// Safe composition default while no Firebase project has been authorized.
///
/// A configured bootstrap replaces this gateway with [FirebaseSdkModelGateway]
/// after `Firebase.initializeApp`; keeping the pending state typed prevents an
/// uninitialized SDK call from crashing normal app startup.
final class FirebaseConfigurationPendingGateway
    implements FirebaseModelGateway {
  const FirebaseConfigurationPendingGateway();

  @override
  bool get configurationPending => true;

  @override
  Future<FirebaseModelResponse> generate(FirebaseModelRequest request) =>
      Future<FirebaseModelResponse>.error(
        OcrFailure.of(OcrFailureKind.configuration),
      );
}

final class FirebaseConfigurationFailedGateway implements FirebaseModelGateway {
  const FirebaseConfigurationFailedGateway();

  @override
  bool get configurationPending => false;

  @override
  Future<FirebaseModelResponse> generate(FirebaseModelRequest request) =>
      Future<FirebaseModelResponse>.error(
        OcrFailure.of(OcrFailureKind.configuration),
      );
}

typedef OcrImageFileReader = Future<Uint8List> Function(File file);

typedef FirebaseGenerateForTest = Future<GenerateContentResponse> Function({
  required FirebaseAppCheck appCheck,
  required String model,
  required GenerationConfig config,
  required List<Content> prompt,
});

typedef FirebaseAppCheckProvider = FirebaseAppCheck Function();

FirebaseAI createFirebaseAiClient({required FirebaseAppCheck appCheck}) =>
    FirebaseAI.googleAI(appCheck: appCheck);

final class FirebaseSdkModelGateway implements FirebaseModelGateway {
  FirebaseSdkModelGateway({
    this.generateForTest,
    FirebaseAppCheckProvider? appCheckProvider,
  }) : _appCheckProvider =
           appCheckProvider ?? (() => FirebaseAppCheck.instance);

  static const modelName = 'gemini-3.8-flash';
  static const _transcriptionPrompt = '''
Transcribe only the visible text in this image.
Preserve the original line breaks exactly.
Do not guess obscured or unreadable text.
Do not correct spelling, grammar, punctuation, or formatting.
Do not translate the text.
Do not summarize or explain the text.
Return status "textDetected" with the transcription in "text" only when at least one visible character is readable.
Otherwise return status "noReadableText" and omit "text" or set it to null or an empty string.
''';

  final FirebaseGenerateForTest? generateForTest;
  final FirebaseAppCheckProvider _appCheckProvider;

  @override
  bool get configurationPending => false;

  @override
  Future<FirebaseModelResponse> generate(FirebaseModelRequest request) async {
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: <String, Schema>{
          'status': Schema.enumString(
            enumValues: const <String>['textDetected', 'noReadableText'],
          ),
          'text': Schema.string(nullable: true),
        },
        optionalProperties: const <String>['text'],
        propertyOrdering: const <String>['status', 'text'],
      ),
      thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.low),
    );
    final prompt = <Content>[
      Content.multi(<Part>[
        const TextPart(_transcriptionPrompt),
        InlineDataPart(request.mimeType, request.imageBytes),
      ]),
    ];
    final appCheck = _appCheckProvider();
    final response = generateForTest == null
        ? await createFirebaseAiClient(appCheck: appCheck)
              .generativeModel(model: modelName, generationConfig: config)
              .generateContent(prompt)
        : await generateForTest!(
            appCheck: appCheck,
            model: modelName,
            config: config,
            prompt: prompt,
          );

    final finishReason = response.candidates.firstOrNull?.finishReason;
    if (finishReason == FinishReason.safety ||
        response.promptFeedback?.blockReason == BlockReason.safety) {
      return const FirebaseModelResponse(
        finishReason: FirebaseModelFinishReason.safety,
      );
    }
    if (finishReason == FinishReason.recitation) {
      return const FirebaseModelResponse(
        finishReason: FirebaseModelFinishReason.recitation,
      );
    }
    return FirebaseModelResponse(text: response.text);
  }
}

final class FirebaseAiOcrService implements CloudOcrService {
  FirebaseAiOcrService({
    required this.gateway,
    OcrImageFileReader? readImageFile,
  }) : _readImageFile = readImageFile ?? _readImageBytes;

  static const maxImageBytes = 14 * 1024 * 1024;
  static const _maxImageDimension = 8192;
  static const _maxImagePixels = 32 * 1024 * 1024;

  final FirebaseModelGateway gateway;
  final OcrImageFileReader _readImageFile;

  @override
  bool get configurationPending => gateway.configurationPending;

  @override
  Future<OcrResult> recognize(String imagePath) async {
    try {
      final file = File(imagePath);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size <= 0 ||
          stat.size > maxImageBytes) {
        throw OcrFailure.of(OcrFailureKind.invalidInput);
      }

      final bytes = await _readImageFile(file);
      if (bytes.isEmpty || bytes.length > maxImageBytes) {
        throw OcrFailure.of(OcrFailureKind.invalidInput);
      }
      final mimeType = await Isolate.run(() => _validateImage(bytes));
      if (mimeType == null) {
        throw OcrFailure.of(OcrFailureKind.invalidInput);
      }

      final response = await gateway.generate(
        FirebaseModelRequest(imageBytes: bytes, mimeType: mimeType),
      );
      if (response.finishReason != null) {
        throw OcrFailure.of(OcrFailureKind.safetyOrRecitation);
      }
      return _parse(response.text);
    } on OcrFailure {
      rethrow;
    } on FileSystemException {
      throw OcrFailure.of(OcrFailureKind.invalidInput);
    } on InvalidApiKey {
      throw OcrFailure.of(OcrFailureKind.configuration);
    } on ServiceApiNotEnabled {
      throw OcrFailure.of(OcrFailureKind.configuration);
    } on UnsupportedUserLocation {
      throw OcrFailure.of(OcrFailureKind.unsupportedLocation);
    } on QuotaExceeded {
      throw OcrFailure.quota();
    } on FirebaseAISdkException {
      throw OcrFailure.invalidResponse();
    } on SocketException {
      throw OcrFailure.transportTransient();
    } on TimeoutException {
      throw OcrFailure.transportTransient();
    } on FirebaseModelTransientException {
      throw OcrFailure.transportTransient();
    } on ServerException {
      throw OcrFailure.of(OcrFailureKind.service);
    } on FirebaseAIException {
      throw OcrFailure.of(OcrFailureKind.service);
    } catch (_) {
      throw OcrFailure.of(OcrFailureKind.service);
    }
  }

  OcrResult _parse(String? source) {
    if (source == null || source.isEmpty) {
      throw OcrFailure.invalidResponse();
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw OcrFailure.invalidResponse();
    }
    if (decoded is! Map<String, dynamic>) {
      throw OcrFailure.invalidResponse();
    }
    final rawKeys = _topLevelObjectKeys(source);
    if (rawKeys == null || rawKeys.toSet().length != rawKeys.length) {
      throw OcrFailure.invalidResponse();
    }

    final status = decoded['status'];
    final keys = decoded.keys.toSet();
    if (status == 'textDetected' &&
        keys.length == 2 &&
        keys.containsAll(const <String>{'status', 'text'})) {
      final text = decoded['text'];
      if (text is String && text.trim().isNotEmpty) {
        return OcrResult.textDetected(text);
      }
    } else if (status == 'noReadableText' &&
        keys.difference(const <String>{'status', 'text'}).isEmpty) {
      final text = decoded['text'];
      if (text == null || text == '') {
        return const OcrResult.noReadableText();
      }
    }
    throw OcrFailure.invalidResponse();
  }
}

Future<Uint8List> _readImageBytes(File file) => file.readAsBytes();

String? _validateImage(Uint8List bytes) {
  try {
    final decoder = image.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (decoder == null ||
        info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width > FirebaseAiOcrService._maxImageDimension ||
        info.height > FirebaseAiOcrService._maxImageDimension ||
        info.width * info.height > FirebaseAiOcrService._maxImagePixels) {
      return null;
    }
    final mimeType = switch (decoder.format) {
      image.ImageFormat.jpg => 'image/jpeg',
      image.ImageFormat.png => 'image/png',
      image.ImageFormat.webp => 'image/webp',
      _ => null,
    };
    if (mimeType == null || decoder.decodeFrame(0) == null) {
      return null;
    }
    return mimeType;
  } catch (_) {
    return null;
  }
}

List<String>? _topLevelObjectKeys(String source) {
  var offset = _skipWhitespace(source, 0);
  if (offset >= source.length || source.codeUnitAt(offset) != 0x7b) {
    return null;
  }
  offset = _skipWhitespace(source, offset + 1);
  final keys = <String>[];
  if (offset < source.length && source.codeUnitAt(offset) == 0x7d) {
    return keys;
  }
  while (offset < source.length) {
    if (source.codeUnitAt(offset) != 0x22) {
      return null;
    }
    final keyEnd = _jsonStringEnd(source, offset);
    if (keyEnd == null) {
      return null;
    }
    final key = jsonDecode(source.substring(offset, keyEnd));
    if (key is! String) {
      return null;
    }
    keys.add(key);
    offset = _skipWhitespace(source, keyEnd);
    if (offset >= source.length || source.codeUnitAt(offset) != 0x3a) {
      return null;
    }
    offset = _skipJsonValue(source, _skipWhitespace(source, offset + 1));
    offset = _skipWhitespace(source, offset);
    if (offset >= source.length) {
      return null;
    }
    final delimiter = source.codeUnitAt(offset);
    if (delimiter == 0x7d) {
      return _skipWhitespace(source, offset + 1) == source.length ? keys : null;
    }
    if (delimiter != 0x2c) {
      return null;
    }
    offset = _skipWhitespace(source, offset + 1);
  }
  return null;
}

int _skipWhitespace(String source, int offset) {
  while (offset < source.length) {
    final code = source.codeUnitAt(offset);
    if (code != 0x20 && code != 0x0a && code != 0x0d && code != 0x09) {
      break;
    }
    offset += 1;
  }
  return offset;
}

int? _jsonStringEnd(String source, int offset) {
  var escaped = false;
  for (var index = offset + 1; index < source.length; index += 1) {
    final code = source.codeUnitAt(index);
    if (escaped) {
      escaped = false;
    } else if (code == 0x5c) {
      escaped = true;
    } else if (code == 0x22) {
      return index + 1;
    }
  }
  return null;
}

int _skipJsonValue(String source, int offset) {
  if (offset >= source.length) {
    return offset;
  }
  if (source.codeUnitAt(offset) == 0x22) {
    return _jsonStringEnd(source, offset) ?? source.length;
  }
  final opening = source.codeUnitAt(offset);
  if (opening != 0x7b && opening != 0x5b) {
    while (offset < source.length &&
        source.codeUnitAt(offset) != 0x2c &&
        source.codeUnitAt(offset) != 0x7d) {
      offset += 1;
    }
    return offset;
  }

  final stack = <int>[opening];
  var index = offset + 1;
  while (index < source.length && stack.isNotEmpty) {
    final code = source.codeUnitAt(index);
    if (code == 0x22) {
      index = _jsonStringEnd(source, index) ?? source.length;
      continue;
    }
    if (code == 0x7b || code == 0x5b) {
      stack.add(code);
    } else if ((code == 0x7d && stack.last == 0x7b) ||
        (code == 0x5d && stack.last == 0x5b)) {
      stack.removeLast();
    }
    index += 1;
  }
  return index;
}
