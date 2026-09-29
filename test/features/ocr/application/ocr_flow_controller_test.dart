import 'dart:async';

import 'package:altinus_ocr/features/camera/camera_models.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_flow_controller.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_flow_state.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_providers.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_engine.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/ocr_fakes.dart';

void main() {
  group('startup and camera ownership', () {
    for (final testCase in const [
      (
        CameraFailure(CameraFailureKind.unavailable),
        OcrFailureKind.cameraUnavailable,
      ),
      (
        CameraFailure(CameraFailureKind.initialization),
        OcrFailureKind.cameraInitialization,
      ),
      (
        CameraFailure(CameraFailureKind.interrupted),
        OcrFailureKind.cameraInterrupted,
      ),
    ]) {
      test('maps ${testCase.$1.kind} to an explicit domain failure', () {
        fakeAsync((async) {
          final harness = _Harness(async, cameraInitializeError: testCase.$1);

          unawaited(harness.controller.start());
          async.flushMicrotasks();

          final error = harness.state as RecoverableError;
          expect(error.failure.kind, testCase.$2);
          harness.dispose(async);
        });
      });
    }

    test('maps camera capture failure to an explicit domain failure', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        unawaited(harness.controller.capture());
        harness.camera.failCapture(
          0,
          const CameraFailure(CameraFailureKind.capture),
        );
        async.flushMicrotasks();

        final error = harness.state as RecoverableError;
        expect(error.failure.kind, OcrFailureKind.cameraCapture);
        harness.dispose(async);
      });
    });

    test('adopts a stale adapter path when direct deletion fails', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        unawaited(harness.controller.capture());
        harness.camera.failCapture(
          0,
          const CameraFailure(
            CameraFailureKind.interrupted,
            cleanupPath: '/owned/stale-adapter.jpg',
          ),
        );
        async.flushMicrotasks();

        expect(
          harness.files.cleanedPaths,
          contains('/owned/stale-adapter.jpg'),
        );
        harness.dispose(async);
      });
    });

    test('unaccepted disclosure stops before camera initialization', () {
      fakeAsync((async) {
        final harness = _Harness(async, disclosureAccepted: false);

        unawaited(harness.controller.start());
        async.flushMicrotasks();

        expect(harness.state, isA<DisclosureRequired>());
        expect(harness.camera.initializeCount, 0);
        expect(harness.files.cleanupOrphansCount, 1);
        harness.dispose(async);
      });
    });

    test('accepted disclosure initializes camera and reaches preview', () {
      fakeAsync((async) {
        final harness = _Harness(async);

        harness.start(async);

        expect(harness.state, isA<PreviewReady>());
        expect(harness.camera.initializeCount, 1);
        harness.dispose(async);
      });
    });

    test(
      'recapture disposes a pending initialization before one replacement',
      () {
        fakeAsync((async) {
          final harness = _Harness(async);
          harness.camera.holdInitialize = true;
          unawaited(harness.controller.start());
          async.flushMicrotasks();
          expect(harness.state, isA<CameraInitializing>());

          unawaited(harness.controller.recapture());
          async.flushMicrotasks();

          expect(harness.camera.disposeCount, 1);
          expect(harness.camera.initializeCount, 2);
          expect(harness.camera.maxConcurrentInitializationCount, 1);
          expect(harness.camera.activeInitializationCount, 1);
          expect(harness.camera.liveSessionCount, 0);

          harness.camera.completeInitialize(1);
          async.flushMicrotasks();
          expect(harness.state, isA<PreviewReady>());
          expect(harness.camera.liveSessionCount, 1);
          harness.dispose(async);
        });
      },
    );

    test(
      'a disposed stale initialization cannot write the replacement state',
      () {
        fakeAsync((async) {
          final harness = _Harness(async);
          harness.camera.holdInitialize = true;
          unawaited(harness.controller.start());
          async.flushMicrotasks();
          unawaited(harness.controller.recapture());
          async.flushMicrotasks();

          expect(harness.camera.wasInitializeCancelled(0), isTrue);
          harness.camera.completeInitialize(1);
          async.flushMicrotasks();

          expect(harness.state, isA<PreviewReady>());
          expect(harness.camera.liveSessionCount, 1);
          harness.dispose(async);
        });
      },
    );

    test('unaccepted recapture tears down pending initialization before disclosure', () {
      fakeAsync((async) {
        final harness = _Harness(async);
        harness.camera.holdInitialize = true;
        unawaited(harness.controller.start());
        async.flushMicrotasks();

        harness.disclosure.accepted = false;
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        expect(harness.camera.disposeCount, 1);
        expect(harness.camera.wasInitializeCancelled(0), isTrue);
        expect(harness.camera.initializeCount, 1);
        expect(harness.camera.liveSessionCount, 0);
        expect(harness.state, isA<DisclosureRequired>());
        harness.dispose(async);
      });
    });

    test('disclosure read failure tears down pending initialization before recovery', () {
      fakeAsync((async) {
        final harness = _Harness(async);
        harness.camera.holdInitialize = true;
        unawaited(harness.controller.start());
        async.flushMicrotasks();

        harness.disclosure.hasAcceptedError = StateError('private detail');
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        expect(harness.camera.disposeCount, 1);
        expect(harness.camera.wasInitializeCancelled(0), isTrue);
        expect(harness.camera.initializeCount, 1);
        expect(harness.camera.liveSessionCount, 0);
        expect(harness.state, isA<RecoverableError>());
        harness.dispose(async);
      });
    });

    test('rapid recaptures share teardown and only the latest initializes', () {
      fakeAsync((async) {
        final harness = _Harness(async);
        harness.camera.holdInitialize = true;
        unawaited(harness.controller.start());
        async.flushMicrotasks();
        harness.camera.holdDispose = true;

        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        expect(harness.camera.disposeCount, 1);
        expect(harness.camera.initializeCount, 1);
        harness.camera.completeDispose(0);
        async.flushMicrotasks();

        expect(harness.camera.initializeCount, 2);
        expect(harness.camera.maxConcurrentInitializationCount, 1);
        harness.camera.completeInitialize(1);
        async.flushMicrotasks();

        expect(harness.state, isA<PreviewReady>());
        expect(harness.camera.liveSessionCount, 1);
        harness.dispose(async);
      });
    });

    test('controller can retry a repository that proves later release', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        harness.camera.disposeError = StateError('private detail');

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        expect(harness.state, isA<RecoverableError>());
        expect(harness.camera.disposeCount, 1);

        harness.camera.disposeError = null;
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        expect(harness.camera.disposeCount, 2);
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test(
      'recapture rechecks accepted disclosure before returning to camera',
      () {
        fakeAsync((async) {
          final harness = _Harness(
            async,
            disclosureAccepted: false,
            cleanupOrphansError: StateError('initial cleanup failed'),
          );

          unawaited(harness.controller.start());
          async.flushMicrotasks();
          expect(harness.state, isA<RecoverableError>());

          unawaited(harness.controller.recapture());
          async.flushMicrotasks();

          expect(harness.state, isA<DisclosureRequired>());
          expect(harness.camera.initializeCount, 0);
          expect(harness.disclosure.hasAcceptedCount, 1);
          harness.dispose(async);
        });
      },
    );

    test('accepted recapture still returns to the ready preview', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);

        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        expect(harness.state, isA<PreviewReady>());
        expect(harness.disclosure.hasAcceptedCount, 2);
        harness.dispose(async);
      });
    });

    test('recapture disclosure read failure stays in a safe recovery', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cleanupOrphansError: StateError('initial cleanup failed'),
        );

        unawaited(harness.controller.start());
        async.flushMicrotasks();
        harness.disclosure.hasAcceptedError = StateError('private read detail');
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        expect(harness.state, isA<RecoverableError>());
        expect(harness.camera.initializeCount, 0);
        harness.dispose(async);
      });
    });

    test('a stale recapture disclosure read cannot restore camera state', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cleanupOrphansError: StateError('initial cleanup failed'),
        );

        unawaited(harness.controller.start());
        async.flushMicrotasks();
        harness.disclosure.holdHasAccepted = true;
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(harness.disclosure.pendingHasAccepted, hasLength(1));

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        harness.disclosure.completeHasAccepted(0);
        async.flushMicrotasks();

        expect(harness.state, isA<RecoverableError>());
        expect(harness.camera.initializeCount, 0);
        harness.dispose(async);
      });
    });

    test('accepting disclosure persists it before initializing camera', () {
      fakeAsync((async) {
        final harness = _Harness(async, disclosureAccepted: false);
        unawaited(harness.controller.start());
        async.flushMicrotasks();

        unawaited(harness.controller.acceptDisclosure());
        async.flushMicrotasks();

        expect(harness.disclosure.accepted, isTrue);
        expect(harness.disclosure.acceptCount, 1);
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test('two rapid captures invoke the camera only once', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);

        unawaited(harness.controller.capture());
        unawaited(harness.controller.capture());

        expect(harness.camera.captureCount, 1);
        expect(harness.state, isA<Capturing>());
        harness.camera.completeCapture(0, '/owned/capture-1.jpg');
        async.flushMicrotasks();
        expect(harness.cloud.requests, hasLength(1));
        harness.dispose(async);
      });
    });

    test('start is idempotent while its first async start is pending', () {
      fakeAsync((async) {
        final harness = _Harness(async, holdCleanupOrphans: true);

        unawaited(harness.controller.start());
        unawaited(harness.controller.start());
        async.flushMicrotasks();

        expect(harness.files.cleanupOrphansCount, 1);
        expect(harness.files.pendingOrphanCleanups, hasLength(1));
        harness.files.completeOrphanCleanup(0);
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test('accept disclosure is debounced while persistence is pending', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          disclosureAccepted: false,
          holdDisclosureAccept: true,
        );
        unawaited(harness.controller.start());
        async.flushMicrotasks();

        unawaited(harness.controller.acceptDisclosure());
        unawaited(harness.controller.acceptDisclosure());
        async.flushMicrotasks();

        expect(harness.disclosure.acceptCount, 1);
        expect(harness.disclosure.pendingAccepts, hasLength(1));
        harness.disclosure.completeAccept(0);
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test('inactive abandons a pending start token without canceling it', () {
      fakeAsync((async) {
        final harness = _Harness(async, holdCleanupOrphans: true);
        unawaited(harness.controller.start());
        async.flushMicrotasks();

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.start());
        async.flushMicrotasks();
        expect(harness.files.cleanupOrphansCount, 2);

        harness.files.completeOrphanCleanup(0);
        async.flushMicrotasks();
        unawaited(harness.controller.start());
        async.flushMicrotasks();
        expect(
          harness.files.cleanupOrphansCount,
          2,
          reason: 'old finally cannot clear the newer pending token',
        );

        harness.files.completeOrphanCleanup(1);
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test(
      'resume restarts boot held on orphan cleanup and stales the old start',
      () {
        fakeAsync((async) {
          final harness = _Harness(async, holdCleanupOrphans: true);
          unawaited(harness.controller.start());
          async.flushMicrotasks();

          unawaited(harness.controller.onInactive());
          unawaited(harness.controller.onResumed());
          async.flushMicrotasks();

          expect(harness.files.cleanupOrphansCount, 2);
          harness.files.completeOrphanCleanup(1);
          async.flushMicrotasks();
          expect(harness.state, isA<PreviewReady>());
          expect(harness.camera.initializeCount, 1);

          harness.files.completeOrphanCleanup(0);
          async.flushMicrotasks();
          expect(harness.state, isA<PreviewReady>());
          expect(harness.camera.initializeCount, 1);
          harness.dispose(async);
        });
      },
    );

    test(
      'resume restarts boot held on disclosure and preserves unaccepted branch',
      () {
        fakeAsync((async) {
          final harness = _Harness(
            async,
            disclosureAccepted: false,
            holdDisclosureRead: true,
          );
          unawaited(harness.controller.start());
          async.flushMicrotasks();

          unawaited(harness.controller.onInactive());
          unawaited(harness.controller.onResumed());
          async.flushMicrotasks();

          expect(harness.disclosure.hasAcceptedCount, 2);
          harness.disclosure.completeHasAccepted(1);
          async.flushMicrotasks();
          expect(harness.state, isA<DisclosureRequired>());
          expect(harness.camera.initializeCount, 0);

          harness.disclosure.accepted = true;
          harness.disclosure.completeHasAccepted(0);
          async.flushMicrotasks();
          expect(harness.state, isA<DisclosureRequired>());
          expect(harness.camera.initializeCount, 0);
          harness.dispose(async);
        });
      },
    );

    test('inactive abandons a pending disclosure token independently', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          disclosureAccepted: false,
          holdDisclosureAccept: true,
        );
        unawaited(harness.controller.start());
        async.flushMicrotasks();
        unawaited(harness.controller.acceptDisclosure());
        async.flushMicrotasks();

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.acceptDisclosure());
        async.flushMicrotasks();
        expect(harness.disclosure.acceptCount, 2);

        harness.disclosure.completeAccept(0);
        async.flushMicrotasks();
        unawaited(harness.controller.acceptDisclosure());
        async.flushMicrotasks();
        expect(
          harness.disclosure.acceptCount,
          2,
          reason: 'old finally cannot clear the newer pending token',
        );

        harness.disclosure.completeAccept(1);
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    for (final invoke in <String, void Function(OcrFlowController)>{
      'start': (controller) => unawaited(controller.start()),
      'acceptDisclosure': (controller) =>
          unawaited(controller.acceptDisclosure()),
    }.entries) {
      test('${invoke.key} cannot replace an active cloud transaction', () {
        fakeAsync((async) {
          final harness = _Harness(async)..startCloud(async);
          final recognizing = harness.state;

          invoke.value(harness.controller);
          async.flushMicrotasks();

          expect(harness.camera.initializeCount, 1);
          expect(harness.camera.captureCount, 1);
          expect(harness.state, same(recognizing));
          harness.cloud.complete(0, OcrResult.textDetected('cloud result'));
          async.flushMicrotasks();
          expect((harness.state as OcrSuccess).text, 'cloud result');
          harness.dispose(async);
        });
      });

      test('${invoke.key} cannot replace an active local transaction', () {
        fakeAsync((async) {
          final harness = _Harness(async)..startCloud(async);
          async.elapse(const Duration(seconds: 10));
          unawaited(harness.controller.useLocalOcr());
          async.flushMicrotasks();
          final recognizing = harness.state;

          invoke.value(harness.controller);
          async.flushMicrotasks();

          expect(harness.camera.initializeCount, 1);
          expect(harness.camera.captureCount, 1);
          expect(harness.state, same(recognizing));
          harness.local.complete(0, OcrResult.textDetected('local result'));
          async.flushMicrotasks();
          expect((harness.state as OcrSuccess).text, 'local result');
          harness.dispose(async);
        });
      });
    }

    test('orphan cleanup failure becomes a domain recovery', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cleanupOrphansError: StateError('private orphan detail'),
        );

        unawaited(harness.controller.start());
        async.flushMicrotasks();

        final error = harness.state as RecoverableError;
        expect(error.failure.kind, OcrFailureKind.service);
        harness.dispose(async);
      });
    });

    test('disclosure read failure becomes a domain recovery', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          hasAcceptedError: StateError('private read detail'),
        );

        unawaited(harness.controller.start());
        async.flushMicrotasks();

        final error = harness.state as RecoverableError;
        expect(error.failure.kind, OcrFailureKind.service);
        harness.dispose(async);
      });
    });

    test('disclosure write failure becomes a domain recovery', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          disclosureAccepted: false,
          disclosureAcceptError: StateError('private write detail'),
        );
        unawaited(harness.controller.start());
        async.flushMicrotasks();

        unawaited(harness.controller.acceptDisclosure());
        async.flushMicrotasks();

        final error = harness.state as RecoverableError;
        expect(error.failure.kind, OcrFailureKind.service);
        harness.dispose(async);
      });
    });
  });

  group('pending configuration direct local path', () {
    test('bypasses cloud state, held preparation, and cloud budget', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cloudConfigurationPending: true,
          prepareImmediately: false,
        );
        final observed = <OcrFlowState>[];
        final observer = harness.container.listen<OcrFlowState>(
          ocrFlowControllerProvider,
          (_, next) => observed.add(next),
        );

        harness.startCapture(async);

        expect(observed.whereType<RecognizingCloud>(), isEmpty);
        expect(harness.preparer.canonicalPaths, isEmpty);
        expect(harness.preparer.preparations, isEmpty);
        expect(harness.cloud.requests, isEmpty);
        expect(harness.local.paths, ['/owned/capture-1.jpg']);
        expect(harness.state, isA<RecognizingLocal>());

        async.elapse(const Duration(seconds: 60));
        expect(harness.state, isA<RecognizingLocal>());
        harness.local.complete(0, OcrResult.textDetected('local result'));
        async.flushMicrotasks();

        final result = harness.state as OcrSuccess;
        expect(result.text, 'local result');
        expect(result.engine, OcrEngine.local);
        observer.close();
        harness.dispose(async);
      });
    });

    test('bypasses a failing preparer and surfaces local failure', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cloudConfigurationPending: true,
          prepareError: StateError('preparer must stay unreachable'),
        )..startCapture(async);

        expect(harness.preparer.canonicalPaths, isEmpty);
        expect(harness.cloud.requests, isEmpty);
        expect(harness.local.requests, hasLength(1));

        harness.local.fail(0, StateError('private local detail'));
        async.flushMicrotasks();

        final recovery = harness.state as RecoverableError;
        expect(recovery.failure.kind, OcrFailureKind.recognizer);
        harness.dispose(async);
      });
    });

    test('recapture cleans once and ignores a late local completion', () {
      fakeAsync((async) {
        final harness = _Harness(async, cloudConfigurationPending: true)
          ..startCapture(async);
        expect(harness.local.requests, hasLength(1));

        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg',
          ),
          hasLength(1),
        );

        harness.local.complete(0, OcrResult.textDetected('local late'));
        async.flushMicrotasks();

        expect(harness.state, isA<PreviewReady>());
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg',
          ),
          hasLength(1),
        );
        harness.dispose(async);
      });
    });

    test('dispose cleans once and contains a late local completion', () {
      fakeAsync((async) {
        final harness = _Harness(async, cloudConfigurationPending: true)
          ..startCapture(async);
        expect(harness.local.requests, hasLength(1));

        harness.dispose(async);
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg',
          ),
          hasLength(1),
        );

        harness.local.complete(0, OcrResult.textDetected('local late'));
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg',
          ),
          hasLength(1),
        );
      });
    });
  });

  group('cloud timing and retry policy', () {
    test('9.999 seconds stays active and 10 seconds presents one choice', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);
        final initial = harness.state as RecognizingCloud;

        async.elapse(const Duration(milliseconds: 9999));
        expect((harness.state as RecognizingCloud).takingLonger, isFalse);
        expect(harness.cloud.requests, hasLength(1));

        async.elapse(const Duration(milliseconds: 1));
        final delayed = harness.state as RecognizingCloud;
        expect(delayed.takingLonger, isTrue);
        expect(delayed.transactionId, initial.transactionId);
        expect(delayed.attempt, 1);
        expect(delayed.startedAt, initial.startedAt);
        expect(harness.cloud.requests, hasLength(1));
        harness.dispose(async);
      });
    });

    test(
      'keep waiting preserves the transaction request attempt and deadline',
      () {
        fakeAsync((async) {
          final harness = _Harness(async)..startCloud(async);
          async.elapse(const Duration(seconds: 10));
          final delayed = harness.state as RecognizingCloud;

          harness.controller.keepWaiting();
          final waiting = harness.state as RecognizingCloud;

          expect(waiting.transactionId, delayed.transactionId);
          expect(waiting.attempt, delayed.attempt);
          expect(waiting.startedAt, delayed.startedAt);
          expect(waiting.takingLonger, isFalse);
          expect(harness.cloud.requests, hasLength(1));

          async.elapse(const Duration(seconds: 50));
          final recovery = harness.state as CloudRecovery;
          expect(recovery.failure.kind, OcrFailureKind.deadline);
          expect(harness.cloud.requests, hasLength(1));
          harness.dispose(async);
        });
      },
    );

    test('a transient first failure retries once after injected backoff', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);

        harness.cloud.fail(0, OcrFailure.transportTransient());
        async.flushMicrotasks();
        expect((harness.state as RecognizingCloud).attempt, 1);
        expect(harness.cloud.requests, hasLength(1));

        async.elapse(const Duration(milliseconds: 499));
        expect(harness.cloud.requests, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(harness.cloud.requests, hasLength(2));
        expect((harness.state as RecognizingCloud).attempt, 2);
        harness.dispose(async);
      });
    });

    test('a transient second failure never creates a third cloud attempt', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);
        harness.cloud.fail(0, OcrFailure.transportTransient());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

        harness.cloud.fail(1, OcrFailure.transportTransient());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(harness.cloud.requests, hasLength(2));
        final recovery = harness.state as CloudRecovery;
        expect(recovery.failure.kind, OcrFailureKind.transportTransient);
        harness.dispose(async);
      });
    });

    test('a nonretryable first failure enters recovery after one call', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);

        harness.cloud.fail(0, OcrFailure.quota());
        async.flushMicrotasks();

        final recovery = harness.state as CloudRecovery;
        expect(recovery.failure.kind, OcrFailureKind.quota);
        expect(harness.cloud.requests, hasLength(1));
        harness.dispose(async);
      });
    });

    for (final failureKind in <OcrFailureKind>[
      OcrFailureKind.configuration,
      OcrFailureKind.service,
    ]) {
      test('configured cloud $failureKind keeps recovery policy', () {
        fakeAsync((async) {
          final harness = _Harness(async)..startCloud(async);

          harness.cloud.fail(0, OcrFailure.of(failureKind));
          async.flushMicrotasks();

          final recovery = harness.state as CloudRecovery;
          expect(recovery.failure.kind, failureKind);
          expect(harness.local.paths, isEmpty);
          harness.dispose(async);
        });
      });
    }

    test('retry preserves the original cumulative 60 second deadline', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);

        async.elapse(const Duration(seconds: 30));
        harness.cloud.fail(0, OcrFailure.transportTransient());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));
        expect(harness.cloud.requests, hasLength(2));

        async.elapse(const Duration(milliseconds: 29499));
        expect(harness.state, isA<RecognizingCloud>());
        async.elapse(const Duration(milliseconds: 1));
        final recovery = harness.state as CloudRecovery;
        expect(recovery.failure.kind, OcrFailureKind.deadline);
        expect((harness.state as CloudRecovery).transactionId, isNotEmpty);
        harness.dispose(async);
      });
    });

    test(
      '59.999 seconds is active and 60 seconds invalidates the deadline',
      () {
        fakeAsync((async) {
          final harness = _Harness(async)..startCloud(async);

          async.elapse(const Duration(milliseconds: 59999));
          expect(harness.state, isA<RecognizingCloud>());
          async.elapse(const Duration(milliseconds: 1));

          final recovery = harness.state as CloudRecovery;
          expect(recovery.failure.kind, OcrFailureKind.deadline);
          harness.cloud.complete(0, OcrResult.textDetected('too late'));
          async.flushMicrotasks();
          expect(harness.state, same(recovery));
          harness.dispose(async);
        });
      },
    );

    test('the cumulative timers start before image preparation completes', () {
      fakeAsync((async) {
        final harness = _Harness(async, prepareImmediately: false)
          ..startCapture(async);
        expect(harness.preparer.preparations, hasLength(1));

        async.elapse(const Duration(seconds: 10));
        expect((harness.state as RecognizingCloud).takingLonger, isTrue);
        async.elapse(const Duration(seconds: 50));
        expect(
          (harness.state as CloudRecovery).failure.kind,
          OcrFailureKind.deadline,
        );
        expect(harness.cloud.requests, isEmpty);
        harness.dispose(async);
      });
    });
  });

  group('stale completion and result handling', () {
    test(
      'local selection invalidates and ignores the pending cloud result',
      () {
        fakeAsync((async) {
          final harness = _Harness(async)..startCloud(async);
          async.elapse(const Duration(seconds: 10));

          unawaited(harness.controller.useLocalOcr());
          async.flushMicrotasks();
          expect(harness.state, isA<RecognizingLocal>());
          expect(harness.local.paths, ['/owned/capture-1.jpg']);

          harness.cloud.complete(0, OcrResult.textDetected('cloud late'));
          async.flushMicrotasks();
          expect(harness.state, isA<RecognizingLocal>());

          harness.local.complete(0, OcrResult.textDetected('local result'));
          async.flushMicrotasks();
          final success = harness.state as OcrSuccess;
          expect(success.text, 'local result');
          expect(success.engine, OcrEngine.local);
          harness.dispose(async);
        });
      },
    );

    test('recapture invalidates and ignores a late local completion', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);
        async.elapse(const Duration(seconds: 10));
        unawaited(harness.controller.useLocalOcr());
        async.flushMicrotasks();

        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());

        harness.local.complete(0, OcrResult.textDetected('local late'));
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test('cloud text and empty results retain their engine', () {
      fakeAsync((async) {
        final textHarness = _Harness(async)..startCloud(async);
        textHarness.cloud.complete(0, OcrResult.textDetected('invoice'));
        async.flushMicrotasks();
        final success = textHarness.state as OcrSuccess;
        expect(success.text, 'invoice');
        expect(success.engine, OcrEngine.cloud);
        textHarness.dispose(async);

        final emptyHarness = _Harness(async)..startCloud(async);
        emptyHarness.cloud.complete(0, const OcrResult.noReadableText());
        async.flushMicrotasks();
        expect((emptyHarness.state as OcrEmpty).engine, OcrEngine.cloud);
        emptyHarness.dispose(async);
      });
    });
  });

  group('cleanup and lifecycle', () {
    test('inactive settles a newer never-completing capture marker', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        unawaited(harness.controller.capture());
        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();
        unawaited(harness.controller.capture());

        harness.camera.completeCapture(0, '/owned/older-known.jpg');
        async.flushMicrotasks();
        expect(harness.files.cleanedPaths, isEmpty);

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        expect(harness.files.cleanedPaths, contains('/owned/older-known.jpg'));
        harness.dispose(async);
      });
    });

    test('deadline settles a newer never-completing preparation marker', () {
      fakeAsync((async) {
        final harness = _Harness(async, prepareImmediately: false)
          ..start(async);
        unawaited(harness.controller.capture());
        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();
        harness.startCapture(async, path: '/owned/newer-canonical.jpg');

        harness.camera.completeCapture(0, '/owned/older-known.jpg');
        async.flushMicrotasks();
        expect(harness.files.cleanedPaths, isEmpty);

        async.elapse(const Duration(seconds: 60));
        expect(harness.files.cleanedPaths, contains('/owned/older-known.jpg'));
        expect(harness.state, isA<CloudRecovery>());
        harness.dispose(async);
      });
    });

    test(
      'dispose settles pending producers and does not stall older cleanup',
      () {
        fakeAsync((async) {
          final harness = _Harness(async)..start(async);
          unawaited(harness.controller.capture());
          unawaited(harness.controller.onInactive());
          async.flushMicrotasks();
          unawaited(harness.controller.onResumed());
          async.flushMicrotasks();
          unawaited(harness.controller.capture());
          harness.camera.completeCapture(0, '/owned/older-known.jpg');
          async.flushMicrotasks();
          expect(harness.files.cleanedPaths, isEmpty);

          harness.dispose(async);

          expect(
            harness.files.cleanedPaths,
            contains('/owned/older-known.jpg'),
          );
        });
      },
    );

    test('dispose settles a never-completing preparation before cleanup', () {
      fakeAsync((async) {
        final harness = _Harness(async, prepareImmediately: false)
          ..start(async);
        unawaited(harness.controller.capture());
        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();
        harness.startCapture(async, path: '/owned/newer-canonical.jpg');

        harness.camera.completeCapture(0, '/owned/older-known.jpg');
        async.flushMicrotasks();
        expect(harness.files.cleanedPaths, isEmpty);

        harness.dispose(async);

        expect(
          harness.files.cleanedPaths,
          containsAll(<String>[
            '/owned/older-known.jpg',
            '/owned/newer-canonical.jpg',
          ]),
        );
      });
    });

    test('older capture cleanup cannot delete newer active same path', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        unawaited(harness.controller.capture());
        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();

        unawaited(harness.controller.capture());
        harness.camera.completeCapture(1, '/owned/reused.jpg');
        async.flushMicrotasks();
        final newerRecognition = harness.state;

        harness.camera.completeCapture(0, '/owned/reused.jpg');
        async.flushMicrotasks();

        expect(harness.state, same(newerRecognition));
        expect(
          harness.files.cleanedPaths,
          isNot(contains('/owned/reused.jpg')),
        );
        harness.cloud.complete(0, OcrResult.textDetected('newer'));
        async.flushMicrotasks();
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/reused.jpg',
          ),
          hasLength(1),
        );
        harness.dispose(async);
      });
    });

    test('older late capture cleans after newer same path is released', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        unawaited(harness.controller.capture());
        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();

        unawaited(harness.controller.capture());
        harness.camera.completeCapture(1, '/owned/reused-late.jpg');
        async.flushMicrotasks();
        harness.cloud.complete(0, OcrResult.textDetected('newer'));
        async.flushMicrotasks();
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/reused-late.jpg',
          ),
          hasLength(1),
        );

        harness.camera.completeCapture(0, '/owned/reused-late.jpg');
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/reused-late.jpg',
          ),
          hasLength(2),
        );
        harness.dispose(async);
      });
    });

    test('older capture waits for newer pending path claim', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        unawaited(harness.controller.capture());
        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();

        unawaited(harness.controller.capture());
        harness.camera.completeCapture(0, '/owned/reused.jpg');
        async.flushMicrotasks();
        expect(harness.files.cleanedPaths, isEmpty);

        harness.camera.completeCapture(1, '/owned/reused.jpg');
        async.flushMicrotasks();
        expect(harness.files.cleanedPaths, isEmpty);
        expect(harness.cloud.requests, hasLength(1));
        harness.dispose(async);
      });
    });

    test('older preparation cannot delete newer prepared same path', () {
      fakeAsync((async) {
        final harness = _Harness(async, prepareImmediately: false)
          ..startCapture(async);
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        harness.startCapture(async);

        harness.preparer.complete(
          1,
          canonicalPath: '/owned/capture-1.jpg',
          cloudPath: '/owned/shared-prepared.jpg',
        );
        async.flushMicrotasks();
        final newerRecognition = harness.state;
        harness.preparer.complete(
          0,
          canonicalPath: '/owned/capture-1.jpg',
          cloudPath: '/owned/shared-prepared.jpg',
        );
        async.flushMicrotasks();

        expect(harness.state, same(newerRecognition));
        expect(
          harness.files.cleanedPaths,
          isNot(contains('/owned/shared-prepared.jpg')),
        );
        harness.dispose(async);
      });
    });

    test('older late preparation cleans after newer claim is released', () {
      fakeAsync((async) {
        final harness = _Harness(async, prepareImmediately: false)
          ..startCapture(async);
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        harness.startCapture(async);
        harness.preparer.complete(
          1,
          canonicalPath: '/owned/capture-1.jpg',
          cloudPath: '/owned/released-prepared.jpg',
        );
        async.flushMicrotasks();
        harness.cloud.complete(0, OcrResult.textDetected('newer'));
        async.flushMicrotasks();
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/released-prepared.jpg',
          ),
          hasLength(1),
        );

        harness.preparer.complete(
          0,
          canonicalPath: '/owned/capture-1.jpg',
          cloudPath: '/owned/released-prepared.jpg',
        );
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/released-prepared.jpg',
          ),
          hasLength(2),
        );
        harness.dispose(async);
      });
    });

    test('capture is gated while physical cleanup is unresolved', () {
      fakeAsync((async) {
        final harness = _Harness(async, cleanupImmediately: false)
          ..start(async);
        unawaited(harness.controller.capture());
        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();
        harness.camera.completeCapture(0, '/owned/stale.jpg');
        async.flushMicrotasks();
        expect(harness.files.pendingCleanups, hasLength(1));

        unawaited(harness.controller.capture());
        expect(harness.camera.captureCount, 1);

        harness.files.completeCleanup(0);
        async.flushMicrotasks();
        unawaited(harness.controller.capture());
        expect(harness.camera.captureCount, 2);
        harness.dispose(async);
      });
    });

    test('recapture and dispose clean every owned path exactly once', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);
        harness.cloud.complete(0, OcrResult.textDetected('first'));
        async.flushMicrotasks();

        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());

        harness.startCapture(async, path: '/owned/capture-2.jpg');
        harness.dispose(async);

        expect(
          harness.files.cleanedPaths.toList(),
          containsAll(<String>[
            '/owned/capture-1.jpg',
            '/owned/capture-1.jpg.prepared',
            '/owned/capture-2.jpg',
            '/owned/capture-2.jpg.prepared',
          ]),
        );
        for (final path in harness.files.cleanedPaths.toSet()) {
          expect(
            harness.files.cleanedPaths.where((item) => item == path),
            hasLength(1),
            reason: '$path must be deleted once',
          );
        }
      });
    });

    test('a reused path is cleaned once for each file ownership', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);
        harness.cloud.complete(0, OcrResult.textDetected('first'));
        async.flushMicrotasks();
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        harness.startCapture(async);
        harness.dispose(async);

        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg',
          ),
          hasLength(2),
        );
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg.prepared',
          ),
          hasLength(2),
        );
      });
    });

    test('late preparation records and cleans its derived path once', () {
      fakeAsync((async) {
        final harness = _Harness(async, prepareImmediately: false)
          ..startCapture(async);

        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        harness.preparer.complete(
          0,
          canonicalPath: '/owned/capture-1.jpg',
          cloudPath: '/owned/capture-1-derived.jpg',
        );
        async.flushMicrotasks();

        expect(harness.state, isA<PreviewReady>());
        expect(harness.cloud.requests, isEmpty);
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg',
          ),
          hasLength(1),
        );
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1-derived.jpg',
          ),
          hasLength(1),
        );
        harness.dispose(async);
      });
    });

    test('late cleanup failure cannot replace deadline recovery', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          prepareImmediately: false,
          cleanupError: StateError('cleanup failed'),
        )..startCapture(async);
        async.elapse(const Duration(seconds: 60));
        final deadlineRecovery = harness.state;

        harness.preparer.complete(
          0,
          canonicalPath: '/owned/capture-1.jpg',
          cloudPath: '/owned/capture-1-derived.jpg',
        );
        async.flushMicrotasks();

        expect(harness.state, same(deadlineRecovery));
        harness.dispose(async);
      });
    });

    test('active recapture cleanup failure becomes domain recovery', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cleanupError: StateError('private cleanup detail'),
        )..startCloud(async);

        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        final error = harness.state as RecoverableError;
        expect(error.failure.kind, OcrFailureKind.service);
        harness.dispose(async);
      });
    });

    test('failed recapture cleanup retains paths for a later retry', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);
        harness.files.cleanupError = StateError('first cleanup failed');
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(harness.state, isA<RecoverableError>());

        harness.files.cleanupError = null;
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();

        expect(
          harness.files.cleanupCalls.where(
            (paths) => paths.contains('/owned/capture-1.jpg'),
          ),
          hasLength(2),
        );
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test('dispose attempts later owners after an earlier cleanup fails', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        unawaited(harness.controller.capture());
        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();
        unawaited(harness.controller.capture());

        harness.files.cleanupOutcomes.add(StateError('stale cleanup failed'));
        harness.camera.completeCapture(0, '/owned/owner-1.jpg');
        async.flushMicrotasks();
        harness.camera.completeCapture(1, '/owned/owner-2.jpg');
        async.flushMicrotasks();
        expect(harness.cloud.requests, hasLength(1));

        harness.files.cleanupOutcomes.addAll([
          StateError('owner 1 failed again'),
          null,
        ]);
        harness.dispose(async);

        expect(
          harness.files.cleanupCalls.where(
            (paths) => paths.contains('/owned/owner-1.jpg'),
          ),
          hasLength(2),
        );
        expect(
          harness.files.cleanupCalls.where(
            (paths) => paths.contains('/owned/owner-2.jpg'),
          ),
          hasLength(1),
        );
      });
    });

    test('deadline late preparation preserves canonical for local OCR', () {
      fakeAsync((async) {
        final harness = _Harness(async, prepareImmediately: false)
          ..startCapture(async);
        async.elapse(const Duration(seconds: 60));
        expect(harness.state, isA<CloudRecovery>());

        harness.preparer.complete(
          0,
          canonicalPath: '/owned/capture-1.jpg',
          cloudPath: '/owned/deadline-derived.jpg',
        );
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths,
          isNot(contains('/owned/capture-1.jpg')),
        );
        expect(
          harness.files.cleanedPaths,
          contains('/owned/deadline-derived.jpg'),
        );

        unawaited(harness.controller.useLocalOcr());
        async.flushMicrotasks();
        expect(harness.local.paths, ['/owned/capture-1.jpg']);
        harness.local.complete(0, OcrResult.textDetected('local'));
        async.flushMicrotasks();
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg',
          ),
          hasLength(1),
        );
        harness.dispose(async);
      });
    });

    test('local in flight late preparation preserves canonical input', () {
      fakeAsync((async) {
        final harness = _Harness(async, prepareImmediately: false)
          ..startCapture(async);
        async.elapse(const Duration(seconds: 10));
        unawaited(harness.controller.useLocalOcr());
        async.flushMicrotasks();
        expect(harness.local.paths, ['/owned/capture-1.jpg']);

        harness.preparer.complete(
          0,
          canonicalPath: '/owned/capture-1.jpg',
          cloudPath: '/owned/local-derived.jpg',
        );
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths,
          isNot(contains('/owned/capture-1.jpg')),
        );
        expect(
          harness.files.cleanedPaths,
          contains('/owned/local-derived.jpg'),
        );

        harness.local.complete(0, OcrResult.textDetected('local'));
        async.flushMicrotasks();
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(
          harness.files.cleanedPaths.where(
            (path) => path == '/owned/capture-1.jpg',
          ),
          hasLength(1),
        );
        harness.dispose(async);
      });
    });

    test('inactive capture is disposed and its late callback stays stale', () {
      fakeAsync((async) {
        final harness = _Harness(async)..start(async);
        unawaited(harness.controller.capture());

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        expect(harness.camera.disposeCount, 1);

        harness.camera.completeCapture(0, '/owned/stale-capture.jpg');
        async.flushMicrotasks();
        expect(harness.cloud.requests, isEmpty);
        expect(
          harness.files.cleanedPaths,
          contains('/owned/stale-capture.jpg'),
        );

        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();
        expect(harness.camera.initializeCount, 2);
        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test('inactive invalidates a recapture waiting for file cleanup', () {
      fakeAsync((async) {
        final harness = _Harness(async, cleanupImmediately: false)
          ..startCloud(async);

        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(harness.files.pendingCleanups, hasLength(1));

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        harness.files.completeCleanup(0);
        async.flushMicrotasks();

        expect(harness.camera.initializeCount, 1);
        expect(harness.state, isNot(isA<PreviewReady>()));
        harness.dispose(async);
      });
    });

    test('resume does not initialize a camera while OCR owns the flow', () {
      fakeAsync((async) {
        final harness = _Harness(async)..startCloud(async);

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();
        unawaited(harness.controller.onResumed());
        async.flushMicrotasks();

        expect(harness.camera.initializeCount, 1);
        expect(harness.state, isA<RecognizingCloud>());
        harness.dispose(async);
      });
    });

    test('active camera disposal failure becomes domain recovery', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cameraDisposeError: StateError('private camera detail'),
        )..start(async);

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();

        final error = harness.state as RecoverableError;
        expect(error.failure.kind, OcrFailureKind.service);
        harness.dispose(async);
      });
    });

    test('camera disposal failure cannot replace active cloud state', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cameraDisposeError: StateError('private camera detail'),
        )..startCloud(async);
        final recognizing = harness.state;

        unawaited(harness.controller.onInactive());
        async.flushMicrotasks();

        expect(harness.state, same(recognizing));
        harness.dispose(async);
      });
    });

    test('open settings delegates without changing flow state', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cameraPermission: CameraPermissionState.denied,
        )..start(async);
        final before = harness.state;

        unawaited(harness.controller.openSettings());
        async.flushMicrotasks();

        expect(harness.settings.openCount, 1);
        expect(harness.state, same(before));
        harness.dispose(async);
      });
    });

    test('settings launch failure becomes a domain recovery', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cameraPermission: CameraPermissionState.denied,
          settingsError: StateError('private settings detail'),
        )..start(async);
        expect(harness.state, isA<PermissionDenied>());

        unawaited(harness.controller.openSettings());
        async.flushMicrotasks();

        final error = harness.state as RecoverableError;
        expect(error.failure.kind, OcrFailureKind.service);
        harness.dispose(async);
      });
    });

    test('stale settings failure cannot replace a newer preview', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cameraPermission: CameraPermissionState.denied,
        )..start(async);
        harness.settings.holdOpen = true;
        unawaited(harness.controller.openSettings());
        async.flushMicrotasks();

        harness.camera.permission = CameraPermissionState.granted;
        unawaited(harness.controller.recapture());
        async.flushMicrotasks();
        expect(harness.state, isA<PreviewReady>());
        harness.settings.failOpen(0, StateError('private stale detail'));
        async.flushMicrotasks();

        expect(harness.state, isA<PreviewReady>());
        harness.dispose(async);
      });
    });

    test('dispose contains camera and file cleanup failures', () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          cameraDisposeError: StateError('private camera detail'),
          cleanupError: StateError('private cleanup detail'),
        )..startCloud(async);

        harness.dispose(async);

        expect(harness.camera.disposeCount, 1);
        expect(harness.files.cleanupCalls, isNotEmpty);
      });
    });
  });
}

final class _Harness {
  _Harness(
    FakeAsync async, {
    CameraPermissionState cameraPermission = CameraPermissionState.granted,
    Object? cameraInitializeError,
    Object? cameraDisposeError,
    bool disclosureAccepted = true,
    bool holdDisclosureAccept = false,
    bool holdDisclosureRead = false,
    Object? hasAcceptedError,
    Object? disclosureAcceptError,
    bool prepareImmediately = true,
    Object? prepareError,
    bool cleanupImmediately = true,
    bool holdCleanupOrphans = false,
    Object? cleanupError,
    Object? cleanupOrphansError,
    Object? settingsError,
    bool cloudConfigurationPending = false,
  }) : camera = ControllableCameraRepository(
         permission: cameraPermission,
         initializeError: cameraInitializeError,
         disposeError: cameraDisposeError,
       ),
       disclosure = MemoryDisclosureStore(
         accepted: disclosureAccepted,
         holdHasAccepted: holdDisclosureRead,
         holdAccept: holdDisclosureAccept,
         hasAcceptedError: hasAcceptedError,
         acceptError: disclosureAcceptError,
       ),
       preparer = ControllableImagePreparer(
         completeImmediately: prepareImmediately,
         prepareError: prepareError,
       ),
       files = RecordingTransactionFiles(
         completeImmediately: cleanupImmediately,
         cleanupError: cleanupError,
         holdCleanupOrphans: holdCleanupOrphans,
         cleanupOrphansError: cleanupOrphansError,
       ),
       settings = RecordingAppSettingsLauncher()..openError = settingsError {
    cloud = ControllableCloudOcrService(
      configurationPending: cloudConfigurationPending,
    );
    final clock = async.getClock(DateTime.utc(2026, 9, 28, 12));
    container = ProviderContainer(
      overrides: [
        cameraRepositoryProvider.overrideWithValue(camera),
        disclosureStoreProvider.overrideWithValue(disclosure),
        cloudOcrServiceProvider.overrideWithValue(cloud),
        localOcrServiceProvider.overrideWithValue(local),
        imagePreparerProvider.overrideWithValue(preparer),
        transactionFilesProvider.overrideWithValue(files),
        appSettingsLauncherProvider.overrideWithValue(settings),
        ocrNowProvider.overrideWithValue(clock.now),
        ocrRetryDelayProvider.overrideWithValue(
          (_) => const Duration(milliseconds: 500),
        ),
      ],
    );
    subscription = container.listen<OcrFlowState>(
      ocrFlowControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
  }

  final ControllableCameraRepository camera;
  late final ControllableCloudOcrService cloud;
  final ControllableLocalOcrService local = ControllableLocalOcrService();
  final MemoryDisclosureStore disclosure;
  final ControllableImagePreparer preparer;
  final RecordingTransactionFiles files;
  final RecordingAppSettingsLauncher settings;
  late final ProviderContainer container;
  late final ProviderSubscription<OcrFlowState> subscription;

  OcrFlowController get controller =>
      container.read(ocrFlowControllerProvider.notifier);

  OcrFlowState get state => container.read(ocrFlowControllerProvider);

  void start(FakeAsync async) {
    unawaited(controller.start());
    async.flushMicrotasks();
  }

  void startCapture(FakeAsync async, {String path = '/owned/capture-1.jpg'}) {
    start(async);
    unawaited(controller.capture());
    camera.completeCapture(camera.captures.length - 1, path);
    async.flushMicrotasks();
  }

  void startCloud(FakeAsync async, {String path = '/owned/capture-1.jpg'}) {
    startCapture(async, path: path);
    expect(cloud.requests, isNotEmpty);
  }

  void dispose(FakeAsync async) {
    subscription.close();
    container.dispose();
    async.flushMicrotasks();
  }
}
