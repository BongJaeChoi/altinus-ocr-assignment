import 'dart:async';
import 'dart:io';

import 'package:altinus_ocr/app.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_flow_controller.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_flow_state.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_providers.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:altinus_ocr/features/ocr/presentation/ocr_copy.dart';
import 'package:altinus_ocr/features/ocr/presentation/ocr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/ocr_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS simulator real camera adapter recovers from absent hardware',
    (tester) async {
      if (!Platform.isIOS ||
          !const bool.fromEnvironment('RUN_SIMULATOR_CAMERA_CHECK')) {
        markTestSkipped(
          'Explicitly opt in on an iOS simulator without cameras.',
        );
        return;
      }
      // Only disclosure persistence is replaced. Camera discovery and its native
      // plugin are real; Firebase bootstrap is outside this unavailable-camera flow.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            disclosureStoreProvider.overrideWithValue(
              MemoryDisclosureStore(accepted: true),
            ),
          ],
          child: const AltinusOcrApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OcrScreen)),
      );
      await _waitForRecovery(tester, container);
      expect(
        (container.read(
          ocrFlowControllerProvider,
        ) as RecoverableError).failure.kind,
        OcrFailureKind.cameraUnavailable,
      );
      expect(find.text(OcrCopy.genericRecovery), findsOneWidget);
      final recoveredAgain = Completer<void>();
      var retriedCameraDiscovery = false;
      final subscription = container.listen(ocrFlowControllerProvider, (
        _,
        next,
      ) {
        if (next is CameraInitializing) retriedCameraDiscovery = true;
        if (next is RecoverableError && !recoveredAgain.isCompleted) {
          recoveredAgain.complete();
        }
      });
      addTearDown(subscription.close);
      await tester.tap(find.byKey(const ValueKey('recapture')));
      await tester.runAsync(
        () => recoveredAgain.future.timeout(const Duration(seconds: 20)),
      );
      await tester.pump();
      await _waitForRecovery(tester, container);
      expect(retriedCameraDiscovery, isTrue);
      expect(
        (container.read(
          ocrFlowControllerProvider,
        ) as RecoverableError).failure.kind,
        OcrFailureKind.cameraUnavailable,
      );
      expect(find.byKey(const ValueKey('recapture')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _waitForRecovery(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // A quiet frame does not mean path-provider/file I/O or camera discovery
  // has completed. Wait for the actual state, with a wall-clock bound.
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (container.read(ocrFlowControllerProvider) is! RecoverableError &&
      DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(
    container.read(ocrFlowControllerProvider),
    isA<RecoverableError>(),
    reason:
        'Camera discovery must settle into recovery; '
        'lifecycle: ${tester.binding.lifecycleState}',
  );
}
