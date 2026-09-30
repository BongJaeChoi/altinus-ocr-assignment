import 'dart:io';

import 'package:altinus_ocr/features/ocr/data/temp_image_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory parentDirectory;
  late Directory controlledDirectory;
  late Directory cameraDirectory;
  late TempImageStore store;

  setUp(() async {
    parentDirectory = await Directory.systemTemp.createTemp('image_store_');
    controlledDirectory = Directory('${parentDirectory.path}/controlled');
    cameraDirectory = Directory('${parentDirectory.path}/system-temp/camera');
    await controlledDirectory.create();
    await cameraDirectory.create(recursive: true);
    store = TempImageStore(
      directoryProvider: () async => controlledDirectory,
      cameraDirectoryProvider: () async => cameraDirectory,
    );
  });

  tearDown(() => parentDirectory.delete(recursive: true));

  test(
    'cleanup deletes only explicit files inside the controlled directory',
    () async {
      final owned = await File('${controlledDirectory.path}/capture.jpg')
          .writeAsString('owned');
      final unlisted = await File('${controlledDirectory.path}/keep.jpg')
          .writeAsString('keep');
      final outside = await File('${parentDirectory.path}/outside.jpg')
          .writeAsString('outside');

      await store.cleanup(<String>[owned.path]);
      await store.cleanup(<String>[owned.path]);

      expect(await owned.exists(), isFalse);
      expect(await unlisted.exists(), isTrue);
      expect(await outside.exists(), isTrue);
    },
  );

  test('explicit cleanup deletes a pinned iOS camera capture', () async {
    final pictures = Directory('${cameraDirectory.path}/pictures');
    await pictures.create();
    final capture = await File('${pictures.path}/capture.jpg')
        .writeAsString('capture');

    await store.cleanup(<String>[capture.path]);

    expect(await capture.exists(), isFalse);
  });

  test('explicit cleanup rejects paths outside both private roots', () async {
    final outside = await File('${parentDirectory.path}/outside.jpg')
        .writeAsString('outside');

    await expectLater(
      store.cleanup(<String>[
        outside.path,
        '${controlledDirectory.path}/../outside.jpg',
      ]),
      throwsA(isA<TempImageCleanupException>()),
    );

    expect(await outside.exists(), isTrue);
  });

  test('startup cleanup deletes only prefixed orphan files', () async {
    final orphan = await File('${controlledDirectory.path}/altinus_ocr_old.jpg')
        .writeAsString('orphan');
    final unrelated = await File('${controlledDirectory.path}/camera.jpg')
        .writeAsString('keep');
    final outside = await File(
      '${parentDirectory.path}/altinus_ocr_outside.jpg',
    ).writeAsString('outside');
    final cameraPrefixed = await File(
      '${cameraDirectory.path}/altinus_ocr_camera.jpg',
    ).writeAsString('camera');
    final cameraCapture = await File('${cameraDirectory.path}/capture.jpg')
        .writeAsString('camera');

    await store.cleanupOrphans();
    await store.cleanupOrphans();

    expect(await orphan.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    expect(await outside.exists(), isTrue);
    expect(await cameraPrefixed.exists(), isTrue);
    expect(await cameraCapture.exists(), isTrue);
  });

  test(
    'does not follow a prefixed symlink outside the controlled directory',
    () async {
      final outside = await File('${parentDirectory.path}/outside.jpg')
          .writeAsString('outside');
      final link = Link('${controlledDirectory.path}/altinus_ocr_link.jpg');
      await link.create(outside.path);

      await store.cleanupOrphans();
      await expectLater(
        store.cleanup(<String>[link.path]),
        throwsA(isA<TempImageCleanupException>()),
      );

      expect(await outside.exists(), isTrue);
    },
  );

  test(
    'does not traverse an in-scope directory symlink to an outside file',
    () async {
      final outsideDirectory = Directory('${parentDirectory.path}/outside')
        ..createSync();
      final outside = await File('${outsideDirectory.path}/capture.jpg')
          .writeAsString('outside');
      final linkedDirectory = Link('${controlledDirectory.path}/linked');
      await linkedDirectory.create(outsideDirectory.path);

      await expectLater(
        store.cleanup(<String>['${linkedDirectory.path}/capture.jpg']),
        throwsA(isA<TempImageCleanupException>()),
      );

      expect(await outside.exists(), isTrue);
    },
  );

  test('rejects a controlled root that is itself a symlink', () async {
    final outsideDirectory = Directory('${parentDirectory.path}/outside-root')
      ..createSync();
    final outside = await File('${outsideDirectory.path}/capture.jpg')
        .writeAsString('outside');
    final linkedRoot = Link('${parentDirectory.path}/linked-root');
    await linkedRoot.create(outsideDirectory.path);
    final linkedStore = TempImageStore(
      directoryProvider: () async => Directory(linkedRoot.path),
      cameraDirectoryProvider: () async => cameraDirectory,
    );

    await expectLater(
      linkedStore.cleanup(<String>['${linkedRoot.path}/capture.jpg']),
      throwsA(isA<TempImageCleanupException>()),
    );

    expect(await outside.exists(), isTrue);
  });

  test(
    'a path swapped after resolution cannot delete its outside target',
    () async {
      final owned = await File('${controlledDirectory.path}/capture.jpg')
          .writeAsString('owned');
      final outside = await File('${parentDirectory.path}/outside.jpg')
          .writeAsString('outside');
      final swappingStore = TempImageStore(
        directoryProvider: () async => controlledDirectory,
        cameraDirectoryProvider: () async => cameraDirectory,
        beforeDelete: (originalPath, resolvedPath) async {
          expect(originalPath, owned.path);
          expect(resolvedPath, await owned.resolveSymbolicLinks());
          await owned.delete();
          await Link(owned.path).create(outside.path);
        },
      );

      await expectLater(
        swappingStore.cleanup(<String>[owned.path]),
        throwsA(isA<TempImageCleanupException>()),
      );

      expect(await outside.exists(), isTrue);
    },
  );

  test('unexpected explicit cleanup failures propagate', () async {
    final owned = await File('${controlledDirectory.path}/capture.jpg')
        .writeAsString('owned');
    final failure = StateError('injected cleanup failure');
    final failingStore = TempImageStore(
      directoryProvider: () async => controlledDirectory,
      cameraDirectoryProvider: () async => cameraDirectory,
      beforeDelete: (originalPath, resolvedPath) async => throw failure,
    );

    await expectLater(
      failingStore.cleanup(<String>[owned.path]),
      throwsA(failure),
    );
    expect(await owned.exists(), isTrue);
  });
}
