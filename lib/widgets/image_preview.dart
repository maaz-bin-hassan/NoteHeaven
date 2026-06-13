import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ImagePreview extends StatefulWidget {
  final String imagePath;

  const ImagePreview({super.key, required this.imagePath});

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview>
    with SingleTickerProviderStateMixin {
  late final TransformationController _controller;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) _controller.value = _animation!.value;
      });
  }

  void _handleDoubleTap() {
    if (_controller.value != Matrix4.identity()) {
      _animateTo(Matrix4.identity());
    } else {
      final position = _doubleTapDetails!.localPosition;
      const scale = 2.5;
      _animateTo(Matrix4.identity()
        ..translateByDouble(
            -position.dx * (scale - 1), -position.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, scale, 1));
    }
  }

  void _animateTo(Matrix4 target) {
    _animation = Matrix4Tween(begin: _controller.value, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward(from: 0);
  }

  Future<void> _share() async {
    HapticFeedback.lightImpact();
    if (!File(widget.imagePath).existsSync()) return;
    try {
      await SharePlus.instance
          .share(ShareParams(files: [XFile(widget.imagePath)]));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _share,
            tooltip: 'Share image',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: (d) => _doubleTapDetails = d,
        onDoubleTap: _handleDoubleTap,
        child: Center(
          child: Hero(
            tag: 'image-${widget.imagePath}',
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      size: 64, color: Colors.white54),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
