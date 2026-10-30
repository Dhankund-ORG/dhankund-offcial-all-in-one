import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../api_service.dart';
import '../../cloudflare_r2_service.dart';
import '../../theme/app_theme.dart';

class BlogPostsPage extends StatefulWidget {
  const BlogPostsPage({super.key});

  @override
  State<BlogPostsPage> createState() => _BlogPostsPageState();
}

class _BlogPostsPageState extends State<BlogPostsPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String _statusFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final posts = await _api.fetchBlogPosts();
    final categories = await _api.fetchBlogCategories();
    if (mounted) {
      setState(() {
        _posts = posts;
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPosts {
    return _posts.where((p) {
      final matchesStatus = _statusFilter == 'All' || p['status'] == _statusFilter;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          (p['title']?.toString().toLowerCase().contains(q) ?? false) ||
          (p['excerpt']?.toString().toLowerCase().contains(q) ?? false) ||
          (p['author_name']?.toString().toLowerCase().contains(q) ?? false) ||
          (p['category_name']?.toString().toLowerCase().contains(q) ?? false);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _openEditor({Map<String, dynamic>? post}) async {
    final saved = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlogEditorPage(post: post, categories: _categories),
    ));
    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('लेख हटाएँ?'),
        content: Text('"${post['title']}" को स्थायी रूप से हटा दें?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rubyRed),
            child: const Text('हटाएँ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.deleteBlogPost(post['id'].toString());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('लेख हटा दिया गया')));
    await _loadData();
  }

  void _openCategories() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CategoriesDialog(
        categories: List<Map<String, dynamic>>.from(_categories),
        onChanged: () async {
          final categories = await _api.fetchBlogCategories();
          if (ctx.mounted) {
            // ignore: use_build_context_synchronously
            Navigator.of(ctx).pop();
          }
          if (mounted) {
            setState(() => _categories = categories);
          }
        },
      ),
    );
    if (changed == true) await _loadData();
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
              const Icon(Icons.article_outlined, color: AppTheme.brightGold, size: 22),
              const SizedBox(width: 10),
              const Text(
                'BLOG POSTS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _openCategories,
                icon: const Icon(Icons.category_outlined, size: 18),
                label: const Text('Categories'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.royalGold,
                  side: const BorderSide(color: AppTheme.royalGold),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('नया लेख'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalGold,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search लेख...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('सभी')),
                  DropdownMenuItem(value: 'published', child: Text('Published')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v!),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPosts.isEmpty
                    ? const Center(
                        child: Text('कोई लेख नहीं', style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.separated(
                        itemCount: _filteredPosts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final post = _filteredPosts[index];
                          return _PostCard(
                            post: post,
                            onEdit: () => _openEditor(post: post),
                            onDelete: () => _deletePost(post),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostCard({required this.post, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPublished = post['status'] == 'published';
    final title = post['title']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          if (post['cover_image'] != null && post['cover_image'].toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _resolveUrl(post['cover_image'].toString()),
                width: 72,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 48,
                  color: AppTheme.obsidianLight,
                  child: const Icon(Icons.image_not_supported_outlined, size: 20),
                ),
              ),
            )
          else
            Container(
              width: 72,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.obsidianLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.article_outlined, size: 22, color: AppTheme.textSecondary),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusBadge(isPublished: isPublished),
                    if (post['language'] == 'hi') ...[
                      const SizedBox(width: 6),
                      const Text('हिंदी', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen)),
                    ],
                    if (post['category_name'] != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        post['category_name'].toString(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${post['author_name'] ?? 'Dhankund'} • ${post['updated_at']?.toString().substring(0, 10) ?? ''}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppTheme.royalGold),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppTheme.rubyRed),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isPublished;
  const _StatusBadge({required this.isPublished});

  @override
  Widget build(BuildContext context) {
    final color = isPublished ? AppTheme.emeraldGreen : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isPublished ? 'PUBLISHED' : 'DRAFT',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
      ),
    );
  }
}

String _resolveUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  return ApiClient.baseUrl + url;
}

String _slugify(String text) {
  return text
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s-]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

// ============================ EDITOR ============================

class BlogEditorPage extends StatefulWidget {
  final Map<String, dynamic>? post;
  final List<Map<String, dynamic>> categories;

  const BlogEditorPage({super.key, this.post, required this.categories});

  @override
  State<BlogEditorPage> createState() => _BlogEditorPageState();
}

class _BlogEditorPageState extends State<BlogEditorPage> {
  final ApiService _api = ApiService();
  final CloudflareR2Service _r2 = CloudflareR2Service();

  late final TextEditingController _titleController;
  late final TextEditingController _slugController;
  late final TextEditingController _excerptController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  late final TextEditingController _coverUrlController;

  late String _language;
  late String _categoryId;
  bool _isSaving = false;
  bool _isUploadingCover = false;
  bool _slugTouched = false;

  final FocusNode _contentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _titleController = TextEditingController(text: post?['title'] ?? '');
    _slugController = TextEditingController(text: post?['slug'] ?? '');
    _excerptController = TextEditingController(text: post?['excerpt'] ?? '');
    _contentController = TextEditingController(text: post?['content'] ?? '');
    _tagsController = TextEditingController(
      text: (post?['tags'] is List ? (post!['tags'] as List).join(', ') : ''),
    );
    _coverUrlController = TextEditingController(text: post?['cover_image'] ?? '');
    _language = post?['language'] == 'en' ? 'en' : 'hi';
    _categoryId = post?['category_id']?.toString() ?? '';
    if (widget.post != null) _slugTouched = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _excerptController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _coverUrlController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    if (!_slugTouched) {
      _slugController.text = _slugify(value);
    }
    setState(() {});
  }

  void _insertIntoContent(String before, String after, {String? placeholder}) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = text.substring(start, end);
    final inserted = before + (selected.isNotEmpty ? selected : (placeholder ?? '')) + after;
    final newText = text.substring(0, start) + inserted + text.substring(end);
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(offset: start + inserted.length);
    _contentFocus.requestFocus();
    setState(() {});
  }

  Future<void> _uploadCoverImage() async {
    final result = await FilePicker.pickFile(type: FileType.image);
    if (result == null) return;
    setState(() => _isUploadingCover = true);
    try {
      final bytes = await result.readAsBytes();
      final url = await _r2.uploadDocument('blog/' + result.name, bytes);
      if (url != null) {
        _coverUrlController.text = url;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover इमेज अपलोड हो गई')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('अपलोड विफल')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('अपलोड error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _insertImageFromGallery() async {
    final result = await FilePicker.pickFile(type: FileType.image);
    if (result == null) return;
    try {
      final bytes = await result.readAsBytes();
      final url = await _r2.uploadDocument('blog/' + result.name, bytes);
      if (url != null) {
        _insertIntoContent('![${result.name}]($url)', '', placeholder: '');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('इमेज अपलोड विफल')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('अपलोड error: $e')));
    }
  }

  Future<void> _save({required bool publish}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('शीर्षक (Title) ज़रूरी है')));
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('लेख की सामग्री लिखें')));
      return;
    }
    setState(() => _isSaving = true);
    final body = <String, dynamic>{
      'title': title,
      'slug': _slugController.text.trim().isNotEmpty ? _slugController.text.trim() : _slugify(title),
      'content': _contentController.text,
      'excerpt': _excerptController.text.trim(),
      'cover_image': _coverUrlController.text.trim().isEmpty ? null : _coverUrlController.text.trim(),
      'category_id': _categoryId.isEmpty ? null : _categoryId,
      'category_name': _categoryName(),
      'tags': _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      'language': _language,
      'status': publish ? 'published' : 'draft',
      'author_name': ApiClient.currentUserRole == 'admin' ? 'Dhankund' : (ApiClient.currentUserId ?? 'Admin'),
    };
    try {
      if (widget.post == null) {
        await _api.createBlogPost(body);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(publish ? 'लेख publish हो गया!' : 'Draft सहेजा गया')));
      } else {
        await _api.updateBlogPost(widget.post!['id'].toString(), body);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(publish ? 'लेख publish हो गया!' : 'लेख अपडेट हो गया')));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('सहेजने में error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  String? _categoryName() {
    for (final c in widget.categories) {
      if (c['id'].toString() == _categoryId) return c['name']?.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.post != null;
    final isDesktop = MediaQuery.of(context).size.width > 1000;
    final editor = _buildEditor(isDesktop);
    final preview = _buildPreview();

    return Scaffold(
      backgroundColor: AppTheme.obsidianDark,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(isEdit ? 'लेख संपादित करें' : 'नया लेख'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!isDesktop)
            TextButton(
              onPressed: () => _save(publish: false),
              child: const Text('Save Draft'),
            ),
          if (!isDesktop)
            ElevatedButton(
              onPressed: _isSaving ? null : () => _save(publish: true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
              child: const Text('Publish'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                Expanded(flex: 5, child: editor),
                Container(width: 1, color: const Color(0xFFE2E8F0)),
                Expanded(flex: 5, child: preview),
              ],
            )
          : Column(
              children: [
                Expanded(child: editor),
                Container(height: 1, color: const Color(0xFFE2E8F0)),
                SizedBox(
                  height: 260,
                  child: preview,
                ),
              ],
            ),
      bottomNavigationBar: isDesktop
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('रद्द करें'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => _save(publish: false),
                    child: const Text('Save Draft'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : () => _save(publish: true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
                    child: Text(_isSaving ? 'सहेज रहे...' : 'Publish'),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildEditor(bool isDesktop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            onChanged: _onTitleChanged,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'शीर्षक (Title) *',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _slugController,
                  onChanged: (_) {
                    _slugTouched = true;
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Slug (URL)',
                    hintText: 'loan-tips-2026',
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: _language,
                  decoration: const InputDecoration(
                    labelText: 'भाषा',
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) => setState(() => _language = v ?? 'hi'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _categoryId.isEmpty ? null : _categoryId,
                  hint: const Text('Category चुनें'),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  items: widget.categories
                      .map((c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text('${c['name']} (${c['language'] == 'hi' ? 'हिंदी' : 'EN'})'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v ?? ''),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    hintText: 'loan, tips',
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _excerptController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Summary / Excerpt (कार्ड पर दिखेगा)',
              hintText: 'लेख का छोटा सारांश...',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildCoverImageField(),
          const SizedBox(height: 14),
          // Formatting toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _ToolbarButton(
                  icon: Icons.format_bold,
                  tooltip: 'Bold',
                  onTap: () => _insertIntoContent('**', '**', placeholder: 'bold text'),
                ),
                _ToolbarButton(
                  icon: Icons.format_italic,
                  tooltip: 'Italic',
                  onTap: () => _insertIntoContent('*', '*', placeholder: 'italic text'),
                ),
                _ToolbarButton(
                  icon: Icons.title,
                  tooltip: 'Heading',
                  onTap: () => _insertIntoContent('## ', '', placeholder: 'शीर्षक'),
                ),
                _ToolbarButton(
                  icon: Icons.format_list_bulleted,
                  tooltip: 'Bullet list',
                  onTap: () => _insertIntoContent('\n- ', '', placeholder: 'item'),
                ),
                _ToolbarButton(
                  icon: Icons.format_list_numbered,
                  tooltip: 'Numbered list',
                  onTap: () => _insertIntoContent('\n1. ', '', placeholder: 'item'),
                ),
                _ToolbarButton(
                  icon: Icons.link,
                  tooltip: 'Link',
                  onTap: () => _insertIntoContent('[', '](https://)', placeholder: 'link text'),
                ),
                _ToolbarButton(
                  icon: Icons.image_outlined,
                  tooltip: 'Image (file)',
                  onTap: _insertImageFromGallery,
                ),
                _ToolbarButton(
                  icon: Icons.insert_photo_outlined,
                  tooltip: 'Image (URL)',
                  onTap: () => _insertIntoContent('![alt](', ')', placeholder: 'https://image-url'),
                ),
                _ToolbarButton(
                  icon: Icons.format_quote,
                  tooltip: 'Quote',
                  onTap: () => _insertIntoContent('\n> ', '', placeholder: 'quote'),
                ),
                _ToolbarButton(
                  icon: Icons.horizontal_rule,
                  tooltip: 'Divider',
                  onTap: () => _insertIntoContent('\n---\n', '', placeholder: ''),
                ),
              ],
            ),
          ),
          TextField(
            controller: _contentController,
            focusNode: _contentFocus,
            maxLines: null,
            minLines: 18,
            style: const TextStyle(fontSize: 14, height: 1.6, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'यहाँ लेख लिखें (Markdown)...\n\n## परिचय\nयहाँ लिखें...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Markdown supported: **bold**, *italic*, ## headings, - lists, [link](url), ![image](url), > quote',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImageField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _coverUrlController,
            decoration: const InputDecoration(
              labelText: 'Cover इमेज URL',
              hintText: 'अपलोड करें या URL डालें',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _isUploadingCover ? null : _uploadCoverImage,
          icon: _isUploadingCover
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file, size: 18),
          label: const Text('Upload'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.royalGold),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F172A),
            child: const Row(
              children: [
                Icon(Icons.visibility_outlined, color: Color(0xFF94A3B8), size: 16),
                SizedBox(width: 6),
                Text(
                  'LIVE PREVIEW — वेबसाइट पर ऐसा दिखेगा',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCBD5E1),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_coverUrlController.text.trim().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _resolveUrl(_coverUrlController.text.trim()),
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: AppTheme.obsidianLight,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _titleController.text.isEmpty ? 'लेख का शीर्षक' : _titleController.text,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_language == 'hi' ? 'Dhankund' : 'Dhankund'} • ${DateTime.now().year}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (_contentController.text.trim().isEmpty)
                    const Text(
                      'यहाँ लिखना शुरू करें — Preview अपने आप update होता रहेगा।',
                      style: TextStyle(color: AppTheme.textSecondary),
                    )
                  else
                    Markdown(
                      data: _contentController.text,
                      selectable: false,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 15, height: 1.7, color: Color(0xFF334155)),
                        h1: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        h2: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        h4: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        blockquote: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                        blockquoteDecoration: const BoxDecoration(
                          border: Border(left: BorderSide(color: AppTheme.royalGold, width: 3)),
                        ),
                        blockquotePadding: const EdgeInsets.only(left: 12),
                        code: const TextStyle(
                          fontFamily: 'monospace',
                          backgroundColor: Color(0xFFF1F5F9),
                          color: AppTheme.royalGold,
                        ),
                        codeblockDecoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        codeblockPadding: const EdgeInsets.all(12),
                        listBullet: const TextStyle(color: AppTheme.royalGold),
                      ),
                      imageBuilder: (uri, title, alt) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Image.network(
                            _resolveUrl(uri.toString()),
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                          ),
                        );
                      },
                      onTapLink: (text, href, title) {
                        if (href != null && href.startsWith('http')) {
                          // open external link
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.obsidianLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

// ============================ CATEGORIES ============================

class CategoriesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final VoidCallback onChanged;

  const CategoriesDialog({super.key, required this.categories, required this.onChanged});

  @override
  State<CategoriesDialog> createState() => _CategoriesDialogState();
}

class _CategoriesDialogState extends State<CategoriesDialog> {
  final ApiService _api = ApiService();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  String _language = 'hi';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _slugController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _api.createBlogCategory(
        name,
        _slugController.text.trim().isNotEmpty ? _slugController.text.trim() : _slugify(name),
        _language,
      );
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Category बनाने में error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Category हटाएँ?'),
        content: Text('"${category['name']}" हटाएँ? इस category के लेखों की category हट जाएगी।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rubyRed),
            child: const Text('हटाएँ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.deleteBlogCategory(category['id'].toString());
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Blog Categories'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.categories.isNotEmpty)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: widget.categories
                      .map((c) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${c['name']} (${c['language'] == 'hi' ? 'हिंदी' : 'EN'})'),
                            subtitle: Text('/blog?category=${c['slug']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.rubyRed, size: 20),
                              onPressed: () => _delete(c),
                            ),
                          ))
                      .toList(),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('अभी कोई category नहीं', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            const Divider(),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'नई category का नाम',
                isDense: true,
              ),
              onChanged: (_) {
                if (!_slugTouchedCat) {
                  _slugController.text = _slugify(_nameController.text);
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _slugController,
              decoration: const InputDecoration(labelText: 'Slug', isDense: true),
              onChanged: (_) {
                _slugTouchedCat = true;
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(labelText: 'भाषा', isDense: true),
              items: const [
                DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) => setState(() => _language = v ?? 'hi'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saving ? null : _create,
              icon: const Icon(Icons.add, size: 18),
              label: Text(_saving ? 'बना रहे...' : 'Category बनाएँ'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalGold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('बंद करें'),
        ),
      ],
    );
  }

  bool _slugTouchedCat = false;
}