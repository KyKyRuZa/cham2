import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Platform.isAndroid || !Platform.isIOS)
              _WebmVideo(message: widget.message)
            else
              _NativeTransparentVideo(message: widget.message),
            if (widget.message != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: Text(
                  widget.message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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

class _NativeTransparentVideo extends StatefulWidget {
  final String? message;

  const _NativeTransparentVideo({this.message});

  @override
  State<_NativeTransparentVideo> createState() => _NativeTransparentVideoState();
}

class _NativeTransparentVideoState extends State<_NativeTransparentVideo> {
  late final Future<String> _videoPathFuture;

  @override
  void initState() {
    super.initState();
    _videoPathFuture = _copyVideoToTemp('assets/zagruuuuzka.mov');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _videoPathFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return SizedBox(
          width: 420,
          height: 420,
          child: UiKitView(
            viewType: 'transparent_video_player',
            creationParams: {'path': snapshot.data!},
            creationParamsCodec: const StandardMessageCodec(),
          ),
        );
      },
    );
  }

  Future<String> _copyVideoToTemp(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/transparent_video.mov');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());
    return tempFile.path;
  }
}
