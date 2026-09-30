import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'camera_plugin_repository.dart';
import 'camera_repository.dart';

final class CameraPreviewSurface extends StatelessWidget {
  const CameraPreviewSurface({required this.repository, super.key});

  final CameraRepository repository;

  @override
  Widget build(BuildContext context) {
    final handle = repository is CameraPluginRepository
        ? (repository as CameraPluginRepository).previewHandle
        : null;
    if (handle is CameraController && handle.value.isInitialized) {
      return CameraPreview(handle, key: const ValueKey('camera-preview'));
    }
    return const ColoredBox(
      key: ValueKey('camera-preview-placeholder'),
      color: Color(0xFF202124),
      child: SizedBox.expand(),
    );
  }
}
