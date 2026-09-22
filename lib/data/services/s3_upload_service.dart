import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../helpers/shared_prefe.dart';
import 'api_url.dart';

class S3UploadService {
  static String get baseUrl => ApiUrl.baseUrl;

  /// Uploads a File to S3 via Presigned URL and returns public HTTPS URL
  static Future<String?> uploadToS3({
    required File imageFile,
    required String folder,
    String? token,
  }) async {
    try {
      final authToken = (token != null && token.isNotEmpty)
          ? token
          : SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);

      if (authToken.isEmpty) {
        debugPrint("⚠️ [S3UploadService] No auth token available for upload");
        return null;
      }

      final ext = imageFile.path.split('.').last.toLowerCase();
      final contentType = (ext == 'png') ? 'image/png' : 'image/jpeg';
      final filename = 'img_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // 1. Request Presigned Upload URL
      final presignRes = await http.post(
        Uri.parse('$baseUrl/upload/presign'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'filename': filename,
          'contentType': contentType,
          'folder': folder,
        }),
      );

      if (presignRes.statusCode != 200 && presignRes.statusCode != 201) {
        debugPrint("❌ [S3UploadService] Presign request failed: ${presignRes.statusCode} - ${presignRes.body}");
        return null;
      }

      final body = jsonDecode(presignRes.body);
      final data = body['data'] ?? body;
      final uploadUrl = data['signedUrl'] ?? data['uploadUrl'] ?? data['url'];
      final fileUrl = data['publicUrl'] ?? data['fileUrl'] ?? uploadUrl?.toString().split('?').first;

      if (uploadUrl == null) {
        debugPrint("❌ [S3UploadService] uploadUrl missing from response: ${presignRes.body}");
        return null;
      }

      // 2. Upload Binary File Directly to S3
      final bytes = await imageFile.readAsBytes();
      final s3Res = await http.put(
        Uri.parse(uploadUrl.toString()),
        headers: {'Content-Type': contentType},
        body: bytes,
      );

      if (s3Res.statusCode == 200 || s3Res.statusCode == 201 || s3Res.statusCode == 204) {
        debugPrint("✅ [S3UploadService] S3 Upload successful! File URL: $fileUrl");
        return fileUrl?.toString();
      } else {
        debugPrint("❌ [S3UploadService] S3 direct PUT failed: ${s3Res.statusCode} - ${s3Res.body}");
        return null;
      }
    } catch (e) {
      debugPrint('❌ [S3UploadService] S3 Upload Error: $e');
      return null;
    }
  }
}
