import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../domain/ocr_failure.dart';
import '../domain/ocr_ports.dart';

typedef OcrTempDirectoryProvider = Future<Directory> Function();
typedef DerivativeWriter = Future<void> Function(File file, Uint8List bytes);
typedef ImageSourceReader = Future<Uint8List> Function(File file);
typedef DerivativeNameGenerator = String Function();

final class BoundedImagePreparer implements ImagePreparer {
  BoundedImagePreparer({
    OcrTempDirectoryProvider? directoryProvider,
    DerivativeWriter? writeDerivative,
    ImageSourceReader? readSource,
    DerivativeNameGenerator? derivativeName,
  }) : _directoryProvider = directoryProvider ?? getTemporaryDirectory,
       _writeDerivative = writeDerivative ?? _writeDerivativeBytes,
       _readSource = readSource ?? _readSourceBytes,
       _derivativeName = derivativeName ?? _randomDerivativeName;

  static const maxUploadBytes = 14 * 1024 * 1024;
  static const maxSourceBytes = 32 * 1024 * 1024;
  static const _maxSourceDimension = 8192;
  static const _maxSourcePixels = 32 * 1024 * 1024;
  static const _maxDimension = 2560;
  static const _qualityAttempts = <int>[88, 78, 68, 58, 48, 38];

  final OcrTempDirectoryProvider _directoryProvider;
  final DerivativeWriter _writeDerivative;
  final ImageSourceReader _readSource;
  final DerivativeNameGenerator _derivativeName;

  @override
  Future<PreparedImage> prepare(String canonicalPath) async {
    if (canonicalPath.trim().isEmpty) {
      throw OcrFailure.of(OcrFailureKind.invalidInput);
    }
    final canonical = File(canonicalPath);
    final FileStat stat;
    try {
      stat = await canonical.stat();
    } on FileSystemException {
      throw OcrFailure.of(OcrFailureKind.invalidInput);
    }
    if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
      throw OcrFailure.of(OcrFailureKind.invalidInput);
    }
    if (stat.size > maxSourceBytes) {
      throw OcrFailure.of(OcrFailureKind.preparation);
    }

    final Uint8List sourceBytes;
    try {
      sourceBytes = await _readSource(canonical);
    } on FileSystemException {
      throw OcrFailure.of(OcrFailureKind.invalidInput);
    }
    if (sourceBytes.isEmpty) {
      throw OcrFailure.of(OcrFailureKind.invalidInput);
    }
    if (sourceBytes.length > maxSourceBytes) {
      throw OcrFailure.of(OcrFailureKind.preparation);
    }

    final _PreparedBytes prepared;
    try {
      prepared = await Isolate.run(
        () => _prepareBytes(
          _PrepareRequest(
            sourceBytes: sourceBytes,
            sourceWasOversized: sourceBytes.length > maxUploadBytes,
          ),
        ),
      );
    } on OcrFailure {
      rethrow;
    } catch (_) {
      throw OcrFailure.of(OcrFailureKind.preparation);
    }

    if (prepared.bytes == null) {
      return PreparedImage(
        canonicalPath: canonicalPath,
        cloudPath: canonicalPath,
      );
    }

    File? derivative;
    try {
      final directory = await _directoryProvider();
      await directory.create(recursive: true);
      derivative = await _allocateDerivative(directory, _derivativeName);
      await _writeDerivative(derivative, prepared.bytes!);
      if (await derivative.length() >= maxUploadBytes) {
        await derivative.delete();
        throw OcrFailure.of(OcrFailureKind.preparation);
      }
      return PreparedImage(
        canonicalPath: canonicalPath,
        cloudPath: derivative.path,
      );
    } catch (_) {
      if (derivative != null) {
        await _deletePartialDerivative(derivative);
      }
      throw OcrFailure.of(OcrFailureKind.preparation);
    }
  }
}

final class _PrepareRequest {
  const _PrepareRequest({
    required this.sourceBytes,
    required this.sourceWasOversized,
  });

  final Uint8List sourceBytes;
  final bool sourceWasOversized;
}

final class _PreparedBytes {
  const _PreparedBytes(this.bytes);

  final Uint8List? bytes;
}

_PreparedBytes _prepareBytes(_PrepareRequest request) {
  final decoder = image.findDecoderForData(request.sourceBytes);
  final info = decoder?.startDecode(request.sourceBytes);
  if (decoder == null ||
      info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width > BoundedImagePreparer._maxSourceDimension ||
      info.height > BoundedImagePreparer._maxSourceDimension ||
      info.width * info.height > BoundedImagePreparer._maxSourcePixels) {
    throw OcrFailure.of(OcrFailureKind.preparation);
  }
  final jpegOrientation = _isJpeg(request.sourceBytes)
      ? image.decodeJpgExif(request.sourceBytes)?.imageIfd.orientation
      : null;
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) {
    throw OcrFailure.of(OcrFailureKind.preparation);
  }
  final needsOrientationBake =
      (jpegOrientation != null && jpegOrientation != 1) ||
      (decoded.exif.imageIfd.hasOrientation &&
          decoded.exif.imageIfd.orientation != 1);
  if (!request.sourceWasOversized && !needsOrientationBake) {
    return const _PreparedBytes(null);
  }

  // The image package's JPEG decoder applies EXIF orientation while decoding.
  // Other decoders retain orientation metadata and need an explicit bake.
  var working = jpegOrientation != null
      ? decoded
      : needsOrientationBake
      ? image.bakeOrientation(decoded)
      : decoded;
  if (request.sourceWasOversized) {
    final largestDimension = max(working.width, working.height);
    final initialDimension = min(
      BoundedImagePreparer._maxDimension,
      max(1, (largestDimension * 0.85).floor()),
    );
    if (initialDimension < largestDimension) {
      working = _resizeLongestEdge(working, initialDimension);
    }
  }

  var dimensionLimit = max(working.width, working.height);
  for (var scaleAttempt = 0; scaleAttempt < 5; scaleAttempt += 1) {
    final candidate = dimensionLimit < max(working.width, working.height)
        ? _resizeLongestEdge(working, dimensionLimit)
        : working;
    for (final quality in BoundedImagePreparer._qualityAttempts) {
      final bytes = image.encodeJpg(candidate, quality: quality);
      if (bytes.length < BoundedImagePreparer.maxUploadBytes) {
        return _PreparedBytes(bytes);
      }
    }
    dimensionLimit = max(1, (dimensionLimit * 0.75).floor());
  }
  throw OcrFailure.of(OcrFailureKind.preparation);
}

bool _isJpeg(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;

image.Image _resizeLongestEdge(image.Image source, int longestEdge) {
  if (source.width >= source.height) {
    return image.copyResize(source, width: longestEdge);
  }
  return image.copyResize(source, height: longestEdge);
}

Future<void> _writeDerivativeBytes(File file, Uint8List bytes) async {
  await file.writeAsBytes(bytes, flush: true);
}

Future<Uint8List> _readSourceBytes(File file) => file.readAsBytes();

final Random _secureRandom = Random.secure();

String _randomDerivativeName() => List<String>.generate(
  16,
  (_) => _secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

Future<File> _allocateDerivative(
  Directory directory,
  DerivativeNameGenerator nameGenerator,
) async {
  for (var attempt = 0; attempt < 8; attempt += 1) {
    final candidate = File(
      path.join(directory.path, 'altinus_ocr_${nameGenerator()}.jpg'),
    );
    try {
      return await candidate.create(exclusive: true);
    } on FileSystemException {
      if (await candidate.exists()) {
        continue;
      }
      rethrow;
    }
  }
  throw OcrFailure.of(OcrFailureKind.preparation);
}

Future<void> _deletePartialDerivative(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } on FileSystemException {
    // A later startup orphan sweep retries deletion of the prefixed file.
  }
}
