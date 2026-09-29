import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../domain/ocr_ports.dart';
import 'image_preparer.dart';

typedef CleanupBeforeDelete = Future<void> Function(
  String originalPath,
  String resolvedPath,
);

final class TempImageCleanupException implements Exception {
  const TempImageCleanupException();
}

final class TempImageStore implements TransactionFiles {
  TempImageStore({
    OcrTempDirectoryProvider? directoryProvider,
    OcrTempDirectoryProvider? cameraDirectoryProvider,
    this.beforeDelete,
  }) : _directoryProvider = directoryProvider ?? getTemporaryDirectory,
       _cameraDirectoryProvider =
           cameraDirectoryProvider ?? _defaultCameraDirectory;

  static const derivativePrefix = 'altinus_ocr_';

  final OcrTempDirectoryProvider _directoryProvider;
  final OcrTempDirectoryProvider _cameraDirectoryProvider;
  final CleanupBeforeDelete? beforeDelete;

  @override
  Future<void> cleanup(Iterable<String> paths) async {
    final roots = <Directory>[
      await _directoryProvider(),
      await _cameraDirectoryProvider(),
    ];
    for (final candidate in paths.toSet()) {
      await _deleteExplicitFile(roots, candidate);
    }
  }

  @override
  Future<void> cleanupOrphans() async {
    final root = await _directoryProvider();
    if (!await root.exists()) {
      return;
    }
    await for (final entity in root.list(followLinks: false)) {
      if (entity is File &&
          path.basename(entity.path).startsWith(derivativePrefix)) {
        await _deleteStartupOrphan(root, entity.path);
      }
    }
  }

  Future<void> _deleteExplicitFile(
    List<Directory> roots,
    String candidate,
  ) async {
    final candidatePath = path.normalize(path.absolute(candidate));
    Directory? root;
    for (final allowedRoot in roots) {
      final rootPath = path.normalize(path.absolute(allowedRoot.path));
      if (path.isWithin(rootPath, candidatePath)) {
        root = allowedRoot;
        break;
      }
    }
    if (root == null) {
      throw const TempImageCleanupException();
    }

    final type = await FileSystemEntity.type(candidatePath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return;
    }
    if (type != FileSystemEntityType.file) {
      throw const TempImageCleanupException();
    }

    await _verifyNoLinks(root, candidatePath);
    final resolvedRoot = path.normalize(await root.resolveSymbolicLinks());
    final resolvedCandidate = path.normalize(
      await File(candidatePath).resolveSymbolicLinks(),
    );
    if (!path.isWithin(resolvedRoot, resolvedCandidate)) {
      throw const TempImageCleanupException();
    }

    await beforeDelete?.call(candidate, resolvedCandidate);

    // These roots are private mobile sandbox directories. Portable Dart cannot
    // make hostile ancestor replacement and deletion atomic, so revalidate and
    // delete the already-resolved file path, failing closed on any identity
    // change visible before deletion.
    await _verifyNoLinks(root, candidatePath);
    final currentResolvedRoot = path.normalize(
      await root.resolveSymbolicLinks(),
    );
    if (currentResolvedRoot != resolvedRoot) {
      throw const TempImageCleanupException();
    }
    final currentType = await FileSystemEntity.type(
      resolvedCandidate,
      followLinks: false,
    );
    if (currentType != FileSystemEntityType.file) {
      throw const TempImageCleanupException();
    }
    final currentResolved = path.normalize(
      await File(resolvedCandidate).resolveSymbolicLinks(),
    );
    if (currentResolved != resolvedCandidate) {
      throw const TempImageCleanupException();
    }
    await File(resolvedCandidate).delete();
  }

  Future<void> _deleteStartupOrphan(Directory root, String candidate) async {
    final candidatePath = path.normalize(path.absolute(candidate));
    final rootPath = path.normalize(path.absolute(root.path));
    if (!path.isWithin(rootPath, candidatePath) ||
        path.dirname(candidatePath) != rootPath ||
        !path.basename(candidatePath).startsWith(derivativePrefix)) {
      return;
    }
    if (await FileSystemEntity.type(candidatePath, followLinks: false) !=
        FileSystemEntityType.file) {
      return;
    }
    await _verifyNoLinks(root, candidatePath);
    final resolvedRoot = path.normalize(await root.resolveSymbolicLinks());
    final resolvedCandidate = path.normalize(
      await File(candidatePath).resolveSymbolicLinks(),
    );
    if (!path.isWithin(resolvedRoot, resolvedCandidate)) {
      return;
    }
    await File(resolvedCandidate).delete();
  }

  Future<void> _verifyNoLinks(Directory root, String candidatePath) async {
    final rootPath = path.normalize(path.absolute(root.path));
    if (await FileSystemEntity.type(rootPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const TempImageCleanupException();
    }
    final relative = path.relative(candidatePath, from: rootPath);
    var current = rootPath;
    final components = path.split(relative);
    for (var index = 0; index < components.length; index += 1) {
      current = path.join(current, components[index]);
      final type = await FileSystemEntity.type(current, followLinks: false);
      final isLast = index == components.length - 1;
      if (type == FileSystemEntityType.link ||
          (isLast && type != FileSystemEntityType.file) ||
          (!isLast && type != FileSystemEntityType.directory)) {
        throw const TempImageCleanupException();
      }
    }
  }
}

Future<Directory> _defaultCameraDirectory() async =>
    Directory(path.join(Directory.systemTemp.path, 'camera'));
