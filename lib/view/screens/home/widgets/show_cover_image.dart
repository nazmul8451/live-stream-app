import 'package:flutter/material.dart';

import '../../../../data/services/api_url.dart';

class ShowCoverImage extends StatelessWidget {
  const ShowCoverImage({super.key, required this.image});

  final String image;

  static const _placeholder = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF222943), Color(0xFF11121D)],
      ),
    ),
    child: Center(
      child: Icon(Icons.videocam_outlined, size: 48, color: Color(0xFF9199C1)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final source = image.trim();
    final uri = Uri.tryParse(source);
    final legacyCover =
        (uri?.host == 'images.unsplash.com' &&
            uri?.path == '/photo-1613771404784-3a5686aa2be3') ||
        (uri?.host == 's3.amazonaws.com' &&
            uri?.path == '/culturecards/cover1.jpg');

    if (source.isEmpty || legacyCover) return _placeholder;

    if (source.startsWith('data:image/')) {
      try {
        return Image.memory(
          UriData.parse(source).contentAsBytes(),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder,
        );
      } on FormatException {
        return _placeholder;
      }
    }

    final url = uri?.hasScheme == true
        ? source
        : "${ApiUrl.imageBaseUrl}${source.startsWith('/') ? source : '/$source'}";
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder,
    );
  }
}
