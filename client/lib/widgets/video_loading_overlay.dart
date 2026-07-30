import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Прозрачный зацикленный экран загрузки.
///
/// Использует WebView с HTML5-видео (WebM + VP9 альфа) на всех платформах.
/// WKWebView на iOS и WebView на Android корректно проигрывают WebM
/// с альфа-каналом (yuva420p), что обеспечивает прозрачность видео.
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
            _WebmVideo(message: widget.message),
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