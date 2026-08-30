import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AwsS3Service {
  static Future<String?> uploadFile({
    required Uint8List bytes,
    required String folderPath,
    required String extension,
  }) async {
    try {
      final baseUrl = (dotenv.env['CLOUDFLARE_API_BASE_URL'] ?? 'https://dhankund.com').trim();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$folderPath/${timestamp}_image.$extension';

      final uri = Uri.parse('$baseUrl/api/upload?filename=$fileName');
      
      final response = await http.post(
        uri,
        body: bytes,
        headers: {
          'Content-Type': 'application/octet-stream',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'];
      } else {
        debugPrint("Error uploading to R2: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Exception uploading document: $e");
      return null;
    }
  }
}
