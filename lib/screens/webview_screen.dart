import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme.dart';
import '../widgets/ff_back_button.dart';
import '../widgets/ff_button.dart';

/// Generic in-app browser used for Privacy Policy / Support links so the
/// player never has to leave the app.
class FFWebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  const FFWebViewScreen({super.key, required this.title, required this.url});

  @override
  State<FFWebViewScreen> createState() => _FFWebViewScreenState();
}

class _FFWebViewScreenState extends State<FFWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _update(loading: true, error: false),
          onPageFinished: (_) => _update(loading: false),
          onHttpError: (error) {
            final status = error.response?.statusCode ?? 0;
            if (status >= 400) _update(loading: false, error: true);
          },
          onWebResourceError: (error) {
            // Failures for sub-resources (icons, fonts) must not replace a
            // page that rendered fine.
            if (error.isForMainFrame ?? true) _update(loading: false, error: true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _update({bool? loading, bool? error}) {
    if (!mounted) return;
    setState(() {
      if (loading != null) _loading = loading;
      if (error != null) _error = error;
    });
  }

  void _retry() {
    _update(loading: true, error: false);
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FFColors.richGreen,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  FFBackButton(onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 16),
                  Expanded(child: Text(widget.title, style: FFText.title(size: 22))),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD9A971), width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (!_error) WebViewWidget(controller: _controller),
                    if (_loading && !_error)
                      const Center(child: CircularProgressIndicator(color: FFColors.richGreen)),
                    if (_error)
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black38),
                              const SizedBox(height: 12),
                              Text(
                                "Couldn't load this page. Please check your connection and try again.",
                                textAlign: TextAlign.center,
                                style: FFText.body(size: 15, color: Colors.black87),
                              ),
                              const SizedBox(height: 16),
                              FFButton(
                                label: 'Try Again',
                                style: FFButtonStyle.green,
                                width: 180,
                                height: 48,
                                fontSize: 16,
                                onPressed: _retry,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
