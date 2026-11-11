import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../whatsapp_models.dart';
import '../../whatsapp_service.dart';

/// Template manager: list what Meta has approved, create a Hindi + English pair
/// in one go, sync from Meta, and delete what is no longer needed.
class WhatsappTemplatesPage extends StatefulWidget {
  const WhatsappTemplatesPage({super.key});

  @override
  State<WhatsappTemplatesPage> createState() => _WhatsappTemplatesPageState();
}

class _WhatsappTemplatesPageState extends State<WhatsappTemplatesPage> {
  final WhatsAppService _service = WhatsAppService();
  List<WaTemplate> _templates = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _languageFilter = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchTemplates(
        language: _languageFilter,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _templates = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppTheme.rubyRed : AppTheme.emeraldGreen,
    ));
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      final result = await _service.syncTemplates();
      _toast('Synced ${result['synced'] ?? 0} template(s) from Meta');
      await _load();
    } catch (e) {
      _toast(e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CreateTemplateDialog(),
    );
    if (created == null) return;
    setState(() => _busy = true);
    try {
      final result = await _service.createTemplate(
        name: created['name'] as String,
        category: created['category'] as String,
        bodyHi: created['bodyHi'] as String,
        bodyEn: created['bodyEn'] as String,
        headerText: created['header'] as String?,
        footer: created['footer'] as String?,
        bothLanguages: created['both'] as bool? ?? true,
      );
      final failed = result['failed'];
      if (failed is List && failed.isNotEmpty) {
        _toast('Created ${(result['created'] as List?)?.length ?? 0}, failed ${failed.length}. Check the language list.', error: true);
      } else {
        _toast('Template "${created['name']}" sent to Meta for approval');
      }
      await _load();
    } catch (e) {
      _toast(e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(WaTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete template?', style: TextStyle(fontSize: 16)),
        content: Text(
          'This deletes "${template.name}" (${template.language}) from Meta as well. Campaigns using it will stop.',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.rubyRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _service.deleteTemplate(template.id);
      _toast('Template deleted');
      await _load();
    } catch (e) {
      _toast(e.toString().replaceFirst('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 18, color: AppTheme.royalGold),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('WhatsApp Templates',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _sync,
                icon: const Icon(Icons.sync, size: 15),
                label: const Text('Sync from Meta', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New template', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.royalGold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _filterChip('All languages', '', (v) {
                setState(() => _languageFilter = v);
                _load();
              }, selected: _languageFilter.isEmpty),
              _filterChip('हिंदी', 'hi', (v) {
                setState(() => _languageFilter = v);
                _load();
              }, selected: _languageFilter == 'hi'),
              _filterChip('English', 'en', (v) {
                setState(() => _languageFilter = v);
                _load();
              }, selected: _languageFilter == 'en'),
              const SizedBox(width: 16),
              _filterChip('Approved', 'APPROVED', (v) {
                setState(() => _statusFilter = v);
                _load();
              }, selected: _statusFilter == 'APPROVED'),
              _filterChip('Pending', 'PENDING', (v) {
                setState(() => _statusFilter = v);
                _load();
              }, selected: _statusFilter == 'PENDING'),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppTheme.rubyRed, fontSize: 12)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _templates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article_outlined,
                                size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text('No templates yet',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            const Text('Create one, or press Sync to pull what Meta already has.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisExtent: 190,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _templates.length,
                        itemBuilder: (_, index) => _templateCard(_templates[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, ValueChanged<String> onSelected, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onSelected(value),
      ),
    );
  }

  Widget _templateCard(WaTemplate template) {
    final approved = template.approved;
    final color = approved
        ? AppTheme.emeraldGreen
        : (template.status?.toUpperCase() == 'REJECTED' ? AppTheme.rubyRed : AppTheme.brightGold);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.obsidianMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  template.status ?? 'UNKNOWN',
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _pill(template.languageLabel),
              const SizedBox(width: 6),
              _pill(template.category ?? 'UTILITY'),
              if (template.variables > 0) ...[
                const SizedBox(width: 6),
                _pill('${template.variables} var'),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              template.bodyText ?? 'Body not synced yet — press Sync.',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Delete from Meta',
              onPressed: _busy ? null : () => _delete(template),
              icon: const Icon(Icons.delete_outline, size: 17, color: AppTheme.rubyRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.obsidianLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
    );
  }
}

class _CreateTemplateDialog extends StatefulWidget {
  const _CreateTemplateDialog();

  @override
  State<_CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<_CreateTemplateDialog> {
  final _name = TextEditingController();
  final _header = TextEditingController();
  final _bodyHi = TextEditingController();
  final _bodyEn = TextEditingController();
  final _footer = TextEditingController();
  String _category = 'UTILITY';
  bool _both = true;

  @override
  void dispose() {
    _name.dispose();
    _header.dispose();
    _bodyHi.dispose();
    _bodyEn.dispose();
    _footer.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Template name is required';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(name)) {
      return 'Name can only use lowercase letters, digits and underscore';
    }
    if (_both && _bodyHi.text.trim().isEmpty) return 'Hindi body is required';
    if (_bodyEn.text.trim().isEmpty) return 'English body is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New template', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Template name (e.g. loan_status_update)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  DropdownButton<String>(
                    value: _category,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'UTILITY', child: Text('Utility', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'MARKETING', child: Text('Marketing', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'AUTHENTICATION', child: Text('Authentication', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'UTILITY'),
                  ),
                  const SizedBox(width: 16),
                  Checkbox(
                    value: _both,
                    onChanged: (v) => setState(() => _both = v ?? true),
                  ),
                  const Text('Create Hindi + English together', style: TextStyle(fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _header,
                decoration: const InputDecoration(
                  labelText: 'Header (optional, 60 characters)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (_both) ...[
                TextField(
                  controller: _bodyHi,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Hindi body — use {{1}}, {{2}} for variables',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _bodyEn,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'English body — use {{1}}, {{2}} for variables',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _footer,
                decoration: const InputDecoration(
                  labelText: 'Footer (optional, 60 characters)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                'Meta reviews new templates. They show as PENDING until approved, and only approved ones can be sent.',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final problem = _validate();
            if (problem != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(problem), backgroundColor: AppTheme.rubyRed),
              );
              return;
            }
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'category': _category,
              'bodyHi': _bodyHi.text.trim(),
              'bodyEn': _bodyEn.text.trim(),
              'header': _header.text.trim(),
              'footer': _footer.text.trim(),
              'both': _both,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
