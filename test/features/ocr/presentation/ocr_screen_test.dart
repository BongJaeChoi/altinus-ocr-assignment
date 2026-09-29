import 'package:altinus_ocr/features/camera/camera_models.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_providers.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:altinus_ocr/features/ocr/presentation/ocr_copy.dart';
import 'package:altinus_ocr/features/ocr/presentation/ocr_screen.dart';

import '../../../support/ocr_fakes.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrScreen', () {
    testWidgets(
      'explains the first-run camera, cloud transfer, and storage terms',
      (tester) async {
        final harness = await _pump(tester);

        expect(find.textContaining('글자를 촬영'), findsOneWidget);
        expect(find.textContaining('클라우드'), findsOneWidget);
        expect(find.textContaining('영구 저장하지'), findsOneWidget);
        expect(find.byKey(const ValueKey('disclosure-accept')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('disclosure-accept')));
        await tester.pump();
        await tester.pump();

        expect(harness.disclosure.acceptCount, 1);
        expect(find.byKey(const ValueKey('capture')), findsOneWidget);
      },
    );

    testWidgets('permission recovery dispatches settings and a natural retry', (
      tester,
    ) async {
      final harness = await _pump(
        tester,
        accepted: true,
        permission: CameraPermissionState.denied,
      );

      expect(find.textContaining('권한'), findsWidgets);
      expect(find.byKey(const ValueKey('open-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('recapture')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('open-settings')));
      await tester.pump();
      expect(harness.settings.openCount, 1);

      harness.camera.permission = CameraPermissionState.granted;
      await tester.tap(find.byKey(const ValueKey('recapture')));
      await tester.pump();
      await tester.pump();
      expect(harness.camera.initializeCount, 2);
      expect(find.byKey(const ValueKey('capture')), findsOneWidget);
    });

    testWidgets('preview capture dispatches one capture action', (
      tester,
    ) async {
      final harness = await _pumpAtPreview(tester);

      await tester.tap(find.byKey(const ValueKey('capture')));
      await tester.pump();

      expect(harness.camera.captureCount, 1);
      expect(find.textContaining('촬영'), findsWidgets);
    });

    testWidgets(
      'a failed start recapture returns to disclosure before camera use',
      (tester) async {
        final harness = await _pump(
          tester,
          accepted: false,
          filesCleanupError: Exception(
            'Firebase Gemini ML Kit Pigeon HTTP 503 raw',
          ),
        );

        await tester.tap(find.byKey(const ValueKey('recapture')));
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const ValueKey('disclosure-accept')), findsOneWidget);
        expect(harness.camera.initializeCount, 0);
      },
    );

    testWidgets('camera initialization exposes controller-backed recapture', (
      tester,
    ) async {
      final harness = await _pump(tester, accepted: true, holdInitialize: true);
      await tester.tap(find.byKey(const ValueKey('recapture')));
      await tester.pump();

      expect(harness.camera.initializeCount, 2);
      harness.camera.holdInitialize = false;
      harness.camera.completeInitialize(1);
      await tester.pump();
      await tester.pump();
    });

    testWidgets('capture progress exposes controller-backed recapture', (
      tester,
    ) async {
      await _pumpAtPreview(tester);
      await tester.tap(find.byKey(const ValueKey('capture')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('recapture')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('capture')), findsOneWidget);
    });

    testWidgets('local recognition exposes controller-backed recapture', (
      tester,
    ) async {
      final harness = await _pumpAtPreview(tester);
      await _beginCloudRecognition(tester, harness);
      await tester.pump(const Duration(seconds: 10));
      await tester.tap(find.byKey(const ValueKey('use-local')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('recapture')));
      await tester.pump();

      expect(find.byKey(const ValueKey('capture')), findsOneWidget);
    });

    testWidgets(
      'cloud recognition displays exact first and second attempt counters',
      (tester) async {
        final harness = await _pumpAtPreview(
          tester,
          retryDelay: (_) => Duration.zero,
        );
        await _beginCloudRecognition(tester, harness);

        expect(find.text('1/2'), findsOneWidget);
        harness.cloud.fail(0, OcrFailure.transportTransient());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();

        expect(find.text('2/2'), findsOneWidget);
      },
    );

    testWidgets(
      'slow cloud recognition offers local OCR and continued waiting',
      (tester) async {
        final harness = await _pumpAtPreview(tester);
        await _beginCloudRecognition(tester, harness);

        await tester.pump(const Duration(seconds: 10));

        expect(find.byKey(const ValueKey('use-local')), findsOneWidget);
        expect(find.byKey(const ValueKey('keep-waiting')), findsOneWidget);
        expect(find.textContaining('조금 더 기다리기'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('keep-waiting')));
        await tester.pump();
        expect(find.text('1/2'), findsOneWidget);
      },
    );

    testWidgets('slow cloud local action starts local recognition', (
      tester,
    ) async {
      final harness = await _pumpAtPreview(tester);
      await _beginCloudRecognition(tester, harness);
      await tester.pump(const Duration(seconds: 10));

      await tester.tap(find.byKey(const ValueKey('use-local')));
      await tester.pump();

      expect(harness.local.requests, hasLength(1));
    });

    testWidgets(
      'cloud text result can switch once to local without a cloud loop',
      (tester) async {
        final harness = await _pumpAtPreview(tester);
        await _beginCloudRecognition(tester, harness);
        harness.cloud.complete(0, OcrResult.textDetected('클라우드 결과'));
        await tester.pump();

        expect(find.text('클라우드 결과'), findsOneWidget);
        expect(find.byKey(const ValueKey('use-local')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('use-local')));
        await tester.pump();
        expect(harness.local.requests, hasLength(1));

        harness.local.complete(0, OcrResult.textDetected('기기 결과'));
        await tester.pump();
        expect(find.text('기기 결과'), findsOneWidget);
        expect(find.byKey(const ValueKey('use-local')), findsNothing);
        expect(find.byType(SelectableText), findsNothing);
      },
    );

    testWidgets('cloud empty state offers recapture and local OCR', (
      tester,
    ) async {
      final harness = await _pumpAtPreview(tester);
      await _beginCloudRecognition(tester, harness);
      harness.cloud.complete(0, const OcrResult.noReadableText());
      await tester.pump();

      expect(find.byKey(const ValueKey('recapture')), findsOneWidget);
      expect(find.byKey(const ValueKey('use-local')), findsOneWidget);
    });

    testWidgets('local empty state offers recapture without another OCR loop', (
      tester,
    ) async {
      final harness = await _pumpAtPreview(tester);
      await _beginCloudRecognition(tester, harness);
      harness.cloud.complete(0, const OcrResult.noReadableText());
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('use-local')));
      await tester.pump();
      harness.local.complete(0, const OcrResult.noReadableText());
      await tester.pump();

      expect(find.byKey(const ValueKey('recapture')), findsOneWidget);
      expect(find.byKey(const ValueKey('use-local')), findsNothing);
    });

    testWidgets('cloud failure offers local OCR and recapture', (tester) async {
      final harness = await _pumpAtPreview(tester);
      await _beginCloudRecognition(tester, harness);
      harness.cloud.fail(0, OcrFailure.quota());
      await tester.pump();

      expect(find.byKey(const ValueKey('use-local')), findsOneWidget);
      expect(find.byKey(const ValueKey('recapture')), findsOneWidget);
    });

    testWidgets(
      'pending cloud configuration reaches a local result without a recovery tap',
      (tester) async {
        final harness = await _pumpAtPreview(
          tester,
          cloudConfigurationPending: true,
        );
        await tester.tap(find.byKey(const ValueKey('capture')));
        await tester.pump();
        harness.camera.completeCapture(0, '/temporary/photo.jpg');
        await tester.pump();
        await tester.pump();

        expect(harness.cloud.requests, isEmpty);
        expect(harness.preparer.canonicalPaths, isEmpty);
        expect(harness.local.requests, hasLength(1));
        expect(find.byKey(const ValueKey('use-local')), findsNothing);
        expect(find.text(OcrCopy.cloudRecovery), findsNothing);

        harness.local.complete(0, OcrResult.textDetected('기기 인식 결과'));
        await tester.pump();
        expect(find.text('기기 인식 결과'), findsOneWidget);
      },
    );

    testWidgets('configured cloud configuration failure remains recoverable', (
      tester,
    ) async {
      final harness = await _pumpAtPreview(tester);
      await _beginCloudRecognition(tester, harness);

      harness.cloud.fail(0, OcrFailure.of(OcrFailureKind.configuration));
      await tester.pump();

      expect(harness.local.requests, isEmpty);
      expect(find.byKey(const ValueKey('use-local')), findsOneWidget);
      expect(find.text(OcrCopy.cloudRecovery), findsOneWidget);
    });

    testWidgets('technical failure details are never rendered', (tester) async {
      await _pump(
        tester,
        filesCleanupError: Exception(
          'Firebase Gemini ML Kit Pigeon HTTP 503 raw exception detail',
        ),
      );

      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .join('\n');
      expect(text, isNot(contains('Firebase')));
      expect(text, isNot(contains('Gemini')));
      expect(text, isNot(contains('ML Kit')));
      expect(text, isNot(contains('Pigeon')));
      expect(text, isNot(contains('HTTP')));
      expect(text, isNot(matches(RegExp(r'\b[45]\d{2}\b'))));
      expect(find.byKey(const ValueKey('recapture')), findsOneWidget);
      expect(find.text('잠시 문제가 생겼어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets(
      'small viewport and large text keep the recovery action reachable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 360));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final harness = await _pumpAtPreview(tester, textScaleFactor: 2);
        await _beginCloudRecognition(tester, harness);
        await tester.pump(const Duration(seconds: 10));

        final local = find.byKey(const ValueKey('use-local'));
        await tester.ensureVisible(local);
        expect(tester.getSize(local).height, greaterThanOrEqualTo(48));
        await tester.tap(local);
        await tester.pump();
        expect(harness.local.requests, hasLength(1));

        await tester.pumpWidget(const SizedBox());
        final waitingHarness = await _pumpAtPreview(tester, textScaleFactor: 2);
        await _beginCloudRecognition(tester, waitingHarness);
        await tester.pump(const Duration(seconds: 10));
        final waiting = find.byKey(const ValueKey('keep-waiting'));
        await tester.ensureVisible(waiting);
        expect(tester.getSize(waiting).height, greaterThanOrEqualTo(48));
        await tester.tap(waiting);
        await tester.pump();
        expect(find.text('1/2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('every state change uses the stable live region and headings', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final harness = await _pumpAtPreview(tester);
      final heading = tester.semantics.find(find.text(OcrCopy.previewTitle));
      expect(heading.flagsCollection.isHeader, isTrue);
      final previewRegion = tester.semantics.find(
        find.byKey(const ValueKey('status-live-region')),
      );
      expect(previewRegion.flagsCollection.isLiveRegion, isTrue);

      await _beginCloudRecognition(tester, harness);
      final progress = tester.semantics.find(
        find.byKey(const ValueKey('status-live-region')),
      );
      expect(progress.flagsCollection.isLiveRegion, isTrue);
      await tester.pumpWidget(const SizedBox());
      final denied = await _pump(
        tester,
        accepted: true,
        permission: CameraPermissionState.denied,
      );
      expect(denied.camera.initializeCount, 1);
      final deniedRegion = tester.semantics.find(
        find.byKey(const ValueKey('status-live-region')),
      );
      expect(deniedRegion.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('disposing before the post-frame callback is safe', (
      tester,
    ) async {
      final harness = _Harness(
        accepted: true,
        permission: CameraPermissionState.granted,
        retryDelay: null,
        filesCleanupError: null,
      );
      await tester.pumpWidget(
        _screenWithHarness(harness),
        phase: EnginePhase.build,
      );
      await tester.pumpWidget(const SizedBox(), phase: EnginePhase.build);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(harness.files.cleanupOrphansCount, 0);
    });

    testWidgets('rebuilds start the controller exactly once', (tester) async {
      final harness = _Harness(
        accepted: true,
        permission: CameraPermissionState.granted,
        retryDelay: null,
        filesCleanupError: null,
      );
      StateSetter? rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _screenWithHarness(harness);
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      rebuild!(() {});
      await tester.pump();

      expect(harness.files.cleanupOrphansCount, 1);
    });
  });
}

Future<_Harness> _pump(
  WidgetTester tester, {
  bool accepted = false,
  CameraPermissionState permission = CameraPermissionState.granted,
  Duration Function(int)? retryDelay,
  Object? filesCleanupError,
  bool holdInitialize = false,
  double textScaleFactor = 1,
  bool cloudConfigurationPending = false,
}) async {
  final harness = _Harness(
    accepted: accepted,
    permission: permission,
    retryDelay: retryDelay,
    filesCleanupError: filesCleanupError,
    cloudConfigurationPending: cloudConfigurationPending,
  );
  harness.camera.holdInitialize = holdInitialize;
  await tester.pumpWidget(
    _screenWithHarness(harness, textScaleFactor: textScaleFactor),
  );
  await tester.pump();
  await tester.pump();
  return harness;
}

Widget _screenWithHarness(_Harness harness, {double textScaleFactor = 1}) =>
    ProviderScope(
      key: ValueKey(harness),
      overrides: [
        cameraRepositoryProvider.overrideWithValue(harness.camera),
        disclosureStoreProvider.overrideWithValue(harness.disclosure),
        cloudOcrServiceProvider.overrideWithValue(harness.cloud),
        localOcrServiceProvider.overrideWithValue(harness.local),
        imagePreparerProvider.overrideWithValue(harness.preparer),
        transactionFilesProvider.overrideWithValue(harness.files),
        appSettingsLauncherProvider.overrideWithValue(harness.settings),
        ocrRetryDelayProvider.overrideWithValue(harness.retryDelay),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
          child: const OcrScreen(),
        ),
      ),
    );

Future<_Harness> _pumpAtPreview(
  WidgetTester tester, {
  Duration Function(int)? retryDelay,
  double textScaleFactor = 1,
  bool cloudConfigurationPending = false,
}) async {
  final harness = await _pump(
    tester,
    accepted: true,
    retryDelay: retryDelay,
    textScaleFactor: textScaleFactor,
    cloudConfigurationPending: cloudConfigurationPending,
  );
  expect(find.byKey(const ValueKey('capture')), findsOneWidget);
  return harness;
}

Future<void> _beginCloudRecognition(
  WidgetTester tester,
  _Harness harness,
) async {
  await tester.ensureVisible(find.byKey(const ValueKey('capture')));
  await tester.tap(find.byKey(const ValueKey('capture')));
  await tester.pump();
  harness.camera.completeCapture(0, '/temporary/photo.jpg');
  await tester.pump();
  await tester.pump();
  expect(harness.cloud.requests, hasLength(1));
}

final class _Harness {
  _Harness({
    required bool accepted,
    required CameraPermissionState permission,
    required Duration Function(int)? retryDelay,
    required Object? filesCleanupError,
    bool cloudConfigurationPending = false,
  }) : disclosure = MemoryDisclosureStore(accepted: accepted),
       camera = ControllableCameraRepository(permission: permission),
       cloud = ControllableCloudOcrService(
         configurationPending: cloudConfigurationPending,
       ),
       local = ControllableLocalOcrService(),
       preparer = ControllableImagePreparer(),
       files = RecordingTransactionFiles(
         cleanupOrphansError: filesCleanupError,
       ),
       settings = RecordingAppSettingsLauncher(),
       retryDelay = retryDelay ?? ((_) => const Duration(milliseconds: 1));

  final MemoryDisclosureStore disclosure;
  final ControllableCameraRepository camera;
  final ControllableCloudOcrService cloud;
  final ControllableLocalOcrService local;
  final ControllableImagePreparer preparer;
  final RecordingTransactionFiles files;
  final RecordingAppSettingsLauncher settings;
  final Duration Function(int) retryDelay;
}
