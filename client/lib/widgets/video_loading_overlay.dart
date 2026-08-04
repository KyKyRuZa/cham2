import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class VideoLoadingOverlay extends StatelessWidget {
  final bool visible;
  final String? message;

  const VideoLoadingOverlay({super.key, required this.visible, this.message});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final side = size.shortestSide * 1;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: side,
              height: side,
              child: Lottie.asset(
                'assets/video/loading.lottie',
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
              ),
            ),
            if (message != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: Text(
                  message!,
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
