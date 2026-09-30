import 'dart:io';
import 'dart:typed_data';

import 'package:altinus_ocr/features/ocr/data/image_preparer.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  late Directory temporaryDirectory;
  late Directory derivativeDirectory;
  late BoundedImagePreparer preparer;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('preparer_');
    derivativeDirectory = Directory('${temporaryDirectory.path}/derivatives');
    preparer = BoundedImagePreparer(
      directoryProvider: () async => derivativeDirectory,
    );
  });

  tearDown(() => temporaryDirectory.delete(recursive: true));

  test('returns a small canonically oriented image unchanged', () async {
    final canonical = File('${temporaryDirectory.path}/canonical.jpg');
    await canonical.writeAsBytes(
      image.encodeJpg(image.Image(width: 40, height: 20)),
    );
    final originalBytes = await canonical.readAsBytes();

    final prepared = await preparer.prepare(canonical.path);

    expect(prepared.canonicalPath, canonical.path);
    expect(prepared.cloudPath, canonical.path);
    expect(await canonical.readAsBytes(), originalBytes);
    expect(await derivativeDirectory.exists(), isFalse);
  });

  test('bakes EXIF orientation and preserves the canonical file', () async {
    final source = image.Image(width: 30, height: 10)
      ..exif.imageIfd.orientation = 6;
    _paintMarker(source, left: true);
    final canonical = File('${temporaryDirectory.path}/rotated.jpg');
    await canonical.writeAsBytes(image.encodeJpg(source, quality: 95));
    final originalBytes = await canonical.readAsBytes();

    final prepared = await preparer.prepare(canonical.path);

    expect(prepared.canonicalPath, canonical.path);
    expect(prepared.cloudPath, isNot(canonical.path));
    expect(
      prepared.cloudPath.split(Platform.pathSeparator).last,
      startsWith('altinus_ocr_'),
    );
    final output = image.decodeImage(
      await File(prepared.cloudPath).readAsBytes(),
    );
    expect(output, isNotNull);
    expect(output!.width, 10);
    expect(output.height, 30);
    _expectRed(output.getPixel(7, 2));
    _expectDark(output.getPixel(1, 2));
    expect(output.exif.imageIfd.orientation, anyOf(isNull, 1));
    expect(await canonical.readAsBytes(), originalBytes);
  });

  test('bakes mirrored EXIF orientation in the correct direction', () async {
    final source = image.Image(width: 30, height: 10)
      ..exif.imageIfd.orientation = 2;
    _paintMarker(source, left: true);
    final canonical = File('${temporaryDirectory.path}/mirrored.jpg');
    await canonical.writeAsBytes(image.encodeJpg(source, quality: 95));

    final prepared = await preparer.prepare(canonical.path);

    final output = image.decodeImage(
      await File(prepared.cloudPath).readAsBytes(),
    )!;
    expect(output.width, 30);
    expect(output.height, 10);
    _expectRed(output.getPixel(27, 2));
    _expectDark(output.getPixel(2, 2));
    expect(output.exif.imageIfd.orientation, anyOf(isNull, 1));
  });

  test('resizes an over-14-MiB file proportionally below the bound', () async {
    final source = image.Image(width: 2400, height: 1200);
    for (var y = 0; y < source.height; y += 1) {
      for (var x = 0; x < source.width; x += 1) {
        source.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    final canonical = File('${temporaryDirectory.path}/oversized.jpg');
    final encoded = image.encodeJpg(source, quality: 100);
    await canonical.writeAsBytes(<int>[
      ...encoded,
      ...List<int>.filled(BoundedImagePreparer.maxUploadBytes, 0),
    ]);
    final canonicalLength = await canonical.length();

    final prepared = await preparer.prepare(canonical.path);

    final outputFile = File(prepared.cloudPath);
    final output = image.decodeImage(await outputFile.readAsBytes());
    expect(prepared.canonicalPath, canonical.path);
    expect(prepared.cloudPath, isNot(canonical.path));
    expect(
      await outputFile.length(),
      lessThan(BoundedImagePreparer.maxUploadBytes),
    );
    expect(output, isNotNull);
    expect(output!.width, lessThan(source.width));
    expect(output.width / output.height, closeTo(2, 0.02));
    expect(await canonical.length(), canonicalLength);
  });

  test('rejects missing and empty inputs before preparation', () async {
    await expectLater(
      preparer.prepare('${temporaryDirectory.path}/missing.jpg'),
      throwsFailure(OcrFailureKind.invalidInput),
    );
    final empty = File('${temporaryDirectory.path}/empty.jpg');
    await empty.create();
    await expectLater(
      preparer.prepare(empty.path),
      throwsFailure(OcrFailureKind.invalidInput),
    );
  });

  test('maps undecodable image data to preparation failure', () async {
    final invalid = File('${temporaryDirectory.path}/invalid.jpg');
    await invalid.writeAsString('not an image');

    await expectLater(
      preparer.prepare(invalid.path),
      throwsFailure(OcrFailureKind.preparation),
    );
  });

  test(
    'rejects an excessive source dimension before raster preparation',
    () async {
      final compressed = File('${temporaryDirectory.path}/wide.png');
      await compressed.writeAsBytes(
        image.encodePng(image.Image(width: 9000, height: 1)),
      );

      await expectLater(
        preparer.prepare(compressed.path),
        throwsFailure(OcrFailureKind.preparation),
      );

      expect(await derivativeDirectory.exists(), isFalse);
    },
  );

  test('removes a partial derivative when its async write fails', () async {
    final canonical = File('${temporaryDirectory.path}/rotated.jpg');
    final source = image.Image(width: 30, height: 10)
      ..exif.imageIfd.orientation = 6;
    await canonical.writeAsBytes(image.encodeJpg(source));
    preparer = BoundedImagePreparer(
      directoryProvider: () async => derivativeDirectory,
      writeDerivative: (file, bytes) async {
        await file.writeAsBytes(bytes.sublist(0, 4));
        throw const FileSystemException('injected write failure');
      },
    );

    await expectLater(
      preparer.prepare(canonical.path),
      throwsFailure(OcrFailureKind.preparation),
    );

    expect(await derivativeDirectory.list().toList(), isEmpty);
  });

  test(
    'rejects an excessive source byte size before reading the file',
    () async {
      final canonical = File('${temporaryDirectory.path}/too-large-source.jpg');
      await canonical.writeAsBytes(
        image.encodeJpg(image.Image(width: 2, height: 1)),
      );
      final handle = await canonical.open(mode: FileMode.append);
      await handle.setPosition(32 * 1024 * 1024);
      await handle.writeByte(0);
      await handle.close();

      await expectLater(
        preparer.prepare(canonical.path),
        throwsFailure(OcrFailureKind.preparation),
      );

      expect(await derivativeDirectory.exists(), isFalse);
    },
  );

  test('rechecks the actual bytes after an initially small stat', () async {
    final canonical = File('${temporaryDirectory.path}/growing.jpg');
    await canonical.writeAsBytes(
      image.encodeJpg(image.Image(width: 2, height: 1)),
    );
    preparer = BoundedImagePreparer(
      directoryProvider: () async => derivativeDirectory,
      readSource: (file) async =>
          Uint8List(BoundedImagePreparer.maxSourceBytes + 1),
    );

    await expectLater(
      preparer.prepare(canonical.path),
      throwsFailure(OcrFailureKind.preparation),
    );
  });

  test('exclusive allocation retries collision without overwriting', () async {
    final source = image.Image(width: 30, height: 10)
      ..exif.imageIfd.orientation = 6;
    final canonical = File('${temporaryDirectory.path}/rotated.jpg');
    await canonical.writeAsBytes(image.encodeJpg(source));
    await derivativeDirectory.create();
    final collision = await File(
      '${derivativeDirectory.path}/altinus_ocr_collision.jpg',
    ).writeAsString('keep');
    final names = <String>['collision', 'unique'].iterator;
    preparer = BoundedImagePreparer(
      directoryProvider: () async => derivativeDirectory,
      derivativeName: () {
        names.moveNext();
        return names.current;
      },
    );

    final prepared = await preparer.prepare(canonical.path);

    expect(await collision.readAsString(), 'keep');
    expect(
      prepared.cloudPath,
      '${derivativeDirectory.path}/altinus_ocr_unique.jpg',
    );
  });
}

void _paintMarker(image.Image source, {required bool left}) {
  final startX = left ? 0 : source.width - 8;
  for (var y = 0; y < 8; y += 1) {
    for (var x = startX; x < startX + 8; x += 1) {
      source.setPixelRgb(x, y, 255, 0, 0);
    }
  }
}

void _expectRed(image.Pixel pixel) {
  expect(pixel.r, greaterThan(180));
  expect(pixel.g, lessThan(80));
  expect(pixel.b, lessThan(80));
}

void _expectDark(image.Pixel pixel) {
  expect(pixel.r, lessThan(80));
  expect(pixel.g, lessThan(80));
  expect(pixel.b, lessThan(80));
}

Matcher throwsFailure(OcrFailureKind kind) =>
    throwsA(isA<OcrFailure>().having((failure) => failure.kind, 'kind', kind));
