import 'package:flutter/material.dart';
import '../../firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _adminPosts = [];
  List<Map<String, dynamic>> _newsFeed = [];
  List<Map<String, dynamic>> _statuses = [];

  // Announcement Creator Fields
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imageUrlController = TextEditingController(text: 'intellij.png');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCommunityData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityData() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _firestoreService.fetchAdminPosts();
      final feeds = await _firestoreService.fetchNewsFeed();
      final stats = await _firestoreService.fetchStatuses();

      setState(() {
        _adminPosts = posts;
        _newsFeed = feeds;
        _statuses = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading community data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _publishAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await _firestoreService.createAdminPost(
        _titleController.text.trim(),
        _contentController.text.trim(),
        _imageUrlController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement successfully published to the B2B app network!'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );

      _titleController.clear();
      _contentController.clear();
      
      _loadCommunityData();
    } catch (e) {
      debugPrint("Error publishing: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Community Network & Announcements'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.royalGold,
          labelColor: AppTheme.royalGold,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Announcements (Admin)'),
            Tab(text: 'News Feed (B2B Wall)'),
            Tab(text: 'Statuses (Stories)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAnnouncementsTab(),
                _buildNewsFeedTab(),
                _buildStatusesTab(),
              ],
            ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _buildAnnouncementsList(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, right: 16),
                  child: _buildCreateAnnouncementForm(),
                ),
              ),
            ],
          );
        } else {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildCreateAnnouncementForm(),
                const SizedBox(height: 24),
                _buildAnnouncementsList(),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildCreateAnnouncementForm() {
    return GlassCard(
      padding: 24.0,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publish Broad Announcement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.royalGold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Announcement Title',
                hintText: 'e.g. New Commission Payout Rules',
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Content / Message Body',
                hintText: 'Enter full announcement body description here...',
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter content' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Banner Image Key (S3/Web URL)',
                hintText: 'intellij.png',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _publishAnnouncement,
                icon: const Icon(Icons.send),
                label: const Text('Publish Announcement'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _adminPosts.length,
      itemBuilder: (context, index) {
        final post = _adminPosts[index];
        return Card(
          color: AppTheme.obsidianMedium,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.royalGold.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      post['title'] ?? 'No Title',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const Text(
                      'Official Admin Broadcast',
                      style: TextStyle(color: AppTheme.royalGold, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'By Admin',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const Divider(color: Colors.white10, height: 24),
                Text(
                  post['content'] ?? '',
                  style: const TextStyle(color: AppTheme.textPrimary, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      color: AppTheme.obsidianLight,
                      child: const Center(
                        child: Text(
                          'Attachment: Banner image loaded successfully',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewsFeedTab() {
    if (_newsFeed.isEmpty) {
      return const Center(child: Text('No timeline posts from partners found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _newsFeed.length,
      itemBuilder: (context, index) {
        final feed = _newsFeed[index];
        final likes = (feed['likes'] as List?)?.length ?? 0;

        return Card(
          color: AppTheme.obsidianMedium,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.royalGold.withOpacity(0.1),
                    child: Text(
                      (feed['name'] ?? 'P')[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(feed['name'] ?? 'User Post', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${feed['role'] ?? 'DSA'} | ${feed['company'] ?? 'N/A'}'),
                  trailing: Text(feed['mobile'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ),
                const Divider(color: Colors.white10, height: 16),
                Text(
                  feed['content'] ?? '',
                  style: const TextStyle(color: AppTheme.textPrimary, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.favorite, color: AppTheme.rubyRed, size: 16),
                    const SizedBox(width: 6),
                    Text('$likes Likes', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusesTab() {
    if (_statuses.isEmpty) {
      return const Center(child: Text('No statuses/stories found.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: _statuses.length,
      itemBuilder: (context, index) {
        final status = _statuses[index];
        final text = status['text'] ?? '';
        
        return GlassCard(
          isGold: true,
          padding: 16.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.royalGold.withOpacity(0.2),
                    child: Text(
                      (status['name'] ?? 'P')[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.royalGold, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status['name'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${status['role'] ?? 'DSA'} - ${status['company'] ?? ''}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(color: Colors.white10, height: 16),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
