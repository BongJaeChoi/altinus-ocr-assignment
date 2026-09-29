import 'package:flutter/material.dart';

class AltinusOcrApp extends StatelessWidget {
  const AltinusOcrApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SizedBox.expand(key: ValueKey('ocr-shell'))),
  );
}
