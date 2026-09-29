import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum FixtureImageVariant {
  koreanLatin,
  noText,
  darkLowContrast,
  rotated,
  multiline,
}

final class FixtureImageFactory {
  FixtureImageFactory({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getTemporaryDirectory;

  static const primaryText = '안녕하세요 ALTINUS 123';
  static const multilineText = '안녕하세요\nALTINUS 123\nOCR MULTILINE';
  static const _width = 1200.0;
  static const _height = 800.0;

  final Future<Directory> Function() _directoryProvider;

  Future<File> create(FixtureImageVariant variant) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final dark = variant == FixtureImageVariant.darkLowContrast;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _width, _height),
      Paint()..color = dark ? const Color(0xFF202020) : Colors.white,
    );

    if (variant != FixtureImageVariant.noText) {
      final painter = TextPainter(
        text: TextSpan(
          text: variant == FixtureImageVariant.multiline
              ? multilineText
              : primaryText,
          style: TextStyle(
            color: dark ? const Color(0xFF292929) : Colors.black,
            fontSize: 72,
            height: 1.35,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: 1000);

      if (variant == FixtureImageVariant.rotated) {
        canvas
          ..save()
          ..translate(_width / 2, _height / 2)
          ..rotate(math.pi / 2)
          ..translate(-painter.width / 2, -painter.height / 2);
        painter.paint(canvas, Offset.zero);
        canvas.restore();
      } else {
        painter.paint(canvas, const Offset(100, 240));
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), _height.toInt());
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Unable to encode deterministic fixture PNG.');
      }
      final directory = await _directoryProvider();
      await directory.create(recursive: true);
      final file = File(
        path.join(directory.path, 'altinus_fixture_${variant.name}.png'),
      );
      await file.writeAsBytes(
        Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return file;
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
