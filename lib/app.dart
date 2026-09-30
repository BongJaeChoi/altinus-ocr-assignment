import 'package:flutter/material.dart';

import 'features/ocr/presentation/ocr_screen.dart';

class AltinusOcrApp extends StatelessWidget {
  const AltinusOcrApp({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(debugShowCheckedModeBanner: false, home: const OcrScreen());
}
