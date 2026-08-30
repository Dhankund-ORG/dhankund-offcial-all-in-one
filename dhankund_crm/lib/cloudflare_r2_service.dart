import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudflareR2Service {
  // Use the official site domain or fallback to localhost for dev
  late String baseUrl;

  CloudflareR2Service() {
    // We can define CLOUDFLARE_API_BASE_URL in .env (e.g. https://dhankund.com)
    baseUrl = (dotenv.env['CLOUDFLARE_API_BASE_URL'] ?? 'https://dhankund.com').trim();
  }

  /// Upload a document to Cloudflare R2 via Pages Function
  Future<String?> uploadDocument(String fileName, Uint8List fileBytes) async {
    try {
      final uri = Uri.parse('$baseUrl/api/upload?filename=$fileName');
      
      final response = await http.post(
        uri,
        body: fileBytes,
        headers: {
          'Content-Type': 'application/octet-stream',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url']; // Returns the download API URL or public URL
      } else {
        debugPrint("Error uploading to R2: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Exception uploading document: $e");
      return null;
    }
  }

  /// Get a download URL for a document (This is now just the API endpoint)
  Future<String?> getBankerDocumentUrl(String documentKey) async {
    return '$baseUrl/api/download/$documentKey';
  }
}
