import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InAppWebViewScreen extends StatefulWidget {
  final String? title;
  final String? url;

  const InAppWebViewScreen({
    super.key,
    this.title,
    this.url,
  });

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";
  Timer? _safetyTimer;

  late final String pageTitle;
  late final String targetUrl;

  @override
  void initState() {
    super.initState();

    final args = Get.arguments;
    if (args is Map) {
      pageTitle = (args['title'] ?? widget.title ?? "Legal Document").toString();
      targetUrl = (args['url'] ?? widget.url ?? "https://api.areisco.com").toString();
    } else {
      pageTitle = widget.title ?? "Legal Document";
      targetUrl = widget.url ?? "https://api.areisco.com";
    }

    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
                if (progress >= 75) {
                  _isLoading = false;
                }
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
            // Fallback: don't keep full-screen loader blocking if page takes longer than 6 seconds
            _safetyTimer?.cancel();
            _safetyTimer = Timer(const Duration(seconds: 6), () {
              if (mounted && _isLoading) {
                setState(() {
                  _isLoading = false;
                });
              }
            });
          },
          onPageFinished: (String url) {
            _safetyTimer?.cancel();
            if (mounted) {
              setState(() {
                _progress = 100;
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // Only trigger fatal error if main frame failed and nothing has loaded yet
            final isMainFrame = error.isForMainFrame == true;
            if (isMainFrame && _progress < 30 && mounted) {
              _safetyTimer?.cancel();
              _attemptHttpFallback();
            }
          },
        ),
      );

    _loadContent();
  }

  void _loadContent() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _progress = 10;
    });

    final uri = Uri.tryParse(targetUrl);
    if (uri != null) {
      _controller.loadRequest(uri);
    } else {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = "Invalid URL: $targetUrl";
      });
    }
  }

  /// If WebView fails on main frame, attempt to fetch raw HTML directly and render
  Future<void> _attemptHttpFallback() async {
    try {
      final response = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        await _controller.loadHtmlString(response.body, baseUrl: targetUrl);
        if (mounted) {
          setState(() {
            _hasError = false;
            _isLoading = false;
            _progress = 100;
          });
        }
        return;
      }
    } catch (_) {
      // Fall through to error display
    }

    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = "Could not connect to $pageTitle. Please check your connection.";
      });
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0B1E),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
          onPressed: () => Get.back(),
        ),
        title: Text(
          pageTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: const Color(0xFF8B9BFF), size: 22.sp),
            tooltip: "Reload",
            onPressed: () => _loadContent(),
          ),
          IconButton(
            icon: Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20.sp),
            tooltip: "Open in Browser",
            onPressed: () async {
              final uri = Uri.tryParse(targetUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isLoading ? 3.h : 1.h),
          child: _isLoading
              ? LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  backgroundColor: const Color(0xFF1E1E2C),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B9BFF)),
                  minHeight: 3.h,
                )
              : const Divider(color: Colors.white10, height: 1),
        ),
      ),
      body: SafeArea(
        child: _hasError
            ? _buildErrorView()
            : Stack(
                children: [
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    height: double.infinity,
                    child: WebViewWidget(controller: _controller),
                  ),
                  if (_isLoading)
                    Container(
                      color: const Color(0xFF0F0B1E),
                      width: double.infinity,
                      height: double.infinity,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(22.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A162B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x4D8B9BFF),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x268B9BFF),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                                ],

                              ),
                              child: SizedBox(
                                width: 44.r,
                                height: 44.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 3.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B9BFF)),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              "Loading $pageTitle",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _progress > 0
                                  ? "$_progress% loaded..."
                                  : "Please wait, fetching document...",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: const BoxDecoration(
                color: Color(0x1AFF5252),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48.sp),
            ),
            SizedBox(height: 20.h),
            Text(
              "Unable to load $pageTitle",
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.h),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : "Please check your internet connection or open in browser.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13.sp, height: 1.5),
            ),
            SizedBox(height: 28.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _loadContent(),
                  icon: const Icon(Icons.refresh, color: Colors.black, size: 18),
                  label: const Text("Retry", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  ),
                ),
                SizedBox(width: 14.w),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(targetUrl);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser, color: Colors.white70, size: 18),
                  label: const Text("Open in Browser", style: TextStyle(color: Colors.white70)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

