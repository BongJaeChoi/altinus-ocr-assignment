import 'package:altinus_ocr/app.dart';
import 'package:altinus_ocr/features/camera/camera_models.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_providers.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/ocr_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'disclosure through cloud recovery keeps local result over late cloud',
    (tester) async {
      final disclosure = MemoryDisclosureStore(accepted: false);
      final camera = ControllableCameraRepository(
        permission: CameraPermissionState.granted,
      );
      final cloud = ControllableCloudOcrService();
      final local = ControllableLocalOcrService();
      final preparer = ControllableImagePreparer();
      final files = RecordingTransactionFiles();
      final settings = RecordingAppSettingsLauncher();

      await tester.pumpWidget(
        ProviderScope(
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
          child: const AltinusOcrApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('disclosure-accept')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('disclosure-accept')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('capture')), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(camera.disposeCount, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(camera.initializeCount, 2);
      expect(find.byKey(const ValueKey('capture')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('capture')));
      await tester.pump();
      camera.completeCapture(0, '/temporary/first.jpg');
      await tester.pump();
      await tester.pump();
      cloud.complete(0, OcrResult.textDetected('첫 줄\nSECOND LINE\n세 번째 줄'));
      await tester.pump();
      expect(find.text('첫 줄\nSECOND LINE\n세 번째 줄'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recapture')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('capture')));
      await tester.pump();
      camera.completeCapture(1, '/temporary/second.jpg');
      await tester.pump();
      await tester.pump();

      cloud.fail(1, OcrFailure.transportTransient());
      await tester.pump();
      await tester.pump();
      expect(cloud.requests, hasLength(3));
      expect(find.text('2/2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.tap(find.byKey(const ValueKey('use-local')));
      await tester.pump();
      local.complete(0, OcrResult.textDetected('기기 결과\nLOCAL WINS'));
      await tester.pump();
      expect(find.text('기기 결과\nLOCAL WINS'), findsOneWidget);

      cloud.complete(2, OcrResult.textDetected('늦은 클라우드 결과'));
      await tester.pump();
      expect(find.text('기기 결과\nLOCAL WINS'), findsOneWidget);
      expect(find.text('늦은 클라우드 결과'), findsNothing);
    },
  );
}
