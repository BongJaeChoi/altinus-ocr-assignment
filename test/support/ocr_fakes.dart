import 'dart:async';

import 'package:altinus_ocr/features/camera/camera_models.dart';
import 'package:altinus_ocr/features/camera/camera_repository.dart';
import 'package:altinus_ocr/features/disclosure/disclosure_store.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_ports.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';

final class ControllableCloudOcrService implements CloudOcrService {
  final List<String> paths = [];
  final List<Completer<OcrResult>> requests = [];

  @override
  Future<OcrResult> recognize(String imagePath) {
    paths.add(imagePath);
    final request = Completer<OcrResult>();
    requests.add(request);
    return request.future;
  }

  void complete(int index, OcrResult result) {
    requests[index].complete(result);
  }

  void fail(int index, Object error) {
    requests[index].completeError(error);
  }
}

final class ControllableLocalOcrService implements LocalOcrService {
  final List<String> paths = [];
  final List<Completer<OcrResult>> requests = [];

  @override
  Future<OcrResult> recognize(String imagePath) {
    paths.add(imagePath);
    final request = Completer<OcrResult>();
    requests.add(request);
    return request.future;
  }

  void complete(int index, OcrResult result) {
    requests[index].complete(result);
  }

  void fail(int index, Object error) {
    requests[index].completeError(error);
  }
}

final class ControllableCameraRepository implements CameraRepository {
  ControllableCameraRepository({
    this.permission = CameraPermissionState.granted,
    this.flashSupported = true,
    this.holdInitialize = false,
    this.holdDispose = false,
    this.initializeError,
    this.disposeError,
  });

  CameraPermissionState permission;
  bool flashSupported;
  bool holdInitialize;
  bool holdDispose;
  Object? initializeError;
  Object? disposeError;
  int initializeCount = 0;
  int activeInitializationCount = 0;
  int maxConcurrentInitializationCount = 0;
  int liveSessionCount = 0;
  int captureCount = 0;
  int disposeCount = 0;
  final List<Completer<CapturedImage>> captures = [];
  final List<_HeldInitialization> _pendingInitializations = [];
  final List<Completer<void>> _pendingDisposals = [];
  final List<CameraFlashMode> flashModes = [];

  @override
  Future<CameraPermissionState> initialize() async {
    initializeCount += 1;
    activeInitializationCount += 1;
    if (activeInitializationCount > maxConcurrentInitializationCount) {
      maxConcurrentInitializationCount = activeInitializationCount;
    }
    _HeldInitialization? pending;
    try {
      if (holdInitialize) {
        pending = _HeldInitialization();
        _pendingInitializations.add(pending);
        await pending.completer.future;
      }
      if (initializeError case final error?) {
        throw error;
      }
      if (pending?.cancelled != true) {
        liveSessionCount += 1;
      }
      return permission;
    } finally {
      activeInitializationCount -= 1;
      pending?.settled.complete();
    }
  }

  void completeInitialize(int index) =>
      _pendingInitializations[index].completer.complete();

  bool wasInitializeCancelled(int index) =>
      _pendingInitializations[index].cancelled;

  void completeDispose(int index) => _pendingDisposals[index].complete();

  @override
  Future<CapturedImage> capture() {
    captureCount += 1;
    final capture = Completer<CapturedImage>();
    captures.add(capture);
    return capture.future;
  }

  void completeCapture(int index, String path) {
    captures[index].complete(CapturedImage(path));
  }

  void failCapture(int index, Object error) {
    captures[index].completeError(error);
  }

  @override
  Future<bool> supportsFlash() async => flashSupported;

  @override
  Future<void> setFlash(CameraFlashMode mode) async {
    flashModes.add(mode);
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    if (disposeError case final error?) {
      throw error;
    }
    if (holdDispose) {
      final pending = Completer<void>();
      _pendingDisposals.add(pending);
      await pending.future;
    }
    liveSessionCount = 0;
    final pending = List<_HeldInitialization>.of(_pendingInitializations);
    for (final initialization in pending) {
      if (!initialization.settled.isCompleted) {
        initialization.cancelled = true;
        if (!initialization.completer.isCompleted) {
          initialization.completer.complete();
        }
      }
    }
    await Future.wait<void>(
      pending
          .where((initialization) => !initialization.settled.isCompleted)
          .map((initialization) => initialization.settled.future),
    );
  }
}

final class _HeldInitialization {
  final Completer<void> completer = Completer<void>();
  final Completer<void> settled = Completer<void>();
  bool cancelled = false;
}

final class MemoryDisclosureStore implements DisclosureStore {
  MemoryDisclosureStore({
    required this.accepted,
    this.holdHasAccepted = false,
    this.holdAccept = false,
    this.hasAcceptedError,
    this.acceptError,
  });

  bool accepted;
  bool holdHasAccepted;
  bool holdAccept;
  Object? hasAcceptedError;
  Object? acceptError;
  int hasAcceptedCount = 0;
  int acceptCount = 0;
  final List<Completer<void>> pendingHasAccepted = [];
  final List<Completer<void>> pendingAccepts = [];

  @override
  Future<bool> hasAccepted() async {
    hasAcceptedCount += 1;
    if (hasAcceptedError case final error?) {
      throw error;
    }
    if (holdHasAccepted) {
      final pending = Completer<void>();
      pendingHasAccepted.add(pending);
      await pending.future;
    }
    return accepted;
  }

  @override
  Future<void> accept() async {
    acceptCount += 1;
    if (acceptError case final error?) {
      throw error;
    }
    if (holdAccept) {
      final pending = Completer<void>();
      pendingAccepts.add(pending);
      await pending.future;
    }
    accepted = true;
  }

  void completeHasAccepted(int index) => pendingHasAccepted[index].complete();

  void completeAccept(int index) => pendingAccepts[index].complete();
}

final class ControllableImagePreparer implements ImagePreparer {
  ControllableImagePreparer({this.completeImmediately = true});

  bool completeImmediately;
  final List<String> canonicalPaths = [];
  final List<Completer<PreparedImage>> preparations = [];

  @override
  Future<PreparedImage> prepare(String canonicalPath) {
    canonicalPaths.add(canonicalPath);
    if (completeImmediately) {
      return Future.value(
        PreparedImage(
          canonicalPath: canonicalPath,
          cloudPath: '$canonicalPath.prepared',
        ),
      );
    }
    final preparation = Completer<PreparedImage>();
    preparations.add(preparation);
    return preparation.future;
  }

  void complete(int index, {required String canonicalPath, String? cloudPath}) {
    preparations[index].complete(
      PreparedImage(
        canonicalPath: canonicalPath,
        cloudPath: cloudPath ?? '$canonicalPath.prepared',
      ),
    );
  }

  void fail(int index, Object error) {
    preparations[index].completeError(error);
  }
}

final class RecordingTransactionFiles implements TransactionFiles {
  RecordingTransactionFiles({
    this.completeImmediately = true,
    this.cleanupError,
    this.holdCleanupOrphans = false,
    this.cleanupOrphansError,
  });

  bool completeImmediately;
  Object? cleanupError;
  bool holdCleanupOrphans;
  Object? cleanupOrphansError;
  final List<Object?> cleanupOutcomes = [];
  final List<List<String>> cleanupCalls = [];
  final List<Completer<void>> pendingCleanups = [];
  int cleanupOrphansCount = 0;
  final List<Completer<void>> pendingOrphanCleanups = [];

  Iterable<String> get cleanedPaths => cleanupCalls.expand((paths) => paths);

  @override
  Future<void> cleanup(Iterable<String> paths) async {
    cleanupCalls.add(List<String>.of(paths));
    if (cleanupOutcomes.isNotEmpty) {
      final outcome = cleanupOutcomes.removeAt(0);
      if (outcome != null) {
        throw outcome;
      }
    }
    if (cleanupError case final error?) {
      throw error;
    }
    if (!completeImmediately) {
      final cleanup = Completer<void>();
      pendingCleanups.add(cleanup);
      await cleanup.future;
    }
  }

  void completeCleanup(int index) => pendingCleanups[index].complete();

  @override
  Future<void> cleanupOrphans() async {
    cleanupOrphansCount += 1;
    if (cleanupOrphansError case final error?) {
      throw error;
    }
    if (holdCleanupOrphans) {
      final pending = Completer<void>();
      pendingOrphanCleanups.add(pending);
      await pending.future;
    }
  }

  void completeOrphanCleanup(int index) {
    pendingOrphanCleanups[index].complete();
  }
}

final class RecordingAppSettingsLauncher implements AppSettingsLauncher {
  bool result = true;
  bool holdOpen = false;
  Object? openError;
  int openCount = 0;
  final List<Completer<void>> pendingOpens = [];

  @override
  Future<bool> open() async {
    openCount += 1;
    if (openError case final error?) {
      throw error;
    }
    if (holdOpen) {
      final pending = Completer<void>();
      pendingOpens.add(pending);
      await pending.future;
    }
    return result;
  }

  void completeOpen(int index) => pendingOpens[index].complete();

  void failOpen(int index, Object error) {
    pendingOpens[index].completeError(error);
  }
}
