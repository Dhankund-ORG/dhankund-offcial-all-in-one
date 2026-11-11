import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../whatsapp_models.dart';
import '../../whatsapp_service.dart';

/// Broadcast: choose an audience that already exists in the CRM, pick an
/// approved template, preview exactly who will be reached and who is skipped,
/// then start the campaign and watch it progress.
class WhatsappBroadcastPage extends StatefulWidget {
  const WhatsappBroadcastPage({super.key});

  @override
  State<WhatsappBroadcastPage> createState() => _WhatsappBroadcastPageState();
}

class _WhatsappBroadcastPageState extends State<WhatsappBroadcastPage> {
  final WhatsAppService _service = WhatsAppService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _statusFilter = TextEditingController();

  static const List<Map<String, String>> _sources = [
    {'key': 'registrations', 'label': 'Partner / DSA registrations'},
    {'key': 'loans', 'label': 'Loan applications'},
    {'key': 'referrals', 'label': 'Referral and website leads'},
    {'key': 'insurance', 'label': 'Insurance applications'},
    {'key': 'users', 'label': 'Registered users'},
    {'key': 'contacts', 'label': 'Existing WhatsApp contacts'},
  ];

  final Set<String> _selectedSources = {'loans'};
  List<WaTemplate> _templates = [];
  WaTemplate? _selectedTemplate;
  WaAudiencePreview? _preview;
  List<WaBroadcast> _broadcasts = [];
  bool _loadingTemplates = true;
  bool _loadingBroadcasts = true;
  bool _previewing = false;
  bool _sending = false;
  bool _requireOptIn = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadBroadcasts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusFilter.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final list = await _service.fetchTemplates(status: 'APPROVED');
      if (!mounted) return;
      setState(() {
        _templates = list;
        // Keep the current choice only if it is still in the list, otherwise
        // fall back to the first approved template.
        final stillThere = list.any((t) => t.name == _selectedTemplate?.name && t.language == _selectedTemplate?.language);
        if (!stillThere) _selectedTemplate = list.isNotEmpty ? list.first : null;
        _loadingTemplates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTemplates = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _loadBroadcasts() async {
    setState(() => _loadingBroadcasts = true);
    try {
      final list = await _service.fetchBroadcasts();
      if (!mounted) return;
      setState(() {
        _broadcasts = list;
        _loadingBroadcasts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBroadcasts = false);
    }
  }

  Map<String, String> get _filters {
    final map = <String, String>{};
    if (_statusFilter.text.trim().isNotEmpty) map['status'] = _statusFilter.text.trim();
    return map;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppTheme.rubyRed : AppTheme.emeraldGreen,
    ));
  }

  Future<void> _previewAudience() async {
    if (_selectedSources.isEmpty) {
      _toast('Choose at least one audience', error: true);
      return;
    }
    setState(() {
      _previewing = true;
      _preview = null;
    });
    try {
      final preview = await _service.previewAudience(
        sources: _selectedSources.toList(),
        filters: _filters,
        requireOptIn: _requireOptIn,
      );
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      _toast(e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _start() async {
    final template = _selectedTemplate;
    if (template == null) {
      _toast('Choose an approved template first', error: true);
      return;
    }
    final total = _preview?.total ?? 0;
    if (total == 0) {
      _toast('Preview the audience first — nobody would be reached', error: true);
      return;
    }
    if (total > 5000) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Large campaign', style: TextStyle(fontSize: 16)),
          content: Text(
            'This will send to $total people. WhatsApp charges per conversation and a poor campaign can hurt the number quality. Continue?',
            style: const TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _sending = true);
    try {
      final result = await _service.createBroadcast(
        name: _nameController.text.trim().isEmpty ? 'Campaign' : _nameController.text.trim(),
        templateName: template.name,
        templateLang: template.language,
        sources: _selectedSources.toList(),
        filters: _filters,
        requireOptIn: _requireOptIn,
      );
      _toast('Campaign started for ${result['total'] ?? total} recipients');
      _nameController.clear();
      setState(() => _preview = null);
      await _loadBroadcasts();
    } catch (e) {
      _toast(e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 1100;
    final setup = _buildSetupPanel();
    final history = _buildHistoryPanel();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: SingleChildScrollView(child: setup)),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: history),
              ],
            )
          : ListView(children: [setup, const SizedBox(height: 16), history]),
    );
  }

  Widget _buildSetupPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianMedium,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, size: 18, color: AppTheme.royalGold),
              const SizedBox(width: 8),
              const Text('New WhatsApp campaign',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadTemplates,
                icon: const Icon(Icons.sync, size: 14),
                label: const Text('Sync templates', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Campaign name (internal only)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Text('Audience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Taken from the data already in the CRM — no upload needed.',
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ..._sources.map((source) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selectedSources.contains(source['key']),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedSources.add(source['key']!);
                    } else {
                      _selectedSources.remove(source['key']);
                    }
                    _preview = null;
                  });
                },
                title: Text(source['label']!, style: const TextStyle(fontSize: 12)),
                controlAffinity: ListTileControlAffinity.leading,
              )),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status filter (optional, e.g. Pending)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => setState(() => _preview = null),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Switch(
                    value: _requireOptIn,
                    onChanged: (v) => setState(() {
                      _requireOptIn = v;
                      _preview = null;
                    }),
                  ),
                  const Text('Opt-in only', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_loadingTemplates)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_templates.isEmpty)
            const Text('No approved templates. Create one in Templates first.',
                style: TextStyle(fontSize: 11, color: AppTheme.rubyRed))
          else
            DropdownButtonFormField<WaTemplate>(
              value: _selectedTemplate,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              items: _templates
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text('${t.name} · ${t.languageLabel} · ${t.category ?? ''}',
                            style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedTemplate = v),
            ),
          if (_selectedTemplate?.bodyText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF8C6).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_selectedTemplate!.bodyText!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.4)),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _previewing ? null : _previewAudience,
                icon: _previewing
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.groups_outlined, size: 15),
                label: const Text('Preview audience', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _sending ? null : _start,
                icon: _sending
                    ? const SizedBox(
                        width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 15),
                label: const Text('Start campaign', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.royalGold),
              ),
            ],
          ),
          if (_preview != null) ...[
            const SizedBox(height: 14),
            _previewCard(_preview!),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(fontSize: 11, color: AppTheme.rubyRed)),
            ),
        ],
      ),
    );
  }

  Widget _previewCard(WaAudiencePreview preview) {
    final skipped = preview.skipped;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.obsidianLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, size: 15, color: AppTheme.royalGold),
              const SizedBox(width: 6),
              Text('${preview.total} people will receive this',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (preview.perSource.isNotEmpty)
            Text(
              'Source: ${preview.perSource.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: skipped.entries
                .where((e) => e.value > 0)
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.rubyRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${e.value} skipped · ${e.key}',
                          style: const TextStyle(fontSize: 9, color: AppTheme.rubyRed)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianMedium,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: AppTheme.royalGold),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Campaigns',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
              ),
              IconButton(
                onPressed: _loadBroadcasts,
                icon: const Icon(Icons.refresh, size: 17),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingBroadcasts)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_broadcasts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No campaigns yet', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            )
          else
            ..._broadcasts.map(_broadcastRow),
        ],
      ),
    );
  }

  Widget _broadcastRow(WaBroadcast broadcast) {
    final running = broadcast.status == 'running' || broadcast.status == 'queued';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE6ECF3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(broadcast.name ?? broadcast.templateName ?? 'Campaign',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (running ? AppTheme.brightGold : AppTheme.emeraldGreen).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(broadcast.status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: running ? AppTheme.brightGold : AppTheme.emeraldGreen,
                    )),
              ),
              if (running)
                IconButton(
                  tooltip: 'Pause',
                  onPressed: () async {
                    await _service.pauseBroadcast(broadcast.id);
                    _loadBroadcasts();
                  },
                  icon: const Icon(Icons.pause_circle_outline, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${broadcast.templateName ?? ''} · ${broadcast.templateLang ?? ''}',
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: broadcast.progress,
              minHeight: 6,
              backgroundColor: AppTheme.obsidianLight,
              color: AppTheme.royalGold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'sent ${broadcast.sent} · delivered ${broadcast.delivered} · read ${broadcast.read} · failed ${broadcast.failed} of ${broadcast.total}',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
