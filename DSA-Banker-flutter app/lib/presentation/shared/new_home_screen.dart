import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_flutter_app/services/aws_s3_service.dart';
import 'package:my_flutter_app/presentation/shared/my_profile_screen.dart';
import 'package:my_flutter_app/presentation/b2b_network/profession_selection_screen.dart';
import 'package:my_flutter_app/presentation/partner_app/refer_friend_form_screen.dart';
import 'package:my_flutter_app/presentation/partner_app/referral_dashboard_screen.dart';
import 'package:my_flutter_app/presentation/shared/user_profile_card.dart';
import 'package:my_flutter_app/presentation/b2b_network/status_stories_widget.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'package:url_launcher/url_launcher.dart';
import 'package:my_flutter_app/presentation/shared/my_loan_dashboard_screen.dart';
import 'package:my_flutter_app/presentation/shared/my_earnings_screen.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  int _selectedIndex = 0;
  String _userRole = 'Discover'; // Default
  String _targetCollection = 'dsa_registrations'; // Default target
  bool _isRoleLoading = true;
  Map<String, dynamic> _currentUserProfile = {};

  @override
  void initState() {
    super.initState();
    _detectUserRole();
  }

  Future<void> _detectUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch user details from 'users' collection
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists && mounted) {
      final data = userDoc.data() ?? {};
      setState(() {
        _currentUserProfile = data;
        _userRole = data['role'] ?? 'Discover';
      });

      if (_userRole == 'Banker') {
        setState(() {
          _targetCollection = 'dsa_registrations';
          _isRoleLoading = false;
        });
        return;
      } else if (_userRole == 'DSA') {
        setState(() {
          _targetCollection = 'banker_registrations';
          _isRoleLoading = false;
        });
        return;
      } else if (_userRole == 'Builder' || _userRole == 'Connector' || _userRole == 'admin') {
        setState(() {
          _targetCollection = 'admin_posts';
          _isRoleLoading = false;
        });
        return;
      }
    }

    // Check if user is a Banker in registrations
    final bankerDoc = await FirebaseFirestore.instance
        .collection('banker_registrations')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (bankerDoc.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userRole = 'Banker';
          _targetCollection = 'dsa_registrations';
          _isRoleLoading = false;
        });
      }
      return;
    }

    // Check if user is a DSA in registrations
    final dsaDoc = await FirebaseFirestore.instance
        .collection('dsa_registrations')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (dsaDoc.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userRole = 'DSA';
          _targetCollection = 'banker_registrations';
          _isRoleLoading = false;
        });
      }
      return;
    }

    // Check if user is a Partner in registrations
    final partnerDoc = await FirebaseFirestore.instance
        .collection('partner_registrations')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (partnerDoc.docs.isNotEmpty) {
      final pData = partnerDoc.docs.first.data();
      final pRole = pData['role'] ?? 'Builder';
      if (mounted) {
        setState(() {
          _userRole = pRole;
          _targetCollection = 'admin_posts';
          _isRoleLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isRoleLoading = false);
  }

  void _showAddAdminPostDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddAdminPostDialog(),
    );
  }

  Widget _buildAdminPostCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final title = data['title'] ?? 'Announcement';
    final content = data['content'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final authorName = data['name'] ?? 'Admin';
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null
        ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
        : 'Just now';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF4A3AFF),
                  child: Icon(Icons.campaign, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Admin Announcement â€¢ $dateStr',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_userRole == 'admin')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('admin_posts').doc(docId).delete();
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF4A3AFF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (imageUrl != null && imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: _selectedIndex == 0 ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _selectedIndex == 1 
              ? 'My Referrals' 
              : _selectedIndex == 4 
                  ? 'My Profile' 
                  : 'Dhankund Feed',
          style: const TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedIndex != 4) ...[
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black87),
              onPressed: () {},
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF4A3AFF),
              backgroundImage: _currentUserProfile['profilePictureUrl'] != null
                  ? NetworkImage(_currentUserProfile['profilePictureUrl'])
                  : null,
              child: _currentUserProfile['profilePictureUrl'] == null
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: _selectedIndex == 0
          ? const MyLoanDashboardScreen()
          : _selectedIndex == 1 
              ? const ReferralDashboardScreen() 
              : _selectedIndex == 4
                  ? const MyProfileScreen()
                  : _selectedIndex == 3
                      ? const MyEarningsScreen()
                      : DefaultTabController(
                          length: 2,
                          child: Column(
                        children: [
                          // 1. Status Bar (Horizontal Circles)
                          _buildStatusBar(),
                          
                          // Tab Bar for Social Feed vs Directory/Announcements
                          Container(
                            color: Colors.white,
                            child: TabBar(
                              indicatorColor: const Color(0xFF4A3AFF),
                              labelColor: const Color(0xFF4A3AFF),
                              unselectedLabelColor: Colors.grey,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              tabs: [
                                const Tab(text: 'Social Wall'),
                                Tab(
                                  text: _userRole == 'Banker' 
                                      ? 'DSAs' 
                                      : _userRole == 'DSA' 
                                          ? 'Bankers' 
                                          : 'Announcements',
                                ),
                              ],
                            ),
                          ),
                          
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildSocialWallFeedTab(),
                                _buildDirectoryTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
      
      // 3. Floating Action Button
      floatingActionButton: _selectedIndex == 0 ? null : (_userRole == 'admin' && _selectedIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => _showAddAdminPostDialog(context),
              backgroundColor: const Color(0xFF4A3AFF),
              icon: const Icon(Icons.campaign, color: Colors.white),
              label: const Text('Add Announcement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReferFriendFormScreen()),
                );
              },
              backgroundColor: const Color(0xFF4A3AFF),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Refer a Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
      
      // 4. Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF4A3AFF),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'My Loan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share_location),
            label: 'My Referral',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed_outlined),
            label: 'News Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'My Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'My Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('statuses')
          .where('timestamp', isGreaterThan: oneDayAgo)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final Map<String, List<Map<String, dynamic>>> grouped = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final id = doc.id;
            final uid = data['uid'] as String?;
            if (uid != null) {
              data['id'] = id;
              grouped.putIfAbsent(uid, () => []).add(data);
            }
          }
        }

        for (var uid in grouped.keys) {
          grouped[uid]!.sort((a, b) {
            final aTime = a['timestamp'] as Timestamp?;
            final bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return aTime.compareTo(bTime);
          });
        }

        final myUid = currentUser.uid;
        final myStatuses = grouped[myUid] ?? [];
        final hasMyStatus = myStatuses.isNotEmpty;

        final otherUids = grouped.keys.where((uid) => uid != myUid).toList();
        otherUids.sort((a, b) {
          final aLast = grouped[a]!.last['timestamp'] as Timestamp?;
          final bLast = grouped[b]!.last['timestamp'] as Timestamp?;
          if (aLast == null || bLast == null) return 0;
          return bLast.compareTo(aLast);
        });

        return Container(
          height: 115,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF), width: 1)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              StatusCircle(
                label: 'My Status',
                hasActiveStatus: hasMyStatus,
                isMe: true,
                profilePictureUrl: _currentUserProfile['profilePictureUrl'],
                onTap: () {
                  if (hasMyStatus) {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: false,
                      pageBuilder: (context, _, __) {
                        return StatusViewerDialog(
                          userName: _currentUserProfile['name'] ?? 'Me',
                          userRole: _currentUserProfile['role'] ?? 'User',
                          userCompany: _currentUserProfile['company'] ?? '',
                          statuses: myStatuses,
                          currentUid: myUid,
                        );
                      },
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (context) => AddStatusDialog(
                        userProfile: _currentUserProfile,
                        uid: myUid,
                      ),
                    );
                  }
                },
              ),
              ...otherUids.map((uid) {
                final userStatusList = grouped[uid]!;
                final firstStatus = userStatusList.first;
                final userName = firstStatus['name'] ?? 'User';
                final userRole = firstStatus['role'] ?? 'Partner';
                final userCompany = firstStatus['company'] ?? '';
                final profilePic = firstStatus['profilePictureUrl'] as String?;

                return StatusCircle(
                  label: userName,
                  hasActiveStatus: true,
                  isMe: false,
                  profilePictureUrl: profilePic,
                  onTap: () {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: false,
                      pageBuilder: (context, _, __) {
                        return StatusViewerDialog(
                          userName: userName,
                          userRole: userRole,
                          userCompany: userCompany,
                          statuses: userStatusList,
                          currentUid: myUid,
                        );
                      },
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDirectoryTab() {
    return _isRoleLoading
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(_targetCollection)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Feed Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                final emptyText = _targetCollection == 'admin_posts'
                    ? "No announcements from Admin yet"
                    : "No ${_userRole == 'Banker' ? 'DSAs' : 'Bankers'} found yet";
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_targetCollection == 'admin_posts' ? Icons.campaign_outlined : Icons.search_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        emptyText,
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  if (_targetCollection == 'admin_posts') {
                    return _buildAdminPostCard(context, data, doc.id);
                  }
                  return UserProfileCard(
                    data: data,
                    role: _userRole == 'Banker' ? 'DSA' : 'Banker',
                  );
                },
              );
            },
          );
  }

  Widget _buildSocialWallFeedTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      children: [
        // 1. "Create Post" Card
        _buildCreatePostHeader(user),
        
        // 2. Feed Stream
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('news_feed')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading feed: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.feed_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No posts on the Social Wall yet.\nBe the first to share!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildSocialPostCard(context, data, doc.id, user.uid);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreatePostHeader(User user) {
    final name = _currentUserProfile['name'] ?? 'User';
    final profilePic = _currentUserProfile['profilePictureUrl'];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF4A3AFF).withOpacity(0.1),
                backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                child: profilePic == null 
                    ? const Icon(Icons.person, color: Color(0xFF4A3AFF)) 
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showCreatePostDialog(context, user.uid),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      "What's on your mind, $name?",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, thickness: 0.5),
          InkWell(
            onTap: () => _showCreatePostDialog(context, user.uid, startWithImage: true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_library, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context, String uid, {bool startWithImage = false}) {
    showDialog(
      context: context,
      builder: (context) => CreatePostDialog(
        userProfile: _currentUserProfile,
        userRole: _userRole,
        uid: uid,
        startWithImage: startWithImage,
      ),
    );
  }

  Widget _buildSocialPostCard(BuildContext context, Map<String, dynamic> data, String docId, String myUid) {
    final authorName = data['name'] ?? 'User';
    final authorRole = data['role'] ?? 'Partner';
    final authorCompany = data['company'] ?? 'Independent';
    final profilePic = data['profilePictureUrl'];
    final content = data['content'] ?? '';
    final imageUrl = data['imageUrl'];
    final timestamp = data['timestamp'];
    final likes = List<String>.from(data['likes'] ?? []);
    final authorMobile = data['mobile'] ?? '';
    final isLiked = likes.contains(myUid);
    final postUid = data['uid'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF4A3AFF).withOpacity(0.1),
                  backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                  child: profilePic == null 
                      ? const Icon(Icons.person, color: Color(0xFF4A3AFF)) 
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '$authorRole â€¢ $authorCompany â€¢ ${_formatPostTime(timestamp)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (postUid == myUid || _userRole == 'admin')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Post'),
                          content: const Text('Are you sure you want to delete this post?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true), 
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseFirestore.instance.collection('news_feed').doc(docId).delete();
                      }
                    },
                  ),
              ],
            ),
          ),
          
          // Post Content text
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                content,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
            ),
          
          const SizedBox(height: 8),

          // Post Attached Image
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _viewFullPostImage(context, imageUrl),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Like count summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (likes.isNotEmpty) ...[
                  const Icon(Icons.thumb_up, color: Color(0xFF4A3AFF), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${likes.length} ${likes.length == 1 ? 'like' : 'likes'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 16, thickness: 0.5),

          // Actions Buttons (Like & WhatsApp/Call)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Like Button
                InkWell(
                  onTap: () => _toggleLike(docId, myUid, isLiked),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color: isLiked ? const Color(0xFF4A3AFF) : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Like',
                          style: TextStyle(
                            color: isLiked ? const Color(0xFF4A3AFF) : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // WhatsApp/Call Contact Button
                if (authorMobile.isNotEmpty && postUid != myUid)
                  ElevatedButton.icon(
                    onPressed: () => _contactAuthor(context, authorMobile, authorName),
                    icon: const Icon(Icons.message, size: 16, color: Colors.white),
                    label: const Text('WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27AE60),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLike(String docId, String myUid, bool isLiked) {
    final docRef = FirebaseFirestore.instance.collection('news_feed').doc(docId);
    if (isLiked) {
      docRef.update({
        'likes': FieldValue.arrayRemove([myUid])
      });
    } else {
      docRef.update({
        'likes': FieldValue.arrayUnion([myUid])
      });
    }
  }

  void _contactAuthor(BuildContext context, String mobile, String name) async {
    String cleanNumber = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }
    final text = Uri.encodeComponent("Hello $name, I saw your post on Dhankund Feed!");
    final Uri whatsappUri = Uri.parse("https://wa.me/$cleanNumber?text=$text");
    try {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp: $e')),
      );
    }
  }

  void _viewFullPostImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  String _formatPostTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Just now';
    }
    
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class AddAdminPostDialog extends StatefulWidget {
  const AddAdminPostDialog({super.key});

  @override
  State<AddAdminPostDialog> createState() => _AddAdminPostDialogState();
}

class _AddAdminPostDialogState extends State<AddAdminPostDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.bytes != null) {
        setState(() => _isUploadingImage = true);
        final file = result.files.single;
        final extension = file.extension ?? 'jpg';
        final url = await AwsS3Service.uploadFile(
          bytes: file.bytes!,
          folderPath: 'admin_posts_images',
          extension: extension,
        );
        setState(() {
          _uploadedImageUrl = url;
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    }
  }

  Future<void> _savePost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('admin_posts').add({
        'title': title,
        'content': content,
        'imageUrl': _uploadedImageUrl,
        'name': 'Admin',
        'uid': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save announcement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New Admin Announcement',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_isUploadingImage)
                const Center(child: CircularProgressIndicator())
              else if (_uploadedImageUrl != null)
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(_uploadedImageUrl!, height: 100, fit: BoxFit.cover),
                    ),
                    TextButton(onPressed: _pickAndUploadImage, child: const Text('Change Image')),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickAndUploadImage,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add Banner Image (Optional)'),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _savePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A3AFF),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreatePostDialog extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final String userRole;
  final String uid;
  final bool startWithImage;

  const CreatePostDialog({
    super.key,
    required this.userProfile,
    required this.userRole,
    required this.uid,
    required this.startWithImage,
  });

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _contentController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.startWithImage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage();
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null) {
        setState(() {
          _selectedFile = result.files.single;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    final text = _contentController.text.trim();
    if (text.isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text or add an image')),
      );
      return;
    }

    setState(() => _isSaving = true);
    String? imageUrl;

    try {
      if (_selectedFile != null) {
        final extension = _selectedFile!.extension ?? 'jpg';
        
        Uint8List fileBytes;
        if (kIsWeb || _selectedFile!.bytes != null) {
          fileBytes = _selectedFile!.bytes!;
        } else {
          fileBytes = await io.File(_selectedFile!.path!).readAsBytes();
        }

        imageUrl = await AwsS3Service.uploadFile(
          bytes: fileBytes,
          folderPath: 'news_feed_images',
          extension: extension,
        );
      }

      await FirebaseFirestore.instance.collection('news_feed').add({
        'uid': widget.uid,
        'name': widget.userProfile['name'] ?? 'User',
        'role': widget.userRole,
        'company': widget.userProfile['company'] ?? 'Independent',
        'profilePictureUrl': widget.userProfile['profilePictureUrl'],
        'mobile': widget.userProfile['mobile'] ?? '',
        'content': text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userProfile['name'] ?? 'User';
    final profilePic = widget.userProfile['profilePictureUrl'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A3AFF),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF4A3AFF).withOpacity(0.1),
                    backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                    child: profilePic == null 
                        ? const Icon(Icons.person, color: Color(0xFF4A3AFF)) 
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(widget.userRole, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedFile != null)
                Column(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb
                              ? Image.memory(_selectedFile!.bytes!, height: 150, width: double.infinity, fit: BoxFit.cover)
                              : Image.file(io.File(_selectedFile!.path!), height: 150, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedFile = null),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library, color: Colors.green),
                label: const Text('Add Photo'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  foregroundColor: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3AFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

