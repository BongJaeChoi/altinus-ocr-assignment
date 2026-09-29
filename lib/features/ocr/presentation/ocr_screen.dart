import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/camera_models.dart';
import '../../camera/camera_preview_surface.dart';
import '../application/ocr_flow_controller.dart';
import '../application/ocr_flow_state.dart';
import '../application/ocr_providers.dart';
import '../domain/ocr_engine.dart';
import 'ocr_copy.dart';

final class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

final class _OcrScreenState extends ConsumerState<OcrScreen>
    with WidgetsBindingObserver {
  bool _inactiveForwarded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start on the next frame so a widget removed during this first frame
      // cannot read its provider after disposal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final lifecycleState = WidgetsBinding.instance.lifecycleState;
        if (lifecycleState != null &&
            lifecycleState != AppLifecycleState.resumed) {
          _forwardInactiveOnce();
          return;
        }
        ref.read(ocrFlowControllerProvider.notifier).start();
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (!_inactiveForwarded) {
        return;
      }
      _inactiveForwarded = false;
      unawaited(ref.read(ocrFlowControllerProvider.notifier).onResumed());
    } else {
      _forwardInactiveOnce();
    }
  }

  void _forwardInactiveOnce() {
    if (!mounted || _inactiveForwarded) {
      return;
    }
    _inactiveForwarded = true;
    unawaited(ref.read(ocrFlowControllerProvider.notifier).onInactive());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(ocrFlowControllerProvider.notifier);
    final state = ref.watch(ocrFlowControllerProvider);
    final content = switch (state) {
      Booting() => const _MessageContent(message: OcrCopy.booting),
      DisclosureRequired() => _DisclosureContent(
        onAccept: () {
          controller.acceptDisclosure();
        },
      ),
      CameraInitializing() => _MessageContent(
        message: OcrCopy.initializingCamera,
        progress: true,
        onRecapture: () {
          controller.recapture();
        },
      ),
      PermissionDenied() => _PermissionContent(
        onOpenSettings: () {
          controller.openSettings();
        },
        onRetry: () {
          controller.recapture();
        },
      ),
      PreviewReady(:final flashSupported, :final flashMode) => _PreviewContent(
        preview: CameraPreviewSurface(
          repository: ref.watch(cameraRepositoryProvider),
        ),
        flashSupported: flashSupported,
        flashMode: flashMode,
        onFlashChanged: (mode) {
          controller.setFlash(mode);
        },
        onCapture: () {
          controller.capture();
        },
      ),
      Capturing() => _MessageContent(
        message: OcrCopy.capturing,
        progress: true,
        onRecapture: () {
          controller.recapture();
        },
      ),
      RecognizingCloud(:final attempt, :final takingLonger) =>
        _CloudProgressContent(
          attempt: attempt,
          takingLonger: takingLonger,
          onUseLocal: () {
            controller.useLocalOcr();
          },
          onKeepWaiting: () {
            controller.keepWaiting();
          },
        ),
      CloudRecovery() => _RecoveryContent(
        message: OcrCopy.cloudRecovery,
        onRecapture: () {
          controller.recapture();
        },
        onUseLocal: () {
          controller.useLocalOcr();
        },
      ),
      RecognizingLocal() => _MessageContent(
        message: OcrCopy.recognizing,
        progress: true,
        onRecapture: () {
          controller.recapture();
        },
      ),
      OcrSuccess(:final text, engine: OcrEngine.cloud) => _ResultContent(
        text: text,
        onRecapture: () {
          controller.recapture();
        },
        onUseLocal: () {
          controller.useLocalOcr();
        },
      ),
      OcrSuccess(:final text, engine: OcrEngine.local) => _ResultContent(
        text: text,
        onRecapture: () {
          controller.recapture();
        },
      ),
      OcrEmpty(engine: OcrEngine.cloud) => _EmptyContent(
        onRecapture: () {
          controller.recapture();
        },
        onUseLocal: () {
          controller.useLocalOcr();
        },
      ),
      OcrEmpty(engine: OcrEngine.local) => _EmptyContent(
        onRecapture: () {
          controller.recapture();
        },
      ),
      RecoverableError() => _RecoveryContent(
        message: OcrCopy.genericRecovery,
        actionLabel: OcrCopy.tryAgain,
        onRecapture: () {
          controller.recapture();
        },
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text(OcrCopy.appTitle)),
      body: SafeArea(
        child: _ScrollablePage(
          child: Semantics(
            key: const ValueKey('status-live-region'),
            container: true,
            liveRegion: true,
            child: content,
          ),
        ),
      ),
    );
  }
}

final class _ScrollablePage extends StatelessWidget {
  const _ScrollablePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

final class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    this.progress = false,
    this.onRecapture,
  });

  final String message;
  final bool progress;
  final VoidCallback? onRecapture;

  @override
  Widget build(BuildContext context) => _ContentColumn(
    children: [
      if (progress) ...[
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
      ],
      Text(message, textAlign: TextAlign.center),
      if (onRecapture case final action?) ...[
        const SizedBox(height: 24),
        _SecondaryAction(
          key: const ValueKey('recapture'),
          label: OcrCopy.recapture,
          onPressed: action,
        ),
      ],
    ],
  );
}

final class _DisclosureContent extends StatelessWidget {
  const _DisclosureContent({required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) => _ContentColumn(
    children: [
      const _Heading(OcrCopy.disclosureTitle),
      const SizedBox(height: 16),
      const Text(OcrCopy.disclosureBody, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _PrimaryAction(
        key: const ValueKey('disclosure-accept'),
        label: OcrCopy.disclosureAccept,
        onPressed: onAccept,
      ),
    ],
  );
}

final class _PermissionContent extends StatelessWidget {
  const _PermissionContent({
    required this.onOpenSettings,
    required this.onRetry,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _ContentColumn(
    children: [
      const _Heading(OcrCopy.permissionTitle),
      const SizedBox(height: 12),
      const Text(OcrCopy.permissionBody, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _PrimaryAction(
        key: const ValueKey('open-settings'),
        label: OcrCopy.openSettings,
        onPressed: onOpenSettings,
      ),
      const SizedBox(height: 12),
      _SecondaryAction(
        key: const ValueKey('recapture'),
        label: OcrCopy.retry,
        onPressed: onRetry,
      ),
    ],
  );
}

final class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.preview,
    required this.flashSupported,
    required this.flashMode,
    required this.onFlashChanged,
    required this.onCapture,
  });

  final Widget preview;
  final bool flashSupported;
  final CameraFlashMode flashMode;
  final ValueChanged<CameraFlashMode> onFlashChanged;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => _ContentColumn(
    children: [
      const _Heading(OcrCopy.previewTitle),
      const SizedBox(height: 12),
      const Text(OcrCopy.previewBody, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      SizedBox(height: 280, width: double.infinity, child: preview),
      if (flashSupported) ...[
        const SizedBox(height: 16),
        const Text(OcrCopy.flash),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ChoiceChip(
              key: const ValueKey('flash-auto'),
              label: const Text(OcrCopy.flashAuto),
              selected: flashMode == CameraFlashMode.auto,
              onSelected: (_) => onFlashChanged(CameraFlashMode.auto),
            ),
            ChoiceChip(
              key: const ValueKey('flash-off'),
              label: const Text(OcrCopy.flashOff),
              selected: flashMode == CameraFlashMode.off,
              onSelected: (_) => onFlashChanged(CameraFlashMode.off),
            ),
          ],
        ),
      ],
      const SizedBox(height: 24),
      _PrimaryAction(
        key: const ValueKey('capture'),
        label: OcrCopy.capture,
        onPressed: onCapture,
      ),
    ],
  );
}

final class _CloudProgressContent extends StatelessWidget {
  const _CloudProgressContent({
    required this.attempt,
    required this.takingLonger,
    required this.onUseLocal,
    required this.onKeepWaiting,
  });

  final int attempt;
  final bool takingLonger;
  final VoidCallback onUseLocal;
  final VoidCallback onKeepWaiting;

  @override
  Widget build(BuildContext context) => _ContentColumn(
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 24),
      const Text(OcrCopy.recognizing, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('$attempt/2', textAlign: TextAlign.center),
      if (takingLonger) ...[
        const SizedBox(height: 24),
        const Text(OcrCopy.takingLonger, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        _PrimaryAction(
          key: const ValueKey('use-local'),
          label: OcrCopy.useLocal,
          onPressed: onUseLocal,
        ),
        const SizedBox(height: 12),
        _SecondaryAction(
          key: const ValueKey('keep-waiting'),
          label: OcrCopy.keepWaiting,
          onPressed: onKeepWaiting,
        ),
      ],
    ],
  );
}

final class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.text,
    required this.onRecapture,
    this.onUseLocal,
  });

  final String text;
  final VoidCallback onRecapture;
  final VoidCallback? onUseLocal;

  @override
  Widget build(BuildContext context) => _ContentColumn(
    children: [
      const _Heading(OcrCopy.successTitle),
      const SizedBox(height: 16),
      Text(text),
      if (onUseLocal case final action?) ...[
        const SizedBox(height: 16),
        const Text(OcrCopy.cloudAlternative, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _SecondaryAction(
          key: const ValueKey('use-local'),
          label: OcrCopy.useLocal,
          onPressed: action,
        ),
      ],
      const SizedBox(height: 24),
      _PrimaryAction(
        key: const ValueKey('recapture'),
        label: OcrCopy.recapture,
        onPressed: onRecapture,
      ),
    ],
  );
}

final class _EmptyContent extends StatelessWidget {
  const _EmptyContent({required this.onRecapture, this.onUseLocal});

  final VoidCallback onRecapture;
  final VoidCallback? onUseLocal;

  @override
  Widget build(BuildContext context) => _ContentColumn(
    children: [
      const _Heading(OcrCopy.emptyTitle, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      const Text(OcrCopy.emptyBody, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _PrimaryAction(
        key: const ValueKey('recapture'),
        label: OcrCopy.recapture,
        onPressed: onRecapture,
      ),
      if (onUseLocal case final action?) ...[
        const SizedBox(height: 12),
        _SecondaryAction(
          key: const ValueKey('use-local'),
          label: OcrCopy.useLocal,
          onPressed: action,
        ),
      ],
    ],
  );
}

final class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent({
    required this.message,
    required this.onRecapture,
    this.onUseLocal,
    this.actionLabel = OcrCopy.recapture,
  });

  final String message;
  final VoidCallback onRecapture;
  final VoidCallback? onUseLocal;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => _ContentColumn(
    children: [
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _PrimaryAction(
        key: const ValueKey('recapture'),
        label: actionLabel,
        onPressed: onRecapture,
      ),
      if (onUseLocal case final action?) ...[
        const SizedBox(height: 12),
        _SecondaryAction(
          key: const ValueKey('use-local'),
          label: OcrCopy.useLocal,
          onPressed: action,
        ),
      ],
    ],
  );
}

final class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(fontSize: 24),
      textAlign: textAlign,
    ),
  );
}

final class _ContentColumn extends StatelessWidget {
  const _ContentColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

final class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

final class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}
