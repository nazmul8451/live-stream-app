import 'package:flutter/material.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/in_app_webview_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InAppWebViewScreen(
      title: "Terms & Conditions",
      url: ApiUrl.termsAndConditionsUrl,
    );
  }
}

