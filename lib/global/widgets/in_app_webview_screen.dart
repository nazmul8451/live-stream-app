import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
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
  bool _hasError = false;
  String _errorMessage = "";

  late final String pageTitle;
  late final String targetUrl;

  @override
  void initState() {
    super.initState();

    final args = Get.arguments;
    if (args is Map) {
      pageTitle = (args['title'] ?? widget.title ?? "Web Page").toString();
      targetUrl = (args['url'] ?? widget.url ?? "https://api.areisco.com").toString();
    } else {
      pageTitle = widget.title ?? "Web Page";
      targetUrl = widget.url ?? "https://api.areisco.com";
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F0B1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _progress = 100;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
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
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20.sp),
            tooltip: "Open in Browser",
            onPressed: () async {
              final uri = Uri.parse(targetUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_progress < 100 ? 3.h : 1.h),
          child: _progress < 100
              ? LinearProgressIndicator(
                  value: _progress / 100,
                  backgroundColor: const Color(0xFF1E1E2C),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B9BFF)),
                  minHeight: 3.h,
                )
              : const Divider(color: Colors.white10, height: 1),
        ),
      ),
      body: SafeArea(
        child: _hasError
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 50.sp),
                      SizedBox(height: 16.h),
                      Text(
                        "Unable to load page",
                        style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        _errorMessage.isNotEmpty ? _errorMessage : "Please check your internet connection and try again.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                      ),
                      SizedBox(height: 24.h),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _progress = 0;
                          });
                          _controller.loadRequest(Uri.parse(targetUrl));
                        },
                        icon: const Icon(Icons.refresh, color: Colors.black),
                        label: const Text("Retry", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B9BFF),
                          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
