import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Прозрачный зацикленный экран загрузки.
///
/// На iOS используется нативный [video_player] с MOV (ProRes 4444 + альфа) —
/// системный плеер корректно отдаёт прозрачность.
///
/// На Android нативный плеер (Media3/ExoPlayer) НЕ рендерит альфа-канал из
/// WebM, поэтому здесь используется WebView с HTML5-видео, которое на Android
/// корректно проигрывает WebM с альфой (VP9 yuva420p).
class VideoLoadingOverlay extends StatefulWidget {
  final bool visible;
  final String? message;

  const VideoLoadingOverlay({
    super.key,
    required this.visible,
    this.message,
  });

  @override
  State<VideoLoadingOverlay> createState() => _VideoLoadingOverlayState();
}

class _VideoLoadingOverlayState extends State<VideoLoadingOverlay> {
  @override
  void didUpdateWidget(covariant VideoLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      // Пересоздаём внутренний виджет при показе (WebView/плеер лениво стартуют).
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Container(
      // Затемнение экрана под видео (само видео остаётся прозрачным).
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Platform.isIOS)
              _NativeVideo()
            else
              _WebmVideo(message: widget.message),
            if (Platform.isIOS && widget.message != null) ...[
              const SizedBox(height: 14),
              Text(
                widget.message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// iOS: нативный video_player с MOV (прозрачность через альфа-канал).
class _NativeVideo extends StatefulWidget {
  @override
  State<_NativeVideo> createState() => _NativeVideoState();
}

class _NativeVideoState extends State<_NativeVideo> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.asset(
      'assets/zagruuuuzka.mov',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      setState(() => _controller = controller);
      controller.play();
    } catch (e) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        width: 420,
        height: 420,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFF5C518)),
        ),
      );
    }
    return SizedBox(
      width: 420,
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Container(
          color: Colors.transparent,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

/// Android: WebView с HTML5-видео (WebM + альфа).
class _WebmVideo extends StatefulWidget {
  final String? message;

  const _WebmVideo({this.message});

  @override
  State<_WebmVideo> createState() => _WebmVideoState();
}

class _WebmVideoState extends State<_WebmVideo> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('Loading overlay WebView error: ${error.description}');
          },
        ),
      )
      ..loadFlutterAsset('assets/loading_overlay.html');

    if (widget.message != null) {
      // Передаём текст сообщения в HTML после загрузки.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _controller.runJavaScript(
          "window.postMessage({message: ${_json(widget.message)} }, '*');",
        );
      });
    }
  }

  String _json(String? value) =>
      value == null ? 'null' : "'${value.replaceAll("'", "\\'")}'";

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      height: 470,
      child: WebViewWidget(controller: _controller),
    );
  }
}
