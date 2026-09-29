import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' as camera;

import 'camera_models.dart';
import 'camera_repository.dart';

enum CameraDeviceLens { front, rear, external }

enum CameraResolution { high }

enum CameraCaptureFormat { jpeg }

final class CameraDevice {
  const CameraDevice({required this.id, required this.lens});

  final String id;
  final CameraDeviceLens lens;
}

final class CameraSessionConfiguration {
  const CameraSessionConfiguration({
    required this.resolution,
    required this.enableAudio,
    required this.captureFormat,
  });

  final CameraResolution resolution;
  final bool enableAudio;
  final CameraCaptureFormat captureFormat;
}

final class CameraPluginException implements Exception {
  const CameraPluginException(this.code, [this.description]);

  final String code;
  final String? description;
}

abstract interface class CameraPluginFacade {
  Future<List<CameraDevice>> availableCameras();

  CameraPluginSession openSession(
    CameraDevice device,
    CameraSessionConfiguration configuration,
  );
}

abstract interface class CameraPluginSession {
  Object get preview;

  /// Must settle pending [initialize] work and release camera ownership.
  Future<void> dispose();
  Future<void> initialize();
  Future<String> capture(CameraCaptureFormat format);
  Future<void> discardCapture(String path);
  Future<void> setFlash(CameraFlashMode mode);
}

final class CameraPluginRepository implements CameraRepository {
  CameraPluginRepository({CameraPluginFacade? facade})
    : _facade = facade ?? _OfficialCameraFacade();

  static const _configuration = CameraSessionConfiguration(
    resolution: CameraResolution.high,
    enableAudio: false,
    captureFormat: CameraCaptureFormat.jpeg,
  );

  final CameraPluginFacade _facade;
  int _generation = 0;
  int _nextCaptureId = 0;
  int? _activeCaptureId;
  CameraPluginSession? _session;
  CameraPluginSession? _teardownSession;
  CameraPluginSession? _terminalTeardownSession;
  Future<void>? _teardownFuture;
  _Initialization? _initialization;
  Future<CameraPermissionState>? _initializationFuture;
  bool _ready = false;
  bool _flashSupported = false;

  Object? get previewHandle => _ready ? _session?.preview : null;

  @override
  Future<CameraPermissionState> initialize() {
    final existing = _initializationFuture;
    if (existing != null) {
      return existing;
    }
    if (_session != null) {
      if (_ready) {
        return Future.value(CameraPermissionState.granted);
      }
      return Future.error(const CameraFailure(CameraFailureKind.interrupted));
    }

    final operation = _Initialization(++_generation);
    _initialization = operation;
    late final Future<CameraPermissionState> future;
    future = _runInitialization(operation).whenComplete(() {
      operation.settle();
      if (identical(_initialization, operation)) {
        _initialization = null;
      }
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
      }
    });
    _initializationFuture = future;
    return future;
  }

  Future<CameraPermissionState> _runInitialization(
    _Initialization operation,
  ) async {
    _ready = false;
    _flashSupported = false;
    try {
      final devices = await _untilCancelled(
        _facade.availableCameras(),
        operation,
      );
      _checkCurrent(operation);
      if (devices.isEmpty) {
        throw const CameraFailure(CameraFailureKind.unavailable);
      }
      CameraDevice? selected;
      for (final device in devices) {
        if (device.lens == CameraDeviceLens.rear) {
          selected = device;
          break;
        }
      }
      if (selected == null) {
        throw const CameraFailure(CameraFailureKind.unavailable);
      }
      final session = _facade.openSession(selected, _configuration);
      operation.session = session;
      _session = session;

      await _untilCancelled(session.initialize(), operation);
      _checkCurrent(operation);

      try {
        await _untilCancelled(
          session.setFlash(CameraFlashMode.auto),
          operation,
        );
        _checkCurrent(operation);
        _flashSupported = true;
      } on _InitializationInterrupted {
        rethrow;
      } catch (_) {
        _flashSupported = false;
      }

      _checkCurrent(operation);
      _ready = true;
      return CameraPermissionState.granted;
    } on _InitializationInterrupted {
      throw const CameraFailure(CameraFailureKind.interrupted);
    } on CameraPluginException catch (error) {
      final permission = switch (error.code) {
        'CameraAccessDenied' => CameraPermissionState.denied,
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' => CameraPermissionState.restrictedOrNoPrompt,
        _ => null,
      };
      await _releaseFailedInitialization(operation);
      if (permission != null) {
        return permission;
      }
      throw const CameraFailure(CameraFailureKind.initialization);
    } on CameraFailure {
      await _releaseFailedInitialization(operation);
      rethrow;
    } catch (_) {
      await _releaseFailedInitialization(operation);
      throw const CameraFailure(CameraFailureKind.initialization);
    }
  }

  Future<void> _releaseFailedInitialization(_Initialization operation) async {
    final session = operation.session;
    if (session == null) {
      return;
    }
    try {
      await _disposeSession(session);
      operation.session = null;
    } catch (_) {
      // Retain unproven ownership. The terminal teardown latch prevents a
      // misleading later no-op from being treated as physical release.
    }
  }

  Future<T> _untilCancelled<T>(Future<T> source, _Initialization operation) =>
      Future.any<T>([
        source,
        operation.cancelled.future.then<T>(
          (_) => throw const _InitializationInterrupted(),
        ),
      ]);

  void _checkCurrent(_Initialization operation) {
    if (operation.generation != _generation || operation.isCancelled) {
      throw const _InitializationInterrupted();
    }
  }

  @override
  Future<CapturedImage> capture() async {
    final session = _session;
    if (!_ready || session == null) {
      throw const CameraFailure(CameraFailureKind.interrupted);
    }
    if (_activeCaptureId != null) {
      throw const CameraFailure(CameraFailureKind.captureInProgress);
    }

    final generation = _generation;
    final captureId = ++_nextCaptureId;
    _activeCaptureId = captureId;
    try {
      final path = await session.capture(_configuration.captureFormat);
      if (generation != _generation || !identical(session, _session)) {
        try {
          await session.discardCapture(path);
        } catch (_) {
          throw CameraFailure(CameraFailureKind.interrupted, cleanupPath: path);
        }
        throw const CameraFailure(CameraFailureKind.interrupted);
      }
      return CapturedImage(path);
    } on CameraFailure {
      rethrow;
    } catch (_) {
      if (generation != _generation || !identical(session, _session)) {
        throw const CameraFailure(CameraFailureKind.interrupted);
      }
      throw const CameraFailure(CameraFailureKind.capture);
    } finally {
      if (_activeCaptureId == captureId) {
        _activeCaptureId = null;
      }
    }
  }

  @override
  Future<bool> supportsFlash() async => _ready && _flashSupported;

  @override
  Future<void> setFlash(CameraFlashMode mode) async {
    final session = _session;
    if (!_ready || !_flashSupported || session == null) {
      throw const CameraFailure(CameraFailureKind.flashUnsupported);
    }
    final generation = _generation;
    try {
      await session.setFlash(mode);
      if (generation != _generation || !identical(session, _session)) {
        throw const CameraFailure(CameraFailureKind.interrupted);
      }
    } on CameraFailure {
      rethrow;
    } catch (_) {
      _flashSupported = false;
      throw const CameraFailure(CameraFailureKind.flashUnsupported);
    }
  }

  @override
  Future<void> dispose() async {
    _generation += 1;
    _ready = false;
    _flashSupported = false;
    _activeCaptureId = null;
    final initialization = _initialization;
    initialization?.cancel();
    final session = _session ?? initialization?.session;

    Object? disposalError;
    StackTrace? disposalStackTrace;
    try {
      if (session != null) {
        await _disposeSession(session);
      }
    } catch (error, stackTrace) {
      disposalError = error;
      disposalStackTrace = stackTrace;
    } finally {
      await initialization?.settled.future;
    }
    if (disposalError != null) {
      Error.throwWithStackTrace(
        const CameraFailure(CameraFailureKind.interrupted),
        disposalStackTrace!,
      );
    }
  }

  Future<void> _disposeSession(CameraPluginSession session) {
    if (identical(_terminalTeardownSession, session)) {
      return Future<void>.error(
        const CameraFailure(CameraFailureKind.interrupted),
      );
    }
    final existing = _teardownFuture;
    if (existing != null) {
      if (identical(_teardownSession, session)) {
        return existing;
      }
      return existing.then((_) => _disposeSession(session));
    }

    _teardownSession = session;
    late final Future<void> teardown;
    teardown = session
        .dispose()
        .then(
          (_) {
            if (identical(_session, session)) {
              _session = null;
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            _terminalTeardownSession = session;
            Error.throwWithStackTrace(error, stackTrace);
          },
        )
        .whenComplete(() {
          if (identical(_teardownFuture, teardown)) {
            _teardownFuture = null;
            _teardownSession = null;
          }
        });
    _teardownFuture = teardown;
    return teardown;
  }
}

final class _Initialization {
  _Initialization(this.generation);

  final int generation;
  final Completer<void> cancelled = Completer<void>();
  final Completer<void> settled = Completer<void>();
  CameraPluginSession? session;

  bool get isCancelled => cancelled.isCompleted;

  void cancel() {
    if (!cancelled.isCompleted) {
      cancelled.complete();
    }
  }

  void settle() {
    if (!settled.isCompleted) {
      settled.complete();
    }
  }
}

final class _InitializationInterrupted implements Exception {
  const _InitializationInterrupted();
}

final class _OfficialCameraFacade implements CameraPluginFacade {
  final Map<String, camera.CameraDescription> _descriptions = {};

  @override
  Future<List<CameraDevice>> availableCameras() async {
    try {
      final descriptions = await camera.availableCameras();
      _descriptions.clear();
      return [
        for (final (index, description) in descriptions.indexed)
          _device(index, description),
      ];
    } on camera.CameraException catch (error) {
      throw CameraPluginException(error.code, error.description);
    }
  }

  CameraDevice _device(int index, camera.CameraDescription description) {
    final id = '$index:${description.name}';
    _descriptions[id] = description;
    return CameraDevice(
      id: id,
      lens: switch (description.lensDirection) {
        camera.CameraLensDirection.front => CameraDeviceLens.front,
        camera.CameraLensDirection.back => CameraDeviceLens.rear,
        camera.CameraLensDirection.external => CameraDeviceLens.external,
      },
    );
  }

  @override
  CameraPluginSession openSession(
    CameraDevice device,
    CameraSessionConfiguration configuration,
  ) {
    final description = _descriptions[device.id];
    if (description == null) {
      throw const CameraPluginException('CameraDescriptionUnavailable');
    }
    final controller = camera.CameraController(
      description,
      camera.ResolutionPreset.high,
      enableAudio: false,
    );
    return _OfficialCameraSession(controller);
  }
}

final class _OfficialCameraSession implements CameraPluginSession {
  _OfficialCameraSession(this._controller);

  final camera.CameraController _controller;

  @override
  Object get preview => _controller;

  @override
  Future<void> initialize() => _translate(_controller.initialize);

  @override
  Future<String> capture(CameraCaptureFormat format) async {
    if (format != CameraCaptureFormat.jpeg) {
      throw const CameraPluginException('UnsupportedCaptureFormat');
    }
    return (await _translate(_controller.takePicture)).path;
  }

  @override
  Future<void> discardCapture(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> setFlash(CameraFlashMode mode) => _translate(
    () => _controller.setFlashMode(switch (mode) {
      CameraFlashMode.auto => camera.FlashMode.auto,
      CameraFlashMode.off => camera.FlashMode.off,
    }),
  );

  @override
  Future<void> dispose() => _translate(_controller.dispose);
}

Future<T> _translate<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on camera.CameraException catch (error) {
    throw CameraPluginException(error.code, error.description);
  }
}
