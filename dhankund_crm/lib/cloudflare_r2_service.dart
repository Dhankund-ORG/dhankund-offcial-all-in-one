import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class CloudflareR2Service {
  String get baseUrl => ApiClient.baseUrl;

  Future<String?> uploadDocument(String fileName, Uint8List fileBytes) async {
    try {
      final uri = Uri.parse(baseUrl + '/api/v1/upload?filename=' + Uri.encodeQueryComponent(fileName));
      final headers = <String, String>{
        'Content-Type': 'application/octet-stream',
        if (ApiClient.token != null) 'Authorization': 'Bearer ' + ApiClient.token!,
      };
      final response = await http.post(uri, headers: headers, body: fileBytes);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map && data['url'] != null) {
          return data['url'].toString();
        }
        return null;
      }
      debugPrint('R2 upload failed: ' + response.statusCode.toString() + ' ' + response.body);
      return null;
    } catch (e) {
      debugPrint('R2 upload error: ' + e.toString());
      return null;
    }
  }

  Future<String?> getBankerDocumentUrl(String documentKey) async {
    return baseUrl + '/api/v1/download/' + documentKey;
  }
}
