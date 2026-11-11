import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../whatsapp_models.dart';
import '../../whatsapp_service.dart';

/// Two-pane WhatsApp inbox: conversations on the left, the selected chat on the
/// right, with a banner that says whether the 24-hour service window is still
/// open. Outside the window free text is blocked and a template is offered.
class WhatsappInboxPage extends StatefulWidget {
  const WhatsappInboxPage({super.key});

  @override
  State<WhatsappInboxPage> createState() => _WhatsappInboxPageState();
}

class _WhatsappInboxPageState extends State<WhatsappInboxPage> {
  final WhatsAppService _service = WhatsAppService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<WaThread> _threads = [];
  WaThread? _selected;
  WaConversation? _conversation;
  bool _loadingThreads = true;
  bool _loadingConversation = false;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadThreads();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      _loadThreads(silent: true);
      if (_selected != null) _loadConversation(_selected!.phone, silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _searchController.dispose();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadThreads({bool silent = false}) async {
    if (!silent) setState(() => _loadingThreads = true);
    try {
      final threads = await _service.fetchThreads(search: _searchController.text);
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loadingThreads = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingThreads = false;
        if (!silent) _error = e.toString();
      });
    }
  }

  Future<void> _loadConversation(String phone, {bool silent = false, bool markRead = false}) async {
    if (!silent) setState(() => _loadingConversation = true);
    try {
      final conversation = await _service.fetchConversation(phone, markRead: markRead);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _loadingConversation = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConversation = false;
        if (!silent) _error = e.toString();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _openThread(WaThread thread) async {
    setState(() {
      _selected = thread;
      _conversation = null;
    });
    await _loadConversation(thread.phone, markRead: true);
    await _loadThreads(silent: true);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppTheme.rubyRed : AppTheme.emeraldGreen,
    ));
  }

  Future<void> _sendText() async {
    final thread = _selected;
    final text = _composerController.text.trim();
    if (thread == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendText(thread.phone, text);
      _composerController.clear();
      await _loadConversation(thread.phone);
      await _loadThreads(silent: true);
    } catch (e) {
      _toast(e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendTemplate() async {
    final thread = _selected;
    if (thread == null) return;
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TemplatePickerDialog(service: _service, variablesHint: true),
    );
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      await _service.sendTemplate(
        thread.phone,
        picked['name'] as String,
        picked['language'] as String,
        bodyParams: (picked['params'] as List).cast<String>(),
        force: true,
      );
      await _loadConversation(thread.phone);
      await _loadThreads(silent: true);
      _toast('Template sent');
    } catch (e) {
      _toast(e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attachFile() async {
    final thread = _selected;
    if (thread == null) return;
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;

    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      final name = file.name;
      final mime = _mimeFor(name);
      final uploaded = await _service.uploadMedia(bytes, name, mime);
      final mediaId = uploaded['media_id']?.toString();
      if (mediaId == null || mediaId.isEmpty) {
        throw Exception('WhatsApp did not return a media id');
      }
      await _service.sendMedia(
        thread.phone,
        type: mime.startsWith('image/') ? 'image' : 'document',
        mediaId: mediaId,
        filename: name,
      );
      await _loadConversation(thread.phone);
      await _loadThreads(silent: true);
      _toast('File sent');
    } catch (e) {
      _toast(e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    if (!wide && _selected != null) {
      return _buildConversationPane(isStandalone: true);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: wide ? 340 : MediaQuery.of(context).size.width, child: _buildThreadsPane()),
        if (wide)
          Expanded(
            child: _selected == null
                ? _buildEmptyState()
                : _buildConversationPane(isStandalone: false),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Choose a conversation', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Messages from WhatsApp appear here in real time.',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildThreadsPane() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.obsidianMedium,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.forum_outlined, size: 18, color: AppTheme.royalGold),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('WhatsApp Inbox',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _loadThreads(),
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadThreads(),
              decoration: InputDecoration(
                hintText: 'Search name or number',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: AppTheme.obsidianLight,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null && _threads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: AppTheme.rubyRed, fontSize: 12)),
            ),
          Expanded(
            child: _loadingThreads
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _threads.isEmpty
                    ? Center(
                        child: Text('No conversations yet',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      )
                    : ListView.separated(
                        itemCount: _threads.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEF2F7)),
                        itemBuilder: (_, index) => _threadTile(_threads[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _threadTile(WaThread thread) {
    final selected = _selected?.phone == thread.phone;
    return InkWell(
      onTap: () => _openThread(thread),
      child: Container(
        color: selected ? AppTheme.royalGold.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.royalGold.withValues(alpha: 0.12),
              child: Text(
                thread.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                        ),
                      ),
                      if (thread.unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${thread.unread}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    thread.lastBody ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        thread.window.open ? Icons.lock_open : Icons.lock_outline,
                        size: 11,
                        color: thread.window.open ? AppTheme.emeraldGreen : AppTheme.rubyRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        thread.window.remainingLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: thread.window.open ? AppTheme.emeraldGreen : AppTheme.rubyRed,
                        ),
                      ),
                      const Spacer(),
                      Text(_shortTime(thread.lastAt), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationPane({required bool isStandalone}) {
    final thread = _selected!;
    final conversation = _conversation;
    final window = conversation?.window ?? thread.window;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.obsidianMedium,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              if (isStandalone)
                IconButton(
                  onPressed: () => setState(() {
                    _selected = null;
                    _conversation = null;
                  }),
                  icon: const Icon(Icons.arrow_back, size: 18),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(thread.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    Text(thread.phone, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _optInBadge(thread.optInStatus),
            ],
          ),
        ),
        _windowBanner(window),
        Expanded(
          child: Container(
            color: const Color(0xFFF7F9FC),
            child: _loadingConversation && conversation == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : conversation == null || conversation.messages.isEmpty
                    ? Center(
                        child: Text('No messages yet',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: conversation.messages.length,
                        itemBuilder: (_, index) => _bubble(conversation.messages[index]),
                      ),
          ),
        ),
        _composer(window),
      ],
    );
  }

  Widget _optInBadge(String? status) {
    final opted = status == 'opted_in';
    final out = status == 'opted_out';
    final color = opted ? AppTheme.emeraldGreen : (out ? AppTheme.rubyRed : AppTheme.textSecondary);
    final label = opted ? 'Opted in' : (out ? 'Opted out' : 'Consent unknown');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _windowBanner(WaWindow window) {
    final open = window.open;
    final color = open ? AppTheme.emeraldGreen : AppTheme.rubyRed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(open ? Icons.timer_outlined : Icons.timer_off_outlined, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              window.text.isNotEmpty
                  ? window.text
                  : (open ? 'Service window open' : 'Service window closed — only templates can be sent'),
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Text(window.remainingLabel, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _bubble(WaMessage message) {
    final inbound = message.isInbound;
    final bg = inbound ? Colors.white : AppTheme.royalGold.withValues(alpha: 0.09);
    return Align(
      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(inbound ? 2 : 12),
            bottomRight: Radius.circular(inbound ? 12 : 2),
          ),
          border: Border.all(color: const Color(0xFFE6ECF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type != 'text')
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon(message.type), size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(message.type.toUpperCase(),
                        style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                  ],
                ),
              ),
            Text(message.display,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.35)),
            if (message.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(message.errorMessage!,
                    style: const TextStyle(fontSize: 10, color: AppTheme.rubyRed)),
              ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_shortTime(message.createdAt),
                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                if (!inbound) ...[
                  const SizedBox(width: 4),
                  Icon(_statusIcon(message.status), size: 11,
                      color: message.status == 'read' ? AppTheme.brightGold : AppTheme.textSecondary),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'audio':
        return Icons.mic_none;
      case 'document':
        return Icons.description_outlined;
      case 'location':
        return Icons.location_on_outlined;
      case 'template':
        return Icons.article_outlined;
      case 'interactive':
        return Icons.touch_app_outlined;
      case 'reaction':
        return Icons.emoji_emotions_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'read':
        return Icons.done_all;
      case 'delivered':
        return Icons.done_all;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.done;
    }
  }

  Widget _composer(WaWindow window) {
    final disabled = !window.open;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.obsidianMedium,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          if (disabled)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.rubyRed.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: AppTheme.rubyRed),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'The 24-hour window is closed. Send an approved template to start a new conversation.',
                      style: TextStyle(fontSize: 11, color: AppTheme.rubyRed),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: 'Attach a file',
                onPressed: disabled || _sending ? null : _attachFile,
                icon: const Icon(Icons.attach_file, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _composerController,
                  enabled: !disabled,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: disabled ? 'Free text is closed — use a template' : 'Type a message',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.obsidianLight,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (disabled)
                FilledButton.icon(
                  onPressed: _sending ? null : _sendTemplate,
                  icon: const Icon(Icons.article_outlined, size: 16),
                  label: const Text('Template', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.royalGold),
                )
              else
                IconButton.filled(
                  onPressed: _sending ? null : _sendText,
                  icon: _sending
                      ? const SizedBox(
                          width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 18),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.royalGold),
                ),
            ],
          ),
          if (!disabled)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _sending ? null : _sendTemplate,
                icon: const Icon(Icons.article_outlined, size: 14),
                label: const Text('Send a template', style: TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }

  String _shortTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final sameDay = local.year == DateTime.now().year &&
        local.month == DateTime.now().month &&
        local.day == DateTime.now().day;
    if (sameDay) return '$h:$m';
    return '${local.day}/${local.month} $h:$m';
  }
}

/// Picks an approved template, lets the operator fill its variables, and returns
/// `{name, language, params}`.
class _TemplatePickerDialog extends StatefulWidget {
  final WhatsAppService service;
  final bool variablesHint;

  const _TemplatePickerDialog({required this.service, this.variablesHint = false});

  @override
  State<_TemplatePickerDialog> createState() => _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends State<_TemplatePickerDialog> {
  List<WaTemplate> _templates = [];
  WaTemplate? _selected;
  bool _loading = true;
  String _language = 'hi';
  final List<TextEditingController> _params = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _params) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.service.fetchTemplates(language: _language, status: 'APPROVED');
      if (!mounted) return;
      setState(() {
        _templates = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _select(WaTemplate template) {
    for (final c in _params) {
      c.dispose();
    }
    _params.clear();
    for (var i = 0; i < template.variables; i++) {
      _params.add(TextEditingController());
    }
    setState(() => _selected = template);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send a template', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('हिंदी', style: TextStyle(fontSize: 12)),
                  selected: _language == 'hi',
                  onSelected: (_) {
                    setState(() => _language = 'hi');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('English', style: TextStyle(fontSize: 12)),
                  selected: _language == 'en',
                  onSelected: (_) {
                    setState(() => _language = 'en');
                    _load();
                  },
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Sync from Meta',
                  onPressed: () async {
                    await widget.service.syncTemplates();
                    _load();
                  },
                  icon: const Icon(Icons.sync, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_templates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No approved templates in this language. Create one in Templates, then sync.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  children: _templates
                      .map((t) => RadioListTile<String>(
                            dense: true,
                            value: t.name,
                            groupValue: _selected?.name,
                            onChanged: (_) => _select(t),
                            title: Text(t.name, style: const TextStyle(fontSize: 12)),
                            subtitle: Text(
                              t.bodyText ?? t.category ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ))
                      .toList(),
                ),
              ),
            if (_selected != null && _params.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Fill the variables', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...List.generate(_params.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _params[i],
                      decoration: InputDecoration(
                        labelText: '{{${i + 1}}}',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, {
                    'name': _selected!.name,
                    'language': _selected!.language,
                    'params': _params.map((c) => c.text).toList(),
                  }),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
