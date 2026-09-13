import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_flutter_app/services/api_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/cloudflare_r2_service.dart';
import 'package:my_flutter_app/presentation/shared/my_profile_screen.dart';
import 'package:my_flutter_app/presentation/partner_app/refer_friend_form_screen.dart';
import 'package:my_flutter_app/presentation/partner_app/referral_dashboard_screen.dart';
import 'package:my_flutter_app/presentation/shared/user_profile_card.dart';
import 'package:my_flutter_app/presentation/b2b_network/status_stories_widget.dart';
import 'package:my_flutter_app/presentation/shared/my_loan_dashboard_screen.dart';
import 'package:my_flutter_app/presentation/shared/my_earnings_screen.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});
  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  int _selectedIndex = 0;
  String _userRole = 'Discover';
  String _targetCollection = 'admin_posts';
  bool _isRoleLoading = true;
  Map<String, dynamic> _currentUserProfile = {};
  List<Map<String, dynamic>> _statuses = [];
  List<Map<String, dynamic>> _newsFeed = [];
  List<Map<String, dynamic>> _directory = [];
  bool _isAdmin = false;
  bool _isSocialLoading = true;
  final _api = ApiService();

  @override
  void initState() { super.initState(); _detectUserRole(); }

  Future<void> _detectUserRole() async {
    try {
      final p = await _api.fetchMyProfile();
      final role = (p['role'] ?? '').toString();
      final roleL = role.toLowerCase();
      setState(() { _currentUserProfile = p; _userRole = role.isEmpty ? 'Customer' : role; });
      if (roleL == 'banker') { setState(() { _targetCollection = 'dsa_registrations'; _isRoleLoading = false; }); }
      else if (roleL == 'dsa') { setState(() { _targetCollection = 'banker_registrations'; _isRoleLoading = false; }); }
      else { setState(() { _targetCollection = 'admin_posts'; _isRoleLoading = false; }); }
      setState(() => _isAdmin = roleL == 'admin' || roleL == 'staff');
    } catch (e) {
      if (mounted) setState(() => _isRoleLoading = false);
    }
  }

  Future<void> _refreshSocial() async {
    if (_newsFeed.isEmpty) setState(() => _isSocialLoading = true);
    try {
      final results = await Future.wait([
        _api.fetchStatuses(),
        _api.fetchNewsFeed(),
      ]);
      if (mounted) setState(() { _statuses = results[0]; _newsFeed = results[1]; _isSocialLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }
  Future<void> _refreshDirectory() async {
    try {
      if (_targetCollection == 'admin_posts') {
        final posts = await _api.fetchAdminPosts();
        if (mounted) setState(() => _directory = posts);
      } else {
        final role = _targetCollection == 'dsa_registrations' ? 'dsa' : 'banker';
        final list = await _api.fetchDirectory(role);
        if (mounted) setState(() => _directory = list);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text(_selectedIndex == 0 || _selectedIndex == 2 ? 'Dhankund' : _selectedIndex == 1 ? 'My Referrals' : _selectedIndex == 3 ? 'My Earnings' : 'My Profile', style: const TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -0.5)),
        actions: [
          if (_selectedIndex != 4) ...[
            IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black87), onPressed: () {}),
            InkWell(onTap: () => setState(() => _selectedIndex = 4), borderRadius: BorderRadius.circular(18), child: CircleAvatar(radius: 18, backgroundColor: const Color(0xFF4A3AFF), backgroundImage: _currentUserProfile['profilePictureUrl'] != null ? NetworkImage(_currentUserProfile['profilePictureUrl']) : null, child: _currentUserProfile['profilePictureUrl'] == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null)),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const MyLoanDashboardScreen(),
          const ReferralDashboardScreen(),
          DefaultTabController(length: 2, child: Column(children: [
            _buildStatusBar(),
            Container(color: Colors.white, child: TabBar(indicatorColor: const Color(0xFF4A3AFF), labelColor: const Color(0xFF4A3AFF), unselectedLabelColor: Colors.grey, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), tabs: [const Tab(text: 'Social Wall'), Tab(text: _userRole.toLowerCase() == 'banker' ? 'DSAs' : _userRole.toLowerCase() == 'dsa' ? 'Bankers' : 'Announcements')])),
            Expanded(child: TabBarView(children: [_buildSocialWallFeedTab(), _buildDirectoryTab()])),
          ])),
          const MyEarningsScreen(),
          const MyProfileScreen(),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 ? null : (_isAdmin && _selectedIndex == 2
        ? FloatingActionButton.extended(onPressed: () => _showAddAdminPostDialog(context), backgroundColor: const Color(0xFF4A3AFF), icon: const Icon(Icons.campaign, color: Colors.white), label: const Text('Add Announcement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        : FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferFriendFormScreen())), backgroundColor: const Color(0xFF4A3AFF), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Refer a Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex, onTap: (i) { setState(() => _selectedIndex = i); if (i == 2) { _refreshSocial(); _refreshDirectory(); } },
        selectedItemColor: const Color(0xFF4A3AFF), unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed,
        items: const [BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'My Loan'), BottomNavigationBarItem(icon: Icon(Icons.share_location), label: 'My Referral'), BottomNavigationBarItem(icon: Icon(Icons.feed_outlined), label: 'News Feed'), BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'My Earnings'), BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'My Profile')],
      ),
    );
  }

  Widget _buildStatusBar() {
    final myUid = ApiClient.currentUserId ?? '';
    final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var s in _statuses) {
      final ts = s['timestamp'];
      DateTime? dt;
      if (ts != null) { try { dt = DateTime.parse(ts.toString()); } catch (_) {} }
      if (dt != null && dt.isBefore(oneDayAgo)) continue;
      final uid = (s['uid'] ?? '').toString();
      grouped.putIfAbsent(uid, () => []).add(s);
    }
    final myStatuses = grouped[myUid] ?? [];
    final hasMyStatus = myStatuses.isNotEmpty;
    final otherUids = grouped.keys.where((u) => u != myUid).toList();
    return Container(height: 115, padding: const EdgeInsets.symmetric(vertical: 12), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF), width: 1))), child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      StatusCircle(label: 'My Status', hasActiveStatus: hasMyStatus, isMe: true, profilePictureUrl: _currentUserProfile['profilePictureUrl'], onTap: () {
        if (hasMyStatus) {
          showGeneralDialog(context: context, barrierDismissible: true, barrierLabel: 'Status', barrierColor: Colors.black, pageBuilder: (context, _, __) => StatusViewerDialog(userName: (_currentUserProfile['name'] ?? 'Me').toString(), userRole: (_currentUserProfile['role'] ?? 'User').toString(), userCompany: (_currentUserProfile['company'] ?? '').toString(), statuses: myStatuses, currentUid: myUid));
        } else {
          showDialog(context: context, builder: (context) => AddStatusDialog(userProfile: _currentUserProfile, uid: myUid, onStatusAdded: _refreshSocial));
        }
      }),
      ...otherUids.map((uid) {
        final list = grouped[uid]!;
        final first = list.first;
        return StatusCircle(label: (first['name'] ?? 'User').toString(), hasActiveStatus: true, isMe: false, profilePictureUrl: first['profilePictureUrl'], onTap: () => showGeneralDialog(context: context, barrierDismissible: true, barrierLabel: 'Status', barrierColor: Colors.black, pageBuilder: (context, _, __) => StatusViewerDialog(userName: (first['name'] ?? 'User').toString(), userRole: (first['role'] ?? 'Partner').toString(), userCompany: (first['company'] ?? '').toString(), statuses: list, currentUid: myUid)));
      }),
    ]));
  }

  Widget _buildDirectoryTab() {
    if (_isRoleLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(color: const Color(0xFF4A3AFF), onRefresh: _refreshDirectory, child: _directory.isEmpty
      ? ListView(children: [const SizedBox(height: 200), Center(child: Column(children: [Icon(_targetCollection == 'admin_posts' ? Icons.campaign_outlined : Icons.search_off, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), Text(_targetCollection == 'admin_posts' ? 'No announcements from Admin yet' : 'No ${_userRole.toLowerCase() == 'banker' ? 'DSAs' : 'Bankers'} found yet', style: TextStyle(color: Colors.grey[500], fontSize: 16))]))])
      : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), itemCount: _directory.length, itemBuilder: (context, index) {
          final data = _directory[index];
          if (_targetCollection == 'admin_posts') return _buildAdminPostCard(context, data, (data['id'] ?? '').toString());
          return UserProfileCard(data: data, role: _userRole.toLowerCase() == 'banker' ? 'DSA' : 'Banker');
        }));
  }

  Widget _buildAdminPostCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final title = data['title'] ?? 'Announcement';
    final content = data['content'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final authorName = data['name'] ?? 'Admin';
    final timestamp = data['timestamp'];
    String dateStr = 'Just now';
    if (timestamp != null) { try { final dt = DateTime.parse(timestamp.toString()); dateStr = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) {} }
    return Container(margin: const EdgeInsets.only(bottom: 8), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF), width: 1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
        const CircleAvatar(radius: 20, backgroundColor: Color(0xFF4A3AFF), child: Icon(Icons.campaign, color: Colors.white, size: 20)),
        const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(authorName.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text('Admin Announcement • $dateStr', style: const TextStyle(color: Colors.grey, fontSize: 12))])),
        if (_isAdmin) IconButton(icon: const Icon(Icons.more_horiz, color: Colors.grey), onPressed: () async { await _api.deleteAdminPost(docId); _refreshDirectory(); }),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1D1F))), const SizedBox(height: 4), ExpandableText(text: content.toString())])),
      const SizedBox(height: 8),
      if (imageUrl != null && imageUrl.isNotEmpty) AspectRatio(aspectRatio: 1.0, child: CachedNetworkImage(imageUrl: imageUrl, width: double.infinity, fit: BoxFit.cover, memCacheWidth: 800, placeholder: (context, url) => Shimmer.fromColors(baseColor: Colors.grey[200]!, highlightColor: Colors.grey[100]!, child: Container(color: Colors.white)), errorWidget: (context, url, error) => const SizedBox.shrink())),
      const SizedBox(height: 8),
    ]));
  }

  Widget _buildSocialWallFeedTab() {
    if (_newsFeed.isEmpty && _statuses.isEmpty && !_isSocialLoading) { _refreshSocial(); }
    final myUid = ApiClient.currentUserId ?? '';
    return RefreshIndicator(color: const Color(0xFF4A3AFF), onRefresh: _refreshSocial, child: _isSocialLoading
      ? ListView.builder(padding: const EdgeInsets.symmetric(vertical: 8), itemCount: 4, itemBuilder: (context, index) {
          if (index == 0) return _buildCreatePostHeader();
          return Shimmer.fromColors(baseColor: Colors.grey[200]!, highlightColor: Colors.grey[100]!, child: Container(margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16), height: 350, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))));
        })
      : _newsFeed.isEmpty
      ? ListView(children: [_buildCreatePostHeader(), const SizedBox(height: 100), Center(child: Column(children: [Icon(Icons.feed_outlined, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), const Text('No posts on the Social Wall yet. Be the first to share!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16))]))])
      : ListView.builder(padding: const EdgeInsets.symmetric(vertical: 8), itemCount: _newsFeed.length + 1, itemBuilder: (context, index) {
          if (index == 0) return _buildCreatePostHeader();
          final postIndex = index - 1;
          return _buildSocialPostCard(context, _newsFeed[postIndex], (_newsFeed[postIndex]['id'] ?? '').toString(), myUid);
        })
    );
  }

  Widget _buildCreatePostHeader() {
    final name = _currentUserProfile['name'] ?? 'User';
    final profilePic = _currentUserProfile['profilePictureUrl'];
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF), width: 1))), child: Column(children: [
      Row(children: [
        InkWell(onTap: () => setState(() => _selectedIndex = 4), borderRadius: BorderRadius.circular(22), child: CircleAvatar(radius: 22, backgroundColor: const Color(0xFF4A3AFF).withOpacity(0.1), backgroundImage: profilePic != null ? CachedNetworkImageProvider(profilePic) : null, child: profilePic == null ? const Icon(Icons.person, color: Color(0xFF4A3AFF)) : null)),
        const SizedBox(width: 12), Expanded(child: InkWell(onTap: () => _showCreatePostDialog(context, startWithImage: false), borderRadius: BorderRadius.circular(25), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFF3F5F9), borderRadius: BorderRadius.circular(25)), child: Text("What's on your mind, $name?", style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500))))),
      ]),
      const SizedBox(height: 16), const Divider(height: 1, thickness: 0.5), const SizedBox(height: 12),
      InkWell(onTap: () => _showCreatePostDialog(context, startWithImage: true), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.photo_library, color: Colors.green, size: 22), const SizedBox(width: 8), Text('Share a Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 14))])),
    ]));
  }

  void _showCreatePostDialog(BuildContext context, {bool startWithImage = false}) {
    showDialog(context: context, builder: (context) => CreatePostDialog(userProfile: _currentUserProfile, userRole: _userRole, startWithImage: startWithImage, onPosted: _refreshSocial));
  }

  void _showAddAdminPostDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => AddAdminPostDialog(onPosted: _refreshDirectory));
  }

  Widget _buildSocialPostCard(BuildContext context, Map<String, dynamic> data, String docId, String myUid) {
    final authorName = data['name'] ?? 'User';
    final authorRole = data['role'] ?? 'Partner';
    final authorCompany = data['company'] ?? 'Independent';
    final profilePic = data['profilePictureUrl'];
    final content = data['content'] ?? '';
    final imageUrl = data['imageUrl'];
    final timestamp = data['timestamp'];
    final likes = List<String>.from((data['likes'] ?? []).map((e) => e.toString()));
    final authorMobile = (data['mobile'] ?? '').toString();
    final isLiked = likes.contains(myUid);
    final postUid = (data['uid'] ?? '').toString();
    return Container(margin: const EdgeInsets.only(bottom: 8), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF), width: 1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
        InkWell(onTap: () { if (postUid == myUid) setState(() => _selectedIndex = 4); }, borderRadius: BorderRadius.circular(20), child: CircleAvatar(radius: 20, backgroundColor: const Color(0xFF4A3AFF).withOpacity(0.1), backgroundImage: profilePic != null ? CachedNetworkImageProvider(profilePic) : null, child: profilePic == null ? const Icon(Icons.person, color: Color(0xFF4A3AFF), size: 20) : null)),
        const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(authorName.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text('$authorRole • $authorCompany • ${_formatPostTime(timestamp)}', style: const TextStyle(color: Colors.grey, fontSize: 12))])),
        if (postUid == myUid || _isAdmin) IconButton(icon: const Icon(Icons.more_horiz, color: Colors.grey), onPressed: () async { final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Post'), content: const Text('Are you sure you want to delete this post?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))])); if (confirm == true) { setState(() => _newsFeed.removeWhere((item) => (item['id'] ?? '').toString() == docId)); _api.deleteNewsFeedPost(docId).catchError((_) => _refreshSocial()); } }),
      ])),
      if (content.toString().isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: ExpandableText(text: content.toString())),
      const SizedBox(height: 8),
      if (imageUrl != null && imageUrl.toString().isNotEmpty) GestureDetector(onTap: () => _viewFullPostImage(context, imageUrl.toString()), child: AspectRatio(aspectRatio: 1.0, child: CachedNetworkImage(imageUrl: imageUrl.toString(), width: double.infinity, fit: BoxFit.cover, memCacheWidth: 800, placeholder: (context, url) => Shimmer.fromColors(baseColor: Colors.grey[200]!, highlightColor: Colors.grey[100]!, child: Container(color: Colors.white)), errorWidget: (context, url, error) => const SizedBox.shrink()))),
      const SizedBox(height: 8),
      if (likes.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Row(children: [const Icon(Icons.thumb_up, color: Color(0xFF4A3AFF), size: 14), const SizedBox(width: 6), Text('${likes.length}', style: TextStyle(color: Colors.grey[700], fontSize: 13))])),
      const Divider(height: 1, thickness: 0.5, color: Color(0xFFEFEFEF)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Expanded(child: InkWell(onTap: () {
          setState(() {
            final l = List<dynamic>.from(data['likes'] ?? []);
            if (isLiked) { l.remove(myUid); } else { l.add(myUid); }
            data['likes'] = l;
          });
          _api.toggleNewsFeedLike(docId).catchError((_) {
            setState(() {
              final l = List<dynamic>.from(data['likes'] ?? []);
              if (isLiked) { l.add(myUid); } else { l.remove(myUid); }
              data['likes'] = l;
            });
          });
        }, child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: isLiked ? const Color(0xFF4A3AFF) : Colors.grey[600], size: 20), const SizedBox(width: 8), Text('Like', style: TextStyle(color: isLiked ? const Color(0xFF4A3AFF) : Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 14))])))),
        if (authorMobile.isNotEmpty && postUid != myUid) Expanded(child: InkWell(onTap: () => _contactAuthor(context, authorMobile, authorName.toString()), child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.chat_bubble_outline, color: Color(0xFF27AE60), size: 20), const SizedBox(width: 8), const Text('WhatsApp', style: TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.w600, fontSize: 14))])))),
      ])),
    ]));
  }

  void _contactAuthor(BuildContext context, String mobile, String name) async {
    String cleanNumber = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length == 10) cleanNumber = '91$cleanNumber';
    final text = Uri.encodeComponent("Hello $name, I saw your post on Dhankund Feed!");
    final Uri whatsappUri = Uri.parse("https://wa.me/$cleanNumber?text=$text");
    try { await launchUrl(whatsappUri, mode: LaunchMode.externalApplication); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp. Please try again.'))); }
  }

  void _viewFullPostImage(BuildContext context, String imageUrl) {
    showDialog(context: context, builder: (context) => Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(12), child: InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(imageUrl, fit: BoxFit.contain)))));
  }

  String _formatPostTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime dateTime;
    try { dateTime = DateTime.parse(timestamp.toString()); } catch (_) { return 'Just now'; }
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class AddAdminPostDialog extends StatefulWidget {
  final VoidCallback? onPosted;
  const AddAdminPostDialog({super.key, this.onPosted});
  @override
  State<AddAdminPostDialog> createState() => _AddAdminPostDialogState();
}

class _AddAdminPostDialogState extends State<AddAdminPostDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  final _api = ApiService();

  @override
  void dispose() { _titleController.dispose(); _contentController.dispose(); super.dispose(); }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.single.bytes != null) {
        setState(() => _isUploadingImage = true);
        final file = result.files.single;
        final extension = file.extension ?? 'jpg';
        final url = await CloudflareR2Service().uploadFile(bytes: file.bytes!, folderPath: 'admin_posts_images', extension: extension);
        setState(() { _uploadedImageUrl = url; _isUploadingImage = false; });
      }
    } catch (e) { setState(() => _isUploadingImage = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image. ' + friendlyErrorMessage(e)))); }
  }

  Future<void> _savePost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _api.createAdminPost(title: title, content: content, imageUrl: _uploadedImageUrl);
      if (mounted) { Navigator.pop(context); widget.onPosted?.call(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement posted successfully!'))); }
    } catch (e) { if (mounted) { setState(() => _isSaving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save announcement. ' + friendlyErrorMessage(e)))); } }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('New Admin Announcement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF))),
      const SizedBox(height: 16),
      TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _contentController, maxLines: 4, decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      if (_isUploadingImage) const Center(child: CircularProgressIndicator())
      else if (_uploadedImageUrl != null) Column(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_uploadedImageUrl!, height: 100, fit: BoxFit.cover)), TextButton(onPressed: _pickAndUploadImage, child: const Text('Change Image'))])
      else OutlinedButton.icon(onPressed: _pickAndUploadImage, icon: const Icon(Icons.add_a_photo), label: const Text('Add Banner Image (Optional)')),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), const SizedBox(width: 12), ElevatedButton(onPressed: _isSaving ? null : _savePost, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3AFF)), child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
    ]))));
  }
}

class CreatePostDialog extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final String userRole;
  final bool startWithImage;
  final VoidCallback? onPosted;
  const CreatePostDialog({super.key, required this.userProfile, required this.userRole, required this.startWithImage, this.onPosted});
  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _contentController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isSaving = false;
  final _api = ApiService();

  @override
  void initState() { super.initState(); if (widget.startWithImage) { WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage()); } }
  @override
  void dispose() { _contentController.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    try { final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true); if (result != null) setState(() => _selectedFile = result.files.single); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image. ' + friendlyErrorMessage(e)))); }
  }

  Future<void> _submitPost() async {
    final text = _contentController.text.trim();
    if (text.isEmpty && _selectedFile == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter some text or add an image'))); return; }
    setState(() => _isSaving = true);
    String? imageUrl;
    try {
      if (_selectedFile != null) {
        final extension = _selectedFile!.extension ?? 'jpg';
        Uint8List fileBytes;
        if (kIsWeb || _selectedFile!.bytes != null) { fileBytes = _selectedFile!.bytes!; } else { fileBytes = await io.File(_selectedFile!.path!).readAsBytes(); }
        imageUrl = await CloudflareR2Service().uploadFile(bytes: fileBytes, folderPath: 'news_feed_images', extension: extension);
      }
      await _api.createNewsFeedPost(content: text, imageUrl: imageUrl);
      if (mounted) { Navigator.pop(context); widget.onPosted?.call(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post published successfully!'))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish post. ' + friendlyErrorMessage(e)))); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userProfile['name'] ?? 'User';
    final profilePic = widget.userProfile['profilePictureUrl'];
    return Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Container(padding: const EdgeInsets.all(20), width: MediaQuery.of(context).size.width * 0.9, constraints: const BoxConstraints(maxHeight: 520), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Create Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF))), IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))]),
      const Divider(),
      Row(children: [CircleAvatar(radius: 20, backgroundColor: const Color(0xFF4A3AFF).withOpacity(0.1), backgroundImage: profilePic != null ? NetworkImage(profilePic) : null, child: profilePic == null ? const Icon(Icons.person, color: Color(0xFF4A3AFF)) : null), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold)), Text(widget.userRole, style: TextStyle(color: Colors.grey[600], fontSize: 12))])]),
      const SizedBox(height: 16),
      TextField(controller: _contentController, maxLines: 4, decoration: const InputDecoration(hintText: "What's on your mind?", border: InputBorder.none)),
      const SizedBox(height: 16),
      if (_selectedFile != null) Column(children: [Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: kIsWeb ? Image.memory(_selectedFile!.bytes!, height: 150, width: double.infinity, fit: BoxFit.cover) : Image.file(io.File(_selectedFile!.path!), height: 150, width: double.infinity, fit: BoxFit.cover)), Positioned(right: 8, top: 8, child: GestureDetector(onTap: () => setState(() => _selectedFile = null), child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, color: Colors.white, size: 18))))]), const SizedBox(height: 8)]),
      OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_library, color: Colors.green), label: const Text('Add Photo'), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), foregroundColor: Colors.black87)),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _isSaving ? null : _submitPost, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3AFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(double.infinity, 48)), child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
    ]))));
  }
}

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  const ExpandableText({super.key, required this.text, this.maxLines = 3});
  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, size) {
      final span = TextSpan(text: widget.text, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4));
      final tp = TextPainter(text: span, maxLines: widget.maxLines, textDirection: TextDirection.ltr);
      tp.layout(maxWidth: size.maxWidth);
      if (tp.didExceedMaxLines) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.text, maxLines: _isExpanded ? null : widget.maxLines, overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
          InkWell(onTap: () => setState(() => _isExpanded = !_isExpanded), child: Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text(_isExpanded ? 'Show less' : 'More', style: const TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold, fontSize: 14))))
        ]);
      } else {
        return Text(widget.text, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4));
      }
    });
  }
}
