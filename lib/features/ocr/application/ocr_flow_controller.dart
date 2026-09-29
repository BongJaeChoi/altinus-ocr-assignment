import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/camera_models.dart';
import '../../camera/camera_repository.dart';
import '../../disclosure/disclosure_store.dart';
import '../domain/ocr_engine.dart';
import '../domain/ocr_failure.dart';
import '../domain/ocr_ports.dart';
import '../domain/ocr_result.dart';
import 'ocr_flow_state.dart';
import 'ocr_providers.dart';

final ocrFlowControllerProvider =
    NotifierProvider<OcrFlowController, OcrFlowState>(
      OcrFlowController.new,
      dependencies: [
        cameraRepositoryProvider,
        disclosureStoreProvider,
        cloudOcrServiceProvider,
        localOcrServiceProvider,
        imagePreparerProvider,
        transactionFilesProvider,
        appSettingsLauncherProvider,
        ocrNowProvider,
        ocrRetryDelayProvider,
      ],
      isAutoDispose: true,
    );

final class OcrFlowController extends Notifier<OcrFlowState> {
  static const _slowThreshold = Duration(seconds: 10);
  static const _cloudDeadline = Duration(seconds: 60);

  Timer? _slowTimer;
  Timer? _deadlineTimer;
  int _nextTransactionId = 0;
  int _nextEntryToken = 0;
  int? _activeTransactionId;
  int? _activeFileOwnerId;
  int? _retainedCanonicalOwnerId;
  int? _startToken;
  int? _acceptDisclosureToken;
  int? _pendingCaptureOwnerId;
  _PathProduction? _pendingCaptureProduction;

  late CameraRepository _camera;
  late DisclosureStore _disclosure;
  late CloudOcrService _cloudOcr;
  late LocalOcrService _localOcr;
  late ImagePreparer _imagePreparer;
  late TransactionFiles _transactionFiles;
  late AppSettingsLauncher _settingsLauncher;
  late OcrNow _now;
  late OcrRetryDelay _retryDelay;
  late _OwnedTransactionFiles _ownedFiles;

  int _cameraOperationId = 0;
  Future<void>? _cameraTeardownFuture;
  bool _captureInFlight = false;
  bool _flashInFlight = false;
  bool _cameraReady = false;
  bool _flashSupported = false;
  CameraFlashMode _flashMode = CameraFlashMode.auto;
  bool _cameraNeedsDispose = false;
  bool _needsPreviewOnResume = false;
  bool _needsBootOnResume = false;
  bool _disposed = false;
  String? _canonicalPath;

  @override
  OcrFlowState build() {
    _camera = ref.watch(cameraRepositoryProvider);
    _disclosure = ref.watch(disclosureStoreProvider);
    _cloudOcr = ref.watch(cloudOcrServiceProvider);
    _localOcr = ref.watch(localOcrServiceProvider);
    _imagePreparer = ref.watch(imagePreparerProvider);
    _transactionFiles = ref.watch(transactionFilesProvider);
    _settingsLauncher = ref.watch(appSettingsLauncherProvider);
    _now = ref.watch(ocrNowProvider);
    _retryDelay = ref.watch(ocrRetryDelayProvider);
    _ownedFiles = _OwnedTransactionFiles(_transactionFiles);
    ref.onDispose(_disposeOwnedResources);
    return const Booting();
  }

  Future<void> start() async {
    if (state is! Booting || _startToken != null) {
      return;
    }
    final token = ++_nextEntryToken;
    _startToken = token;
    final operationId = ++_cameraOperationId;
    try {
      await _transactionFiles.cleanupOrphans();
      if (!_ownsStart(token, operationId)) {
        return;
      }

      final accepted = await _disclosure.hasAccepted();
      if (!_ownsStart(token, operationId)) {
        return;
      }
      if (!accepted) {
        state = const DisclosureRequired();
        return;
      }
      await _initializeCamera();
    } catch (error) {
      if (_ownsStart(token, operationId)) {
        state = RecoverableError(failure: _domainFailure(error));
      }
    } finally {
      if (_startToken == token) {
        _startToken = null;
      }
    }
  }

  Future<void> acceptDisclosure() async {
    if (state is! DisclosureRequired || _acceptDisclosureToken != null) {
      return;
    }
    final token = ++_nextEntryToken;
    _acceptDisclosureToken = token;
    final operationId = ++_cameraOperationId;
    try {
      await _disclosure.accept();
      if (!_ownsDisclosureAcceptance(token, operationId)) {
        return;
      }
      await _initializeCamera();
    } catch (error) {
      if (_ownsDisclosureAcceptance(token, operationId)) {
        state = RecoverableError(failure: _domainFailure(error));
      }
    } finally {
      if (_acceptDisclosureToken == token) {
        _acceptDisclosureToken = null;
      }
    }
  }

  Future<void> capture() async {
    if (_captureInFlight ||
        _flashInFlight ||
        _ownedFiles.cleanupInFlight ||
        state is! PreviewReady) {
      return;
    }

    _captureInFlight = true;
    final operationId = ++_cameraOperationId;
    final fileOwnerId = _ownedFiles.createOwner();
    final pathProduction = _ownedFiles.beginProduction(fileOwnerId);
    _pendingCaptureOwnerId = fileOwnerId;
    _pendingCaptureProduction = pathProduction;
    int? transactionId;
    state = Capturing(transactionId: 'capture-$operationId');

    try {
      final image = await _camera.capture();
      _ownedFiles.record(fileOwnerId, image.path);
      _ownedFiles.settleProduction(pathProduction);
      _clearPendingCapture(pathProduction);
      if (!_ownsCameraOperation(operationId)) {
        await _cleanupStaleOwner(fileOwnerId);
        return;
      }

      transactionId = ++_nextTransactionId;
      _activeTransactionId = transactionId;
      _activeFileOwnerId = fileOwnerId;
      _retainedCanonicalOwnerId = fileOwnerId;
      _canonicalPath = image.path;
      final startedAt = _now();
      state = RecognizingCloud(
        transactionId: _label(transactionId),
        attempt: 1,
        takingLonger: false,
        startedAt: startedAt,
      );
      _startBudgetTimers(transactionId);
      await _prepareAndRecognize(transactionId, fileOwnerId, image.path);
    } catch (error) {
      if (error case CameraFailure(cleanupPath: final cleanupPath?)) {
        _ownedFiles.record(fileOwnerId, cleanupPath);
      }
      _ownedFiles.settleProduction(pathProduction);
      _clearPendingCapture(pathProduction);
      Object failure = error;
      try {
        await _ownedFiles.cleanupOwner(fileOwnerId);
      } catch (cleanupError) {
        failure = cleanupError;
      }
      final ownsFailedOperation = transactionId == null
          ? _ownsCameraOperation(operationId)
          : _ownsTransaction(transactionId);
      if (ownsFailedOperation) {
        _cancelBudgetTimers();
        _activeTransactionId = null;
        state = RecoverableError(failure: _domainFailure(failure));
      }
    } finally {
      _ownedFiles.settleProduction(pathProduction);
      _clearPendingCapture(pathProduction);
      if (operationId == _cameraOperationId) {
        _captureInFlight = false;
      }
    }
  }

  void keepWaiting() {
    final current = state;
    if (current case RecognizingCloud(takingLonger: true)) {
      state = RecognizingCloud(
        transactionId: current.transactionId,
        attempt: current.attempt,
        takingLonger: false,
        startedAt: current.startedAt,
      );
    }
  }

  Future<void> setFlash(CameraFlashMode mode) async {
    final current = state;
    if (_flashInFlight ||
        current is! PreviewReady ||
        !current.flashSupported ||
        current.flashMode == mode) {
      return;
    }
    _flashInFlight = true;
    final operationId = _cameraOperationId;
    try {
      await _camera.setFlash(mode);
      if (!_ownsCameraOperation(operationId) || state is! PreviewReady) {
        return;
      }
      _flashMode = mode;
      state = PreviewReady(flashSupported: true, flashMode: mode);
    } catch (_) {
      if (!_ownsCameraOperation(operationId) || state is! PreviewReady) {
        return;
      }
      _flashSupported = false;
      _flashMode = CameraFlashMode.auto;
      state = const PreviewReady();
    } finally {
      if (operationId == _cameraOperationId) {
        _flashInFlight = false;
      }
    }
  }

  Future<void> useLocalOcr() async {
    final canonicalPath = _canonicalPath;
    if (canonicalPath == null || !_canSelectLocal(state)) {
      return;
    }

    await _recognizeLocal(canonicalPath);
  }

  Future<void> _recognizeLocal(
    String canonicalPath, {
    int? expectedCloudTransactionId,
  }) async {
    if (expectedCloudTransactionId != null &&
        !_ownsTransaction(expectedCloudTransactionId)) {
      return;
    }

    _cancelBudgetTimers();
    _activeTransactionId = null;
    final fileOwnerId = _activeFileOwnerId;
    if (fileOwnerId != null) {
      _ownedFiles.abandonOwnerProductions(fileOwnerId);
    }
    final transactionId = ++_nextTransactionId;
    _activeTransactionId = transactionId;
    state = RecognizingLocal(transactionId: _label(transactionId));

    try {
      final result = await _localOcr.recognize(canonicalPath);
      if (!_ownsTransaction(transactionId)) {
        return;
      }
      _writeResult(result, OcrEngine.local);
    } catch (error) {
      if (!_ownsTransaction(transactionId)) {
        return;
      }
      state = RecoverableError(
        failure: error is OcrFailure
            ? error
            : OcrFailure.of(OcrFailureKind.recognizer),
      );
    }
  }

  Future<void> recapture() async {
    _retainedCanonicalOwnerId = null;
    _invalidateAsyncWork();
    final operationId = _cameraOperationId;
    if (!_cameraReady && _cameraNeedsDispose) {
      try {
        await _ensureCameraDisposed();
      } catch (error) {
        if (_ownsCameraOperation(operationId)) {
          state = RecoverableError(failure: _domainFailure(error));
        }
        return;
      }
      if (!_ownsCameraOperation(operationId)) {
        return;
      }
      _cameraNeedsDispose = false;
    }
    final fileOwnerId = _activeFileOwnerId;
    _canonicalPath = null;
    try {
      if (fileOwnerId != null) {
        await _ownedFiles.cleanupOwner(fileOwnerId);
      }
    } catch (error) {
      if (_ownsCameraOperation(operationId)) {
        state = RecoverableError(failure: _domainFailure(error));
      }
      return;
    }
    if (_activeFileOwnerId == fileOwnerId) {
      _activeFileOwnerId = null;
    }
    if (!_ownsCameraOperation(operationId)) {
      return;
    }
    try {
      final accepted = await _disclosure.hasAccepted();
      if (!_ownsCameraOperation(operationId)) {
        return;
      }
      if (!accepted) {
        state = const DisclosureRequired();
        return;
      }
    } catch (error) {
      if (_ownsCameraOperation(operationId)) {
        state = RecoverableError(failure: _domainFailure(error));
      }
      return;
    }
    if (_cameraReady) {
      state = PreviewReady(
        flashSupported: _flashSupported,
        flashMode: _flashMode,
      );
      return;
    }
    await _initializeCamera();
  }

  Future<bool> openSettings() async {
    final current = state;
    if (current is! PermissionDenied) {
      return false;
    }
    final operationId = _cameraOperationId;
    try {
      return await _settingsLauncher.open();
    } catch (error) {
      if (_ownsCameraOperation(operationId) && identical(state, current)) {
        state = RecoverableError(failure: _domainFailure(error));
      }
      return false;
    }
  }

  Future<void> onInactive() async {
    final needsBoot = state is Booting;
    final needsPreview = switch (state) {
      PreviewReady() || CameraInitializing() || Capturing() => true,
      _ => false,
    };
    _needsBootOnResume = needsBoot;
    _needsPreviewOnResume = needsPreview;
    final operationId = ++_cameraOperationId;
    _invalidateEntryTokens();
    final pendingCaptureOwnerId = _pendingCaptureOwnerId;
    if (pendingCaptureOwnerId != null) {
      _ownedFiles.abandonOwnerProductions(pendingCaptureOwnerId);
    }
    _pendingCaptureOwnerId = null;
    _pendingCaptureProduction = null;
    _captureInFlight = false;
    _flashInFlight = false;
    _cameraReady = false;
    if (_cameraNeedsDispose) {
      try {
        await _ensureCameraDisposed();
      } catch (error) {
        if (needsPreview && _ownsCameraOperation(operationId)) {
          state = RecoverableError(failure: _domainFailure(error));
        }
        return;
      }
      if (!_ownsCameraOperation(operationId)) {
        return;
      }
      _cameraNeedsDispose = false;
    }
  }

  Future<void> onResumed() async {
    if (_needsBootOnResume && state is Booting) {
      _needsBootOnResume = false;
      await start();
      return;
    }
    if (!_needsPreviewOnResume || !_flowNeedsPreview(state)) {
      return;
    }
    _needsPreviewOnResume = false;
    final operationId = _cameraOperationId;
    final teardown = _cameraTeardownFuture;
    if (teardown != null) {
      try {
        await teardown;
      } catch (_) {
        return;
      }
      if (!_ownsCameraOperation(operationId)) {
        return;
      }
      _cameraNeedsDispose = false;
    }
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final operationId = ++_cameraOperationId;
    state = const CameraInitializing();
    _cameraNeedsDispose = true;
    try {
      final permission = await _camera.initialize();
      if (!_ownsCameraOperation(operationId)) {
        return;
      }
      if (permission == CameraPermissionState.granted) {
        var flashSupported = false;
        try {
          flashSupported = await _camera.supportsFlash();
        } catch (_) {
          flashSupported = false;
        }
        if (!_ownsCameraOperation(operationId)) {
          return;
        }
        _cameraReady = true;
        _flashSupported = flashSupported;
        _flashMode = CameraFlashMode.auto;
        state = PreviewReady(
          flashSupported: flashSupported,
          flashMode: CameraFlashMode.auto,
        );
      } else {
        _cameraReady = false;
        state = PermissionDenied(permission);
      }
    } catch (error) {
      if (_ownsCameraOperation(operationId)) {
        _cameraReady = false;
        state = RecoverableError(failure: _domainFailure(error));
      }
    }
  }

  Future<void> _ensureCameraDisposed() {
    final existing = _cameraTeardownFuture;
    if (existing != null) {
      return existing;
    }
    late final Future<void> teardown;
    teardown = _camera.dispose().whenComplete(() {
      if (identical(_cameraTeardownFuture, teardown)) {
        _cameraTeardownFuture = null;
      }
    });
    _cameraTeardownFuture = teardown;
    return teardown;
  }

  Future<void> _prepareAndRecognize(
    int transactionId,
    int fileOwnerId,
    String canonicalPath,
  ) async {
    final pathProduction = _ownedFiles.beginProduction(fileOwnerId);
    PreparedImage prepared;
    try {
      prepared = await _imagePreparer.prepare(canonicalPath);
    } catch (error) {
      _ownedFiles.settleProduction(pathProduction);
      if (!_ownsTransaction(transactionId)) {
        return;
      }
      _finishCloudWithFailure(
        transactionId,
        error is OcrFailure ? error : OcrFailure.of(OcrFailureKind.preparation),
      );
      return;
    }

    _ownedFiles.record(fileOwnerId, prepared.canonicalPath);
    _ownedFiles.record(fileOwnerId, prepared.cloudPath);
    _ownedFiles.settleProduction(pathProduction);
    if (!_ownsTransaction(transactionId)) {
      final retainedCanonical = _retainedCanonicalOwnerId == fileOwnerId
          ? _canonicalPath
          : null;
      final staleDerivedPaths = <String>{
        prepared.canonicalPath,
        prepared.cloudPath,
      }..remove(retainedCanonical);
      try {
        await _ownedFiles.cleanupOwner(
          fileOwnerId,
          onlyPaths: staleDerivedPaths,
        );
      } catch (_) {
        // A stale completion cannot replace the active flow. Ownership is
        // retained so recapture or disposal can retry cleanup.
      }
      return;
    }
    await _recognizeCloud(transactionId, prepared.cloudPath, 1);
  }

  Future<void> _recognizeCloud(
    int transactionId,
    String cloudPath,
    int attempt,
  ) async {
    try {
      final result = await _cloudOcr.recognize(cloudPath);
      if (!_ownsTransaction(transactionId)) {
        return;
      }
      _cancelBudgetTimers();
      _writeResult(result, OcrEngine.cloud);
    } catch (error) {
      if (!_ownsTransaction(transactionId)) {
        return;
      }
      final failure = error is OcrFailure
          ? error
          : OcrFailure.of(OcrFailureKind.service);
      final canonicalPath = _canonicalPath;
      if (failure.kind == OcrFailureKind.configuration &&
          _cloudOcr.configurationPending &&
          canonicalPath != null) {
        await _recognizeLocal(
          canonicalPath,
          expectedCloudTransactionId: transactionId,
        );
        return;
      }
      if (attempt == 1 && failure.isRetryable) {
        await Future<void>.delayed(_retryDelay(attempt));
        if (!_ownsTransaction(transactionId)) {
          return;
        }
        final current = state;
        final takingLonger = switch (current) {
          RecognizingCloud(:final takingLonger) => takingLonger,
          _ => false,
        };
        state = RecognizingCloud(
          transactionId: _label(transactionId),
          attempt: 2,
          takingLonger: takingLonger,
          startedAt: _startedAt(current),
        );
        await _recognizeCloud(transactionId, cloudPath, 2);
        return;
      }
      _finishCloudWithFailure(transactionId, failure);
    }
  }

  void _finishCloudWithFailure(int transactionId, OcrFailure failure) {
    if (!_ownsTransaction(transactionId)) {
      return;
    }
    _cancelBudgetTimers();
    state = CloudRecovery(
      transactionId: _label(transactionId),
      failure: failure,
    );
  }

  void _writeResult(OcrResult result, OcrEngine engine) {
    switch (result) {
      case TextDetected(:final text):
        state = OcrSuccess(text: text, engine: engine);
      case NoReadableText():
        state = OcrEmpty(engine: engine);
    }
  }

  void _startBudgetTimers(int transactionId) {
    _cancelBudgetTimers();
    _slowTimer = Timer(_slowThreshold, () {
      if (!_ownsTransaction(transactionId)) {
        return;
      }
      final current = state;
      if (current is RecognizingCloud) {
        state = RecognizingCloud(
          transactionId: current.transactionId,
          attempt: current.attempt,
          takingLonger: true,
          startedAt: current.startedAt,
        );
      }
    });
    _deadlineTimer = Timer(_cloudDeadline, () {
      if (!_ownsTransaction(transactionId)) {
        return;
      }
      _activeTransactionId = null;
      final fileOwnerId = _activeFileOwnerId;
      if (fileOwnerId != null) {
        _ownedFiles.abandonOwnerProductions(fileOwnerId);
      }
      _cancelBudgetTimers();
      state = CloudRecovery(
        transactionId: _label(transactionId),
        failure: OcrFailure.of(OcrFailureKind.deadline),
      );
    });
  }

  DateTime _startedAt(OcrFlowState current) => switch (current) {
    RecognizingCloud(:final startedAt) => startedAt,
    _ => _now(),
  };

  bool _canSelectLocal(OcrFlowState current) => switch (current) {
    RecognizingCloud(takingLonger: true) => true,
    CloudRecovery() => true,
    OcrSuccess(engine: OcrEngine.cloud) => true,
    OcrEmpty(engine: OcrEngine.cloud) => true,
    _ => false,
  };

  bool _flowNeedsPreview(OcrFlowState current) => switch (current) {
    PreviewReady() || CameraInitializing() || Capturing() => true,
    _ => false,
  };

  bool _ownsCameraOperation(int operationId) =>
      !_disposed && ref.mounted && operationId == _cameraOperationId;

  bool _ownsTransaction(int transactionId) =>
      !_disposed && ref.mounted && transactionId == _activeTransactionId;

  bool _ownsStart(int token, int operationId) =>
      _startToken == token && _ownsCameraOperation(operationId);

  bool _ownsDisclosureAcceptance(int token, int operationId) =>
      _acceptDisclosureToken == token && _ownsCameraOperation(operationId);

  void _clearPendingCapture(_PathProduction production) {
    if (identical(_pendingCaptureProduction, production)) {
      _pendingCaptureOwnerId = null;
      _pendingCaptureProduction = null;
    }
  }

  Future<void> _cleanupStaleOwner(int fileOwnerId) async {
    try {
      await _ownedFiles.cleanupOwner(fileOwnerId);
    } catch (_) {
      // Stale failures must not overwrite a newer flow. Ownership is retained
      // for recapture or provider disposal to retry.
    }
  }

  void _invalidateAsyncWork() {
    _cancelBudgetTimers();
    _activeTransactionId = null;
    _invalidateEntryTokens();
    final fileOwnerId = _activeFileOwnerId;
    if (fileOwnerId != null) {
      _ownedFiles.abandonOwnerProductions(fileOwnerId);
    }
    final pendingCaptureOwnerId = _pendingCaptureOwnerId;
    if (pendingCaptureOwnerId != null) {
      _ownedFiles.abandonOwnerProductions(pendingCaptureOwnerId);
    }
    _pendingCaptureOwnerId = null;
    _pendingCaptureProduction = null;
    _cameraOperationId += 1;
    _captureInFlight = false;
    _flashInFlight = false;
  }

  void _invalidateEntryTokens() {
    _startToken = null;
    _acceptDisclosureToken = null;
  }

  void _cancelBudgetTimers() {
    _slowTimer?.cancel();
    _slowTimer = null;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
  }

  OcrFailure _domainFailure(Object error) {
    if (error is OcrFailure) {
      return error;
    }
    if (error is CameraFailure) {
      return OcrFailure.of(switch (error.kind) {
        CameraFailureKind.unavailable => OcrFailureKind.cameraUnavailable,
        CameraFailureKind.initialization ||
        CameraFailureKind.flashUnsupported =>
          OcrFailureKind.cameraInitialization,
        CameraFailureKind.capture ||
        CameraFailureKind.captureInProgress => OcrFailureKind.cameraCapture,
        CameraFailureKind.interrupted => OcrFailureKind.cameraInterrupted,
      });
    }
    return OcrFailure.of(OcrFailureKind.service);
  }

  String _label(int transactionId) => 'ocr-$transactionId';

  void _disposeOwnedResources() {
    _disposed = true;
    _invalidateAsyncWork();
    _ownedFiles.abandonAllProductions();
    if (_cameraNeedsDispose) {
      unawaited(_runContained(_disposeCameraAtTerminal));
    }
    unawaited(_runContained(_cleanupAllOwnedPaths));
  }

  Future<void> _cleanupAllOwnedPaths() async {
    try {
      await _ownedFiles.cleanupAll();
    } finally {
      _activeFileOwnerId = null;
      _retainedCanonicalOwnerId = null;
      _canonicalPath = null;
    }
  }

  Future<void> _disposeCameraAtTerminal() async {
    await _ensureCameraDisposed();
    _cameraNeedsDispose = false;
  }

  Future<void> _runContained(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Disposal is already terminal; failures must not escape or write state.
    }
  }
}

final class _PathProduction {
  _PathProduction(this.ownerId);

  final int ownerId;
  final Completer<void> _settled = Completer<void>();
  bool active = true;

  Future<void> get settled => _settled.future;

  void settle() {
    if (!active) {
      return;
    }
    active = false;
    _settled.complete();
  }
}

final class _OwnedTransactionFiles {
  _OwnedTransactionFiles(this._files);

  final TransactionFiles _files;
  final Map<int, Set<String>> _pathsByOwner = {};
  final Map<String, Set<int>> _liveClaims = {};
  final Set<(int, String)> _released = {};
  final Set<_PathProduction> _productions = {};
  final Map<int, Future<void>> _cleanupTails = {};
  int _nextOwnerId = 0;
  int _physicalCleanupCount = 0;

  bool get cleanupInFlight => _physicalCleanupCount > 0;

  int createOwner() => ++_nextOwnerId;

  _PathProduction beginProduction(int ownerId) {
    final production = _PathProduction(ownerId);
    _productions.add(production);
    return production;
  }

  void settleProduction(_PathProduction production) {
    production.settle();
    _productions.remove(production);
  }

  void abandonOwnerProductions(int ownerId) {
    final matching = _productions
        .where((production) => production.ownerId == ownerId)
        .toList();
    for (final production in matching) {
      settleProduction(production);
    }
  }

  void abandonAllProductions() {
    final pending = _productions.toList();
    for (final production in pending) {
      settleProduction(production);
    }
  }

  void record(int ownerId, String path) {
    if (_released.contains((ownerId, path))) {
      return;
    }
    _pathsByOwner.putIfAbsent(ownerId, () => <String>{}).add(path);
    _liveClaims.putIfAbsent(path, () => <int>{}).add(ownerId);
  }

  Future<void> cleanupOwner(int ownerId, {Iterable<String>? onlyPaths}) {
    final previous = _cleanupTails[ownerId];
    late final Future<void> cleanup;
    cleanup = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // A later cleanup is an intentional retry after a failed one.
        }
      }
      await _performCleanup(ownerId, onlyPaths: onlyPaths);
    }();
    _cleanupTails[ownerId] = cleanup;
    return cleanup.whenComplete(() {
      if (identical(_cleanupTails[ownerId], cleanup)) {
        _cleanupTails.remove(ownerId);
      }
    });
  }

  Future<void> cleanupAll() async {
    abandonAllProductions();
    Object? firstError;
    StackTrace? firstStackTrace;
    final ownerIds = _pathsByOwner.keys.toList()..sort();
    for (final ownerId in ownerIds) {
      try {
        await cleanupOwner(ownerId);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<void> _performCleanup(
    int ownerId, {
    Iterable<String>? onlyPaths,
  }) async {
    await _waitForNewerProduction(ownerId);
    final owned = _pathsByOwner[ownerId];
    if (owned == null || owned.isEmpty) {
      return;
    }
    final selected = onlyPaths == null
        ? Set<String>.of(owned)
        : owned.intersection(Set<String>.of(onlyPaths));
    if (selected.isEmpty) {
      return;
    }

    final physical = <String>[];
    for (final path in selected) {
      final claims = _liveClaims[path];
      final hasNewerLiveClaim =
          claims?.any((claimOwner) => claimOwner > ownerId) ?? false;
      if (hasNewerLiveClaim) {
        _release(ownerId, path);
      } else {
        physical.add(path);
      }
    }
    if (physical.isEmpty) {
      return;
    }

    _physicalCleanupCount += 1;
    try {
      await _files.cleanup(physical);
    } finally {
      _physicalCleanupCount -= 1;
    }
    for (final path in physical) {
      _release(ownerId, path);
    }
  }

  Future<void> _waitForNewerProduction(int ownerId) async {
    while (true) {
      final pending = _productions
          .where(
            (production) => production.active && production.ownerId > ownerId,
          )
          .map((production) => production.settled)
          .toList();
      if (pending.isEmpty) {
        return;
      }
      await Future.wait(pending);
    }
  }

  void _release(int ownerId, String path) {
    _released.add((ownerId, path));
    final owned = _pathsByOwner[ownerId];
    owned?.remove(path);
    if (owned != null && owned.isEmpty) {
      _pathsByOwner.remove(ownerId);
    }
    final claims = _liveClaims[path];
    claims?.remove(ownerId);
    if (claims != null && claims.isEmpty) {
      _liveClaims.remove(path);
    }
  }
}
