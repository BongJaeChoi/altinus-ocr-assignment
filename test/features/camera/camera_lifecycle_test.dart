import 'package:altinus_ocr/features/camera/camera_models.dart';
import 'package:altinus_ocr/features/camera/camera_preview_surface.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_providers.dart';
import 'package:altinus_ocr/features/ocr/presentation/ocr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ocr_fakes.dart';

void main() {
  testWidgets('non-plugin repositories render a neutral preview fallback', (
    tester,
  ) async {
    final camera = ControllableCameraRepository();

    await tester.pumpWidget(
      MaterialApp(home: CameraPreviewSurface(repository: camera)),
    );

    expect(find.byKey(const ValueKey('camera-preview-placeholder')), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive disposes once and resumed reinitializes', (
    tester,
  ) async {
    final harness = _LifecycleHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump();
    await tester.pump();
    expect(harness.camera.initializeCount, 1);
    await tester.tap(find.byKey(const ValueKey('flash-off')));
    await tester.pump();
    expect(harness.camera.flashModes, [CameraFlashMode.off]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(harness.camera.disposeCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(harness.camera.initializeCount, 2);
    expect(find.byKey(const ValueKey('capture')), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('flash-auto')))
          .selected,
      isTrue,
    );
  });

  testWidgets(
    'inactive hidden paused resumed forwards one teardown and one restart',
    (tester) async {
      final harness = _LifecycleHarness();
      await tester.pumpWidget(harness.widget);
      await tester.pump();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(harness.camera.disposeCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(harness.camera.initializeCount, 2);
    },
  );

  testWidgets(
    'permission-sheet inactive keeps the pending initialization alive',
    (tester) async {
      final harness = _LifecycleHarness(
        permission: CameraPermissionState.denied,
        holdInitialize: true,
      );
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      await tester.pumpWidget(harness.widget);
      await tester.pump();
      await tester.pump();
      expect(harness.camera.initializeCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(harness.camera.disposeCount, 0);
      expect(harness.camera.initializeCount, 1);
      harness.camera.completeInitialize(0);
      await tester.pump();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(harness.camera.initializeCount, 1);
      expect(find.byKey(const ValueKey('open-settings')), findsOneWidget);
    },
  );

  testWidgets('inactive granted initialization is parked before resume', (
    tester,
  ) async {
    final harness = _LifecycleHarness(holdInitialize: true);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.pumpWidget(harness.widget);
    await tester.pump();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(harness.camera.disposeCount, 0);

    harness.camera.completeInitialize(0);
    await tester.pump();
    await tester.pump();
    expect(harness.camera.disposeCount, 1);

    harness.camera.holdInitialize = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(harness.camera.initializeCount, 2);
    expect(harness.camera.maxConcurrentInitializationCount, 1);
    expect(find.byKey(const ValueKey('capture')), findsOneWidget);
  });

  for (final backgroundState in [
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    testWidgets(
      '${backgroundState.name} cancels deferred initialization before resume',
      (tester) async {
        final harness = _LifecycleHarness(holdInitialize: true);
        addTearDown(() {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        });
        await tester.pumpWidget(harness.widget);
        await tester.pump();
        await tester.pump();

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(backgroundState);
        await tester.pump();

        expect(harness.camera.disposeCount, 1);
        expect(harness.camera.wasInitializeCancelled(0), isTrue);

        harness.camera.holdInitialize = false;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();

        expect(harness.camera.initializeCount, 2);
        expect(harness.camera.maxConcurrentInitializationCount, 1);
        expect(find.byKey(const ValueKey('capture')), findsOneWidget);
      },
    );
  }

  for (final initialState in [
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    testWidgets('mount while ${initialState.name} waits for resume to start', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(initialState);
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      final harness = _LifecycleHarness();

      await tester.pumpWidget(harness.widget);
      await tester.pump();
      await tester.pump();

      expect(harness.files.cleanupOrphansCount, 0);
      expect(harness.camera.initializeCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(harness.files.cleanupOrphansCount, 1);
      expect(harness.camera.initializeCount, 1);
      expect(find.byKey(const ValueKey('capture')), findsOneWidget);
    });
  }

  testWidgets('unsupported flash keeps auto/off controls hidden', (
    tester,
  ) async {
    final harness = _LifecycleHarness(flashSupported: false);
    await tester.pumpWidget(harness.widget);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('flash-auto')), findsNothing);
    expect(find.byKey(const ValueKey('flash-off')), findsNothing);
    expect(find.byKey(const ValueKey('capture')), findsOneWidget);
  });

  testWidgets('observer removal prevents callbacks after screen disposal', (
    tester,
  ) async {
    final harness = _LifecycleHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final disposeCount = harness.camera.disposeCount;
    final initializeCount = harness.camera.initializeCount;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(harness.camera.disposeCount, disposeCount);
    expect(harness.camera.initializeCount, initializeCount);
    expect(tester.takeException(), isNull);
  });
}

final class _LifecycleHarness {
  _LifecycleHarness({
    bool flashSupported = true,
    CameraPermissionState permission = CameraPermissionState.granted,
    bool holdInitialize = false,
  }) : camera = ControllableCameraRepository(
         permission: permission,
         flashSupported: flashSupported,
         holdInitialize: holdInitialize,
       );

  final ControllableCameraRepository camera;
  final disclosure = MemoryDisclosureStore(accepted: true);
  final cloud = ControllableCloudOcrService();
  final local = ControllableLocalOcrService();
  final preparer = ControllableImagePreparer();
  final files = RecordingTransactionFiles();
  final settings = RecordingAppSettingsLauncher();

  Widget get widget => ProviderScope(
    overrides: [
      cameraRepositoryProvider.overrideWithValue(camera),
      disclosureStoreProvider.overrideWithValue(disclosure),
      cloudOcrServiceProvider.overrideWithValue(cloud),
      localOcrServiceProvider.overrideWithValue(local),
      imagePreparerProvider.overrideWithValue(preparer),
      transactionFilesProvider.overrideWithValue(files),
      appSettingsLauncherProvider.overrideWithValue(settings),
      ocrRetryDelayProvider.overrideWithValue((_) => Duration.zero),
    ],
    child: const MaterialApp(home: OcrScreen()),
  );
}
