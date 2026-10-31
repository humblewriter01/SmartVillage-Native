import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../state/app_state.dart';

/// Full-screen leaf scanner (port of `FullScreenCameraModal.tsx`) built on the
/// Flutter `camera` plugin.
///
/// Returns the captured JPEG bytes through [Navigator.pop], or `null` if the
/// farmer backs out. If no camera can be opened — common on very cheap
/// Android devices — it pops with `null` and the caller falls back to the
/// gallery picker.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    this.title,
    this.guideText,
    this.accent = AppColors.crop,
  });

  final String? title;
  final String? guideText;
  final Color accent;

  static Future<Uint8List?> open(
    BuildContext context, {
    String? title,
    String? guideText,
    Color accent = AppColors.crop,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        builder: (_) => CameraCaptureScreen(
          title: title,
          guideText: guideText,
          accent: accent,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  bool _initialising = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = 'No camera found on this device';
          _initialising = false;
        });
        return;
      }

      // Rear camera first — that is what points at a leaf.
      final rear = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initialising = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Camera unavailable: $error';
        _initialising = false;
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $error')),
        );
        setState(() => _capturing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final title = widget.title ??
        state.pick('Leaf Scanner', 'Duba Ganye da Kamara');
    final guide = widget.guideText ??
        state.pick(
          'Hold the leaf inside the frame, in daylight, 20-30 cm away.',
          'Rike ganyen cikin firam ɗin, a cikin hasken rana, nisan 20-30 cm.',
        );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(child: _buildPreview(guide)),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _RoundButton(
                    icon: Icons.close,
                    label: state.pick('Cancel', 'Soke'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  GestureDetector(
                    onTap: _capture,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: _capturing
                            ? AppColors.faint(Colors.white, 0.4)
                            : widget.accent,
                      ),
                      child: Icon(
                        _capturing ? Icons.hourglass_top : Icons.camera_alt,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.flash_on,
                    label: state.pick('Torch', 'Tocila'),
                    onTap: () async {
                      final controller = _controller;
                      if (controller == null) return;
                      try {
                        final current = await controller.getFlashMode();
                        await controller.setFlashMode(
                          current == FlashMode.torch
                              ? FlashMode.off
                              : FlashMode.torch,
                        );
                      } catch (_) {
                        // Torch is optional.
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(String guide) {
    if (_initialising) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null || _controller == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Camera not available',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              child: const Text('Use gallery instead'),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CameraPreview(_controller!),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: widget.accent, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x99000000),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              guide,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x33FFFFFF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}
