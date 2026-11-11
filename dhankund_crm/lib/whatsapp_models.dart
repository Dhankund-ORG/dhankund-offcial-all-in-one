/// Models for the WhatsApp Cloud API module in the CRM.
/// Every field maps straight to a JSON key the API worker returns.
library;

class WaWindow {
  final bool open;
  final String? expiresAt;
  final int remainingSeconds;
  final String reason;
  final String text;

  const WaWindow({
    required this.open,
    this.expiresAt,
    this.remainingSeconds = 0,
    this.reason = '',
    this.text = '',
  });

  factory WaWindow.fromJson(Map<String, dynamic>? json, {String text = ''}) {
    if (json == null) {
      return WaWindow(open: false, reason: 'unknown', text: text);
    }
    return WaWindow(
      open: json['open'] == true,
      expiresAt: json['expiresAt']?.toString(),
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString() ?? '',
      text: text.isNotEmpty ? text : (json['reason']?.toString() ?? ''),
    );
  }

  String get remainingLabel {
    if (!open) return 'Closed';
    final h = remainingSeconds ~/ 3600;
    final m = (remainingSeconds % 3600) ~/ 60;
    if (h <= 0) return '${m}m left';
    return '${h}h ${m}m left';
  }
}

class WaThread {
  final String phone;
  final String? name;
  final String? profileName;
  final String? optInStatus;
  final String? lastBody;
  final String? lastType;
  final String? lastDirection;
  final String? lastAt;
  final int unread;
  final WaWindow window;

  WaThread({
    required this.phone,
    this.name,
    this.profileName,
    this.optInStatus,
    this.lastBody,
    this.lastType,
    this.lastDirection,
    this.lastAt,
    this.unread = 0,
    required this.window,
  });

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    if (profileName != null && profileName!.trim().isNotEmpty) return profileName!;
    return phone;
  }

  factory WaThread.fromJson(Map<String, dynamic> json) {
    return WaThread(
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString(),
      profileName: json['profile_name']?.toString(),
      optInStatus: json['opt_in_status']?.toString(),
      lastBody: json['last_body']?.toString(),
      lastType: json['last_type']?.toString(),
      lastDirection: json['last_direction']?.toString(),
      lastAt: json['last_at']?.toString(),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      window: WaWindow.fromJson(
        json['window'] is Map ? Map<String, dynamic>.from(json['window'] as Map) : null,
        text: json['window_text']?.toString() ?? '',
      ),
    );
  }
}

class WaMessage {
  final String id;
  final String? waMessageId;
  final String direction;
  final String type;
  final String? kind;
  final String? body;
  final String? caption;
  final String? mediaKey;
  final String? mediaMime;
  final String? mediaFilename;
  final String? templateName;
  final String? status;
  final String? errorMessage;
  final String? createdAt;
  final String? reactionEmoji;
  final String? interactiveTitle;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  WaMessage({
    required this.id,
    this.waMessageId,
    required this.direction,
    required this.type,
    this.kind,
    this.body,
    this.caption,
    this.mediaKey,
    this.mediaMime,
    this.mediaFilename,
    this.templateName,
    this.status,
    this.errorMessage,
    this.createdAt,
    this.reactionEmoji,
    this.interactiveTitle,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  bool get isInbound => direction == 'inbound';

  String get display {
    final text = body ?? caption;
    if (text != null && text.trim().isNotEmpty) return text;
    if (type == 'document') return mediaFilename ?? '[document]';
    if (type == 'location') return locationName ?? '[location]';
    return '[${type}]';
  }

  factory WaMessage.fromJson(Map<String, dynamic> json) {
    return WaMessage(
      id: json['id']?.toString() ?? '',
      waMessageId: json['wa_message_id']?.toString(),
      direction: json['direction']?.toString() ?? 'inbound',
      type: json['type']?.toString() ?? 'text',
      kind: json['kind']?.toString(),
      body: json['body']?.toString(),
      caption: json['caption']?.toString(),
      mediaKey: json['media_r2_key']?.toString(),
      mediaMime: json['media_mime']?.toString(),
      mediaFilename: json['media_filename']?.toString(),
      templateName: json['template_name']?.toString(),
      status: json['status']?.toString(),
      errorMessage: json['error_message']?.toString(),
      createdAt: json['created_at']?.toString(),
      reactionEmoji: json['reaction_emoji']?.toString(),
      interactiveTitle: json['interactive_title']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['location_name']?.toString(),
    );
  }
}

class WaConversation {
  final String phone;
  final WaThread? contact;
  final WaWindow window;
  final int unread;
  final List<WaMessage> messages;

  WaConversation({
    required this.phone,
    this.contact,
    required this.window,
    this.unread = 0,
    required this.messages,
  });

  factory WaConversation.fromJson(Map<String, dynamic> json) {
    final raw = json['contact'];
    final messages = (json['messages'] as List? ?? [])
        .whereType<Map>()
        .map((e) => WaMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return WaConversation(
      phone: json['phone']?.toString() ?? '',
      contact: raw is Map
          ? WaThread(
              phone: json['phone']?.toString() ?? '',
              name: raw['name']?.toString(),
              profileName: raw['profile_name']?.toString(),
              optInStatus: raw['opt_in_status']?.toString(),
              window: WaWindow.fromJson(
                json['window'] is Map ? Map<String, dynamic>.from(json['window'] as Map) : null,
                text: json['window_text']?.toString() ?? '',
              ),
            )
          : null,
      window: WaWindow.fromJson(
        json['window'] is Map ? Map<String, dynamic>.from(json['window'] as Map) : null,
        text: json['window_text']?.toString() ?? '',
      ),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      messages: messages,
    );
  }
}

class WaTemplate {
  final String id;
  final String? remoteId;
  final String name;
  final String language;
  final String? category;
  final String? status;
  final String? quality;
  final String? bodyText;
  final int variables;

  WaTemplate({
    required this.id,
    this.remoteId,
    required this.name,
    required this.language,
    this.category,
    this.status,
    this.quality,
    this.bodyText,
    this.variables = 0,
  });

  bool get approved => (status ?? '').toUpperCase() == 'APPROVED';
  String get languageLabel => language == 'hi' ? 'हिंदी' : language.toUpperCase();

  factory WaTemplate.fromJson(Map<String, dynamic> json) {
    final components = json['components'];
    String? bodyText;
    var variables = 0;
    if (components is List) {
      for (final c in components) {
        if (c is Map && (c['type']?.toString().toUpperCase() == 'BODY')) {
          bodyText = c['text']?.toString();
        }
      }
    }
    if (bodyText != null) {
      final matches = RegExp(r'\{\{\s*\d+\s*\}\}').allMatches(bodyText).length;
      variables = matches;
    }
    return WaTemplate(
      id: json['id']?.toString() ?? '',
      remoteId: json['remote_id']?.toString(),
      name: json['name']?.toString() ?? '',
      language: json['language']?.toString() ?? 'en',
      category: json['category']?.toString(),
      status: json['status']?.toString(),
      quality: json['quality']?.toString(),
      bodyText: bodyText,
      variables: variables,
    );
  }
}

class WaAudiencePreview {
  final int total;
  final Map<String, int> skipped;
  final Map<String, int> perSource;
  final List<Map<String, dynamic>> sample;

  WaAudiencePreview({
    required this.total,
    required this.skipped,
    required this.perSource,
    required this.sample,
  });

  factory WaAudiencePreview.fromJson(Map<String, dynamic> json) {
    final skippedRaw = json['skipped'];
    final perSourceRaw = json['perSource'];
    return WaAudiencePreview(
      total: (json['total'] as num?)?.toInt() ?? 0,
      skipped: skippedRaw is Map
          ? skippedRaw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : {},
      perSource: perSourceRaw is Map
          ? perSourceRaw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : {},
      sample: (json['sample'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }
}

class WaBroadcast {
  final String id;
  final String? name;
  final String? templateName;
  final String? templateLang;
  final int total;
  final int sent;
  final int delivered;
  final int read;
  final int failed;
  final int skipped;
  final String status;
  final String? createdAt;

  WaBroadcast({
    required this.id,
    this.name,
    this.templateName,
    this.templateLang,
    this.total = 0,
    this.sent = 0,
    this.delivered = 0,
    this.read = 0,
    this.failed = 0,
    this.skipped = 0,
    required this.status,
    this.createdAt,
  });

  double get progress {
    if (total <= 0) return 0;
    final done = sent + failed;
    return (done / total).clamp(0.0, 1.0);
  }

  factory WaBroadcast.fromJson(Map<String, dynamic> json) {
    return WaBroadcast(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      templateName: json['template_name']?.toString(),
      templateLang: json['template_lang']?.toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as num?)?.toInt() ?? 0,
      read: (json['read'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'queued',
      createdAt: json['created_at']?.toString(),
    );
  }
}
