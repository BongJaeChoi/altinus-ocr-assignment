import 'package:altinus_ocr/app.dart';
import 'package:altinus_ocr/bootstrap/firebase_cloud_bootstrap.dart';
import 'package:altinus_ocr/features/disclosure/shared_preferences_disclosure_store.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final disclosureStore = await SharedPreferencesDisclosureStore.create();
  final firebaseGateway = await createFirebaseModelGateway();
  runApp(
    ProviderScope(
      overrides: [
        disclosureStoreProvider.overrideWithValue(disclosureStore),
        firebaseModelGatewayProvider.overrideWithValue(firebaseGateway),
      ],
      child: const AltinusOcrApp(),
    ),
  );
}
