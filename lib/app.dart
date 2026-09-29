import 'package:flutter/material.dart';

class AltinusOcrApp extends StatelessWidget {
  const AltinusOcrApp({super.key, this.home});

  /// Task 11 supplies the production providers and OCR screen through this seam.
  /// Keeping the shell bootable now avoids fabricating production dependencies.
  final Widget? home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home:
        home ??
        const Scaffold(body: SizedBox.expand(key: ValueKey('ocr-shell'))),
  );
}
