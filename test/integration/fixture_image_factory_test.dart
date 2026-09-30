import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../integration_test/support/fixture_image_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generates deterministic valid PNG variants without binary assets',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'altinus_fixture_test.',
      );
      addTearDown(() => directory.delete(recursive: true));
      final factory = FixtureImageFactory(
        directoryProvider: () async => directory,
      );
      final encodings = <FixtureImageVariant, List<int>>{};

      for (final variant in FixtureImageVariant.values) {
        final first = await factory.create(variant);
        final firstBytes = await first.readAsBytes();
        final second = await factory.create(variant);
        final secondBytes = await second.readAsBytes();
        expect(secondBytes, firstBytes, reason: variant.name);
        final decoded = image.decodePng(firstBytes);
        expect(decoded, isNotNull, reason: variant.name);
        expect(decoded!.width, 1200);
        expect(decoded.height, 800);
        encodings[variant] = firstBytes;
      }

      expect(encodings.values.map(Object.hashAll).toSet(), hasLength(7));
    },
  );
}
