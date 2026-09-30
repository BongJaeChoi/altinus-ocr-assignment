import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/live_cloud_gate.dart';

void main() {
  test('disabled live gate never initializes Firebase', () async {
    var calls = 0;

    await requireLiveFirebase(
      enabled: false,
      alreadyInitialized: false,
      initialize: () async {
        calls += 1;
      },
    );

    expect(calls, 0);
  });

  test('enabled live gate exposes missing configuration as failure', () async {
    await expectLater(
      requireLiveFirebase(
        enabled: true,
        alreadyInitialized: false,
        initialize: () async => throw StateError('private config detail'),
      ),
      throwsA(
        isA<LiveCloudBootstrapFailure>().having(
          (failure) => failure.causeType,
          'causeType',
          'StateError',
        ),
      ),
    );
  });

  test('enabled live gate reuses an initialized Firebase app', () async {
    var calls = 0;

    await requireLiveFirebase(
      enabled: true,
      alreadyInitialized: true,
      initialize: () async {
        calls += 1;
      },
    );

    expect(calls, 0);
  });
}
