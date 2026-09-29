typedef LiveFirebaseInitializer = Future<void> Function();

final class LiveCloudBootstrapFailure implements Exception {
  const LiveCloudBootstrapFailure(this.causeType);

  final String causeType;
}

Future<void> requireLiveFirebase({
  required bool enabled,
  required bool alreadyInitialized,
  required LiveFirebaseInitializer initialize,
}) async {
  if (!enabled || alreadyInitialized) {
    return;
  }
  try {
    await initialize();
  } catch (error) {
    throw LiveCloudBootstrapFailure(error.runtimeType.toString());
  }
}
