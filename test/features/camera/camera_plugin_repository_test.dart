import 'dart:async';

import 'package:altinus_ocr/features/camera/camera_models.dart';
import 'package:altinus_ocr/features/camera/camera_plugin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraPluginRepository', () {
    test(
      'prefers the rear camera and requests the still-photo contract',
      () async {
        final facade = _FakeCameraFacade(
          cameras: const [
            CameraDevice(id: 'front', lens: CameraDeviceLens.front),
            CameraDevice(id: 'rear', lens: CameraDeviceLens.rear),
          ],
        );
        final repository = CameraPluginRepository(facade: facade);

        expect(await repository.initialize(), CameraPermissionState.granted);

        expect(facade.openedDevice?.id, 'rear');
        expect(facade.configuration?.resolution, CameraResolution.high);
        expect(facade.configuration?.enableAudio, isFalse);
        expect(facade.configuration?.captureFormat, CameraCaptureFormat.jpeg);
        expect(repository.previewHandle, same(facade.session.previewHandle));
      },
    );

    test('fails conservatively when no rear lens exists', () async {
      final facade = _FakeCameraFacade(
        cameras: const [
          CameraDevice(id: 'front', lens: CameraDeviceLens.front),
          CameraDevice(id: 'external', lens: CameraDeviceLens.external),
        ],
      );

      final repository = CameraPluginRepository(facade: facade);

      await expectLater(
        repository.initialize(),
        throwsA(_cameraFailure(CameraFailureKind.unavailable)),
      );
      expect(facade.openedDevice, isNull);
    });

    test(
      'reports an explicit unavailable failure when no camera exists',
      () async {
        final repository = CameraPluginRepository(
          facade: _FakeCameraFacade(cameras: const []),
        );

        await expectLater(
          repository.initialize(),
          throwsA(_cameraFailure(CameraFailureKind.unavailable)),
        );
      },
    );

    for (final testCase in const [
      ('CameraAccessDenied', CameraPermissionState.denied),
      (
        'CameraAccessDeniedWithoutPrompt',
        CameraPermissionState.restrictedOrNoPrompt,
      ),
      ('CameraAccessRestricted', CameraPermissionState.restrictedOrNoPrompt),
    ]) {
      test('maps ${testCase.$1} without parsing its message', () async {
        final facade = _FakeCameraFacade(
          camerasError: CameraPluginException(
            testCase.$1,
            'arbitrary private platform detail',
          ),
        );

        final result = await CameraPluginRepository(facade: facade)
            .initialize();

        expect(result, testCase.$2);
      });
    }

    test('maps an unknown initialization exception conservatively', () async {
      final facade = _FakeCameraFacade(
        cameras: const [CameraDevice(id: 'rear', lens: CameraDeviceLens.rear)],
      );
      facade.session.initializeError = const CameraPluginException(
        'CameraDisconnected',
        'private detail',
      );

      await expectLater(
        CameraPluginRepository(facade: facade).initialize(),
        throwsA(_cameraFailure(CameraFailureKind.initialization)),
      );
      expect(facade.session.disposeCount, 1);
      expect(facade.session.ownsCamera, isFalse);
    });

    test('captures one JPEG still and maps plugin capture failure', () async {
      final facade = _FakeCameraFacade(
        cameras: const [CameraDevice(id: 'rear', lens: CameraDeviceLens.rear)],
      );
      final repository = CameraPluginRepository(facade: facade);
      await repository.initialize();
      facade.session.captureError = const CameraPluginException(
        'captureFailed',
        'private detail',
      );

      await expectLater(
        repository.capture(),
        throwsA(_cameraFailure(CameraFailureKind.capture)),
      );
      expect(facade.session.captureFormats, [CameraCaptureFormat.jpeg]);
    });

    test('rejects a duplicate capture before it reaches the session', () async {
      final facade = _FakeCameraFacade(
        cameras: const [CameraDevice(id: 'rear', lens: CameraDeviceLens.rear)],
      );
      final repository = CameraPluginRepository(facade: facade);
      await repository.initialize();
      facade.session.holdCapture = true;

      final first = repository.capture();
      await expectLater(
        repository.capture(),
        throwsA(_cameraFailure(CameraFailureKind.captureInProgress)),
      );
      expect(facade.session.captureCount, 1);

      facade.session.completeCapture('/tmp/rear.jpg');
      expect((await first).path, '/tmp/rear.jpg');
    });

    test('enables auto/off only after an auto-flash probe succeeds', () async {
      final facade = _FakeCameraFacade(
        cameras: const [CameraDevice(id: 'rear', lens: CameraDeviceLens.rear)],
      );
      final repository = CameraPluginRepository(facade: facade);

      await repository.initialize();
      expect(await repository.supportsFlash(), isTrue);
      expect(facade.session.flashModes, [CameraFlashMode.auto]);

      await repository.setFlash(CameraFlashMode.off);
      expect(facade.session.flashModes, [
        CameraFlashMode.auto,
        CameraFlashMode.off,
      ]);
    });

    test(
      'fails flash closed when the auto-flash probe is unsupported',
      () async {
        final facade = _FakeCameraFacade(
          cameras: const [
            CameraDevice(id: 'rear', lens: CameraDeviceLens.rear),
          ],
        );
        facade.session.flashError = const CameraPluginException(
          'setFlashModeFailed',
        );
        final repository = CameraPluginRepository(facade: facade);

        await repository.initialize();

        expect(await repository.supportsFlash(), isFalse);
        await expectLater(
          repository.setFlash(CameraFlashMode.off),
          throwsA(_cameraFailure(CameraFailureKind.flashUnsupported)),
        );
        expect(facade.session.flashModes, [CameraFlashMode.auto]);
      },
    );

    test(
      'dispose settles held initialization and releases ownership',
      () async {
        final facade = _FakeCameraFacade(
          cameras: const [
            CameraDevice(id: 'rear', lens: CameraDeviceLens.rear),
          ],
        );
        facade.session.holdInitialize = true;
        final repository = CameraPluginRepository(facade: facade);
        final initialization = repository.initialize();
        final interrupted = expectLater(
          initialization,
          throwsA(_cameraFailure(CameraFailureKind.interrupted)),
        );
        await facade.session.initializeEntered.future;

        await repository.dispose();

        expect(facade.session.disposeCount, 1);
        expect(facade.session.initializationSettled, isTrue);
        expect(facade.session.ownsCamera, isFalse);
        await interrupted;
      },
    );

    test(
      'a capture completing after dispose cannot produce an image',
      () async {
        final facade = _FakeCameraFacade(
          cameras: const [
            CameraDevice(id: 'rear', lens: CameraDeviceLens.rear),
          ],
        );
        final repository = CameraPluginRepository(facade: facade);
        await repository.initialize();
        facade.session.holdCapture = true;
        final capture = repository.capture();

        await repository.dispose();
        facade.session.completeCapture('/tmp/stale.jpg');

        await expectLater(
          capture,
          throwsA(_cameraFailure(CameraFailureKind.interrupted)),
        );
        expect(facade.session.discardedPaths, ['/tmp/stale.jpg']);
      },
    );

    test(
      'a native dispose failure is terminal even when raw retry would no-op',
      () async {
        final facade = _FakeCameraFacade(
          cameras: const [
            CameraDevice(id: 'rear', lens: CameraDeviceLens.rear),
          ],
        );
        final repository = CameraPluginRepository(facade: facade);
        await repository.initialize();
        facade.session.disposeBecomesNoOpAfterFirstAttempt = true;
        facade.session.disposeOutcomes.add(StateError('private failure'));

        await expectLater(
          repository.dispose(),
          throwsA(_cameraFailure(CameraFailureKind.interrupted)),
        );
        expect(facade.session.ownsCamera, isTrue);
        expect(facade.session.nextDisposeWouldNoOp, isTrue);
        await expectLater(
          repository.initialize(),
          throwsA(_cameraFailure(CameraFailureKind.interrupted)),
        );
        await expectLater(
          repository.capture(),
          throwsA(_cameraFailure(CameraFailureKind.interrupted)),
        );
        expect(facade.session.initializeCount, 1);

        await expectLater(
          repository.dispose(),
          throwsA(_cameraFailure(CameraFailureKind.interrupted)),
        );
        expect(
          facade.session.disposeCount,
          1,
          reason: 'a CameraController retry could be a misleading no-op',
        );
        expect(facade.session.ownsCamera, isTrue);
        expect(facade.openCount, 1);
      },
    );

    test('successful dispose permits one replacement initialization', () async {
      final facade = _FakeCameraFacade(
        cameras: const [CameraDevice(id: 'rear', lens: CameraDeviceLens.rear)],
      );
      final repository = CameraPluginRepository(facade: facade);
      await repository.initialize();

      await repository.dispose();
      expect(await repository.initialize(), CameraPermissionState.granted);

      expect(facade.session.disposeCount, 1);
      expect(facade.session.initializeCount, 2);
      expect(facade.openCount, 2);
    });

    test(
      'failed stale deletion returns its path to cleanup ownership',
      () async {
        final facade = _FakeCameraFacade(
          cameras: const [
            CameraDevice(id: 'rear', lens: CameraDeviceLens.rear),
          ],
        );
        final repository = CameraPluginRepository(facade: facade);
        await repository.initialize();
        facade.session.holdCapture = true;
        facade.session.discardError = StateError('private delete failure');
        final capture = repository.capture();

        await repository.dispose();
        facade.session.completeCapture('/tmp/retry-cleanup.jpg');

        await expectLater(
          capture,
          throwsA(
            isA<CameraFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  CameraFailureKind.interrupted,
                )
                .having(
                  (failure) => failure.cleanupPath,
                  'cleanupPath',
                  '/tmp/retry-cleanup.jpg',
                ),
          ),
        );
      },
    );

    test(
      'failed initialization cleanup and public dispose are single-flight',
      () async {
        final facade = _FakeCameraFacade(
          cameras: const [
            CameraDevice(id: 'rear', lens: CameraDeviceLens.rear),
          ],
        );
        facade.session.initializeError = const CameraPluginException(
          'CameraDisconnected',
        );
        facade.session.holdDispose = true;
        final repository = CameraPluginRepository(facade: facade);
        final initialization = repository.initialize();
        final initializationFailure = expectLater(
          initialization,
          throwsA(_cameraFailure(CameraFailureKind.initialization)),
        );
        await facade.session.disposeEntered.future;

        final disposal = repository.dispose();
        final disposalFailure = expectLater(
          disposal,
          throwsA(_cameraFailure(CameraFailureKind.interrupted)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(facade.session.disposeCount, 1);

        facade.session.failDispose(0, StateError('private teardown failure'));
        await initializationFailure;
        await disposalFailure;

        facade.session.holdDispose = false;
        await expectLater(
          repository.dispose(),
          throwsA(_cameraFailure(CameraFailureKind.interrupted)),
        );
        expect(facade.session.disposeCount, 1);
        expect(facade.session.ownsCamera, isTrue);
      },
    );
  });
}

Matcher _cameraFailure(CameraFailureKind kind) =>
    isA<CameraFailure>().having((failure) => failure.kind, 'kind', kind);

final class _FakeCameraFacade implements CameraPluginFacade {
  _FakeCameraFacade({this.cameras = const [], this.camerasError});

  final List<CameraDevice> cameras;
  final Object? camerasError;
  final _FakeCameraSession session = _FakeCameraSession();
  CameraDevice? openedDevice;
  CameraSessionConfiguration? configuration;
  int openCount = 0;

  @override
  Future<List<CameraDevice>> availableCameras() async {
    if (camerasError case final error?) {
      throw error;
    }
    return cameras;
  }

  @override
  CameraPluginSession openSession(
    CameraDevice device,
    CameraSessionConfiguration configuration,
  ) {
    openCount += 1;
    openedDevice = device;
    this.configuration = configuration;
    return session;
  }
}

final class _FakeCameraSession implements CameraPluginSession {
  final Object previewHandle = Object();
  final Completer<void> initializeEntered = Completer<void>();
  final Completer<void> disposeEntered = Completer<void>();
  final List<CameraCaptureFormat> captureFormats = [];
  final List<CameraFlashMode> flashModes = [];
  final List<String> discardedPaths = [];
  final List<Object?> disposeOutcomes = [];
  final List<Completer<void>> pendingDisposals = [];
  final Completer<void> _heldInitialization = Completer<void>();
  Completer<String>? _heldCapture;
  Object? initializeError;
  Object? captureError;
  Object? flashError;
  Object? discardError;
  bool holdInitialize = false;
  bool holdCapture = false;
  bool holdDispose = false;
  bool disposeBecomesNoOpAfterFirstAttempt = false;
  bool _rawDisposed = false;
  bool initializationSettled = false;
  bool ownsCamera = false;
  int captureCount = 0;
  int initializeCount = 0;
  int disposeCount = 0;

  bool get nextDisposeWouldNoOp =>
      disposeBecomesNoOpAfterFirstAttempt && _rawDisposed;

  @override
  Object get preview => previewHandle;

  @override
  Future<void> initialize() async {
    initializeCount += 1;
    ownsCamera = true;
    if (!initializeEntered.isCompleted) {
      initializeEntered.complete();
    }
    try {
      if (holdInitialize) {
        await _heldInitialization.future;
      }
      if (initializeError case final error?) {
        throw error;
      }
    } finally {
      initializationSettled = true;
    }
  }

  @override
  Future<String> capture(CameraCaptureFormat format) async {
    captureCount += 1;
    captureFormats.add(format);
    if (captureError case final error?) {
      throw error;
    }
    if (holdCapture) {
      _heldCapture = Completer<String>();
      return _heldCapture!.future;
    }
    return '/tmp/capture.jpg';
  }

  void completeCapture(String path) => _heldCapture!.complete(path);

  @override
  Future<void> discardCapture(String path) async {
    discardedPaths.add(path);
    if (discardError case final error?) {
      throw error;
    }
  }

  void failDispose(int index, Object error) {
    pendingDisposals[index].completeError(error);
  }

  @override
  Future<void> setFlash(CameraFlashMode mode) async {
    flashModes.add(mode);
    if (flashError case final error?) {
      throw error;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    if (disposeBecomesNoOpAfterFirstAttempt && _rawDisposed) {
      return;
    }
    if (disposeBecomesNoOpAfterFirstAttempt) {
      _rawDisposed = true;
    }
    if (!disposeEntered.isCompleted) {
      disposeEntered.complete();
    }
    if (holdDispose) {
      final pending = Completer<void>();
      pendingDisposals.add(pending);
      await pending.future;
    }
    if (disposeOutcomes.isNotEmpty) {
      final outcome = disposeOutcomes.removeAt(0);
      if (outcome case final error?) {
        throw error;
      }
    }
    ownsCamera = false;
    if (!_heldInitialization.isCompleted) {
      _heldInitialization.complete();
    }
    while (!initializationSettled && initializeEntered.isCompleted) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}
