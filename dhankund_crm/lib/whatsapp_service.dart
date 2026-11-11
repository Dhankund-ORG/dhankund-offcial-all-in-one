import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_service.dart';
import 'whatsapp_models.dart';

/// Thin wrapper over the WhatsApp routes the shared API worker exposes.
/// Nothing here builds JSON by hand at the call site: every method takes plain
/// values and returns typed models.
class WhatsAppService {
  static const String _base = '/api/v1/whatsapp';

  // ---------- inbox ----------

  Future<List<WaThread>> fetchThreads({String search = ''}) async {
    final query = search.trim().isEmpty ? '' : '?search=${Uri.encodeQueryComponent(search.trim())}';
    final data = await ApiClient.get('$_base/threads$query');
    return _asList(data).map(WaThread.fromJson).toList();
  }

  Future<WaConversation> fetchConversation(String phone, {bool markRead = false}) async {
    final path = '$_base/conversation?phone=${Uri.encodeQueryComponent(phone)}'
        '${markRead ? '&mark_read=1' : ''}';
    final data = await ApiClient.get(path);
    return WaConversation.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> markRead(String phone) async {
    await ApiClient.post('$_base/mark-read', {'phone': phone});
  }

  // ---------- sending ----------

  Future<Map<String, dynamic>> sendText(String phone, String text) async {
    final data = await ApiClient.post('$_base/send', {
      'to': phone,
      'type': 'text',
      'text': text,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> sendTemplate(
    String phone,
    String templateName,
    String language, {
    List<String> bodyParams = const [],
    bool force = false,
  }) async {
    final data = await ApiClient.post('$_base/send', {
      'to': phone,
      'type': 'template',
      'templateName': templateName,
      'templateLang': language,
      'bodyParams': bodyParams,
      'force': force,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> sendMedia(
    String phone, {
    required String type,
    required String mediaId,
    String? caption,
    String? filename,
  }) async {
    final data = await ApiClient.post('$_base/send', {
      'to': phone,
      'type': type,
      'mediaId': mediaId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (filename != null && filename.isNotEmpty) 'filename': filename,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// Uploads a file to R2 and to Meta, returning the media id used by /send.
  Future<Map<String, dynamic>> uploadMedia(Uint8List bytes, String filename, String mimeType) async {
    final uri = Uri.parse(ApiClient.baseUrl + '$_base/media');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      if (ApiClient.token != null) 'Authorization': 'Bearer ${ApiClient.token}',
    });
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _parseMediaType(mimeType)));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final dynamic data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data is Map && data['error'] != null ? data['error'].toString() : 'Upload failed');
    }
    return Map<String, dynamic>.from(data as Map);
  }

  // ---------- templates ----------

  Future<List<WaTemplate>> fetchTemplates({String? language, String? status}) async {
    final params = <String>[];
    if (language != null && language.isNotEmpty) params.add('language=$language');
    if (status != null && status.isNotEmpty) params.add('status=$status');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final data = await ApiClient.get('$_base/templates$query');
    return _asList(data).map(WaTemplate.fromJson).toList();
  }

  Future<Map<String, dynamic>> syncTemplates() async {
    final data = await ApiClient.post('$_base/templates/sync', {});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createTemplate({
    required String name,
    required String category,
    required String bodyHi,
    required String bodyEn,
    String? headerText,
    String? footer,
    bool bothLanguages = true,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'category': category,
      'language': bothLanguages ? 'both' : 'en',
      if (headerText != null && headerText.trim().isNotEmpty) 'header': {'text': headerText.trim()},
      if (footer != null && footer.trim().isNotEmpty) 'footer': footer.trim(),
    };
    if (bothLanguages) {
      payload['perLanguage'] = {
        'hi': {'body': bodyHi},
        'en': {'body': bodyEn},
      };
    } else {
      payload['body'] = bodyEn;
    }
    final data = await ApiClient.post('$_base/templates', payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> deleteTemplate(String id) async {
    await ApiClient.delete('$_base/templates/${Uri.encodeComponent(id)}');
  }

  Future<void> deleteTemplateByName(String name) async {
    await ApiClient.delete('$_base/templates/by-name/${Uri.encodeComponent(name)}');
  }

  // ---------- audience and broadcasts ----------

  Future<WaAudiencePreview> previewAudience({
    required List<String> sources,
    Map<String, String> filters = const {},
    bool requireOptIn = true,
  }) async {
    final data = await ApiClient.post('$_base/audience/preview', {
      'sources': sources,
      'filters': filters,
      'requireOptIn': requireOptIn,
    });
    return WaAudiencePreview.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> createBroadcast({
    required String name,
    required String templateName,
    required String templateLang,
    required List<String> sources,
    Map<String, String> filters = const {},
    bool requireOptIn = true,
    bool dryRun = false,
  }) async {
    final data = await ApiClient.post('$_base/broadcasts', {
      'name': name,
      'templateName': templateName,
      'templateLang': templateLang,
      'sources': sources,
      'filters': filters,
      'requireOptIn': requireOptIn,
      'dryRun': dryRun,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<WaBroadcast>> fetchBroadcasts() async {
    final data = await ApiClient.get('$_base/broadcasts');
    return _asList(data).map(WaBroadcast.fromJson).toList();
  }

  Future<WaBroadcast> fetchBroadcast(String id) async {
    final data = await ApiClient.get('$_base/broadcasts/${Uri.encodeComponent(id)}');
    return WaBroadcast.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> pauseBroadcast(String id) async {
    await ApiClient.post('$_base/broadcasts/${Uri.encodeComponent(id)}/pause', {});
  }

  Future<void> resumeBroadcast(String id) async {
    await ApiClient.post('$_base/broadcasts/${Uri.encodeComponent(id)}/resume', {});
  }

  Future<Map<String, dynamic>> fetchStatus() async {
    final data = await ApiClient.get('$_base/status');
    return Map<String, dynamic>.from(data as Map);
  }

  // ---------- helpers ----------

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static MediaType? _parseMediaType(String mime) {
    try {
      return MediaType.parse(mime);
    } catch (_) {
      return null;
    }
  }
}
