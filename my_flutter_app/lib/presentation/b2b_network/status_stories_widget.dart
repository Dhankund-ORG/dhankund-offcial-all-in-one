import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

const List<LinearGradient> statusGradients = [
  LinearGradient(
    colors: [Color(0xFF4A3AFF), Color(0xFF6C5DD3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  LinearGradient(
    colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  LinearGradient(
    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  LinearGradient(
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
];

class StatusCircle extends StatelessWidget {
  final String label;
  final bool hasActiveStatus;
  final bool isMe;
  final String? profilePictureUrl;
  final VoidCallback onTap;

  const StatusCircle({
    super.key,
    required this.label,
    required this.hasActiveStatus,
    required this.isMe,
    this.profilePictureUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasActiveStatus
                        ? const LinearGradient(
                            colors: [Color(0xFFE1306C), Color(0xFFC13584), Color(0xFFF77737)],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          )
                        : null,
                    border: !hasActiveStatus
                        ? Border.all(color: Colors.grey.shade300, width: 1.5)
                        : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF4A3AFF).withOpacity(0.1),
                      backgroundImage: profilePictureUrl != null
                          ? NetworkImage(profilePictureUrl!)
                          : null,
                      child: profilePictureUrl == null
                          ? Icon(
                              isMe ? Icons.person : Icons.person_outline,
                              color: const Color(0xFF4A3AFF),
                              size: 26,
                            )
                          : null,
                    ),
                  ),
                ),
                if (isMe && !hasActiveStatus)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A3AFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddStatusDialog extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final String uid;

  const AddStatusDialog({
    super.key,
    required this.userProfile,
    required this.uid,
  });

  @override
  State<AddStatusDialog> createState() => _AddStatusDialogState();
}

class _AddStatusDialogState extends State<AddStatusDialog> {
  final TextEditingController _textController = TextEditingController();
  int _selectedGradientIndex = 0;
  bool _isLoading = false;
  String? _mediaUrl;
  String _mediaType = 'text'; // 'text' | 'image' | 'video'
  bool _isUploadingMedia = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadMedia(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type == 'image' ? FileType.image : FileType.video,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _isUploadingMedia = true;
          _mediaType = type;
        });

        final file = result.files.single;
        final extension = file.extension ?? (type == 'image' ? 'jpg' : 'mp4');
        final ref = FirebaseStorage.instance
            .ref()
            .child('status_media/${widget.uid}_${DateTime.now().millisecondsSinceEpoch}.$extension');

        final uploadTask = ref.putData(
          file.bytes!,
          SettableMetadata(contentType: type == 'image' ? 'image/$extension' : 'video/$extension'),
        );

        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();

        setState(() {
          _mediaUrl = url;
          _isUploadingMedia = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
          _mediaType = 'text';
          _mediaUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload media: $e')),
        );
      }
    }
  }

  Future<void> _postStatus() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _mediaUrl == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('statuses').add({
        'uid': widget.uid,
        'name': widget.userProfile['name'] ?? 'Anonymous',
        'role': widget.userProfile['role'] ?? 'User',
        'company': widget.userProfile['company'] ?? '',
        'mobile': widget.userProfile['mobile'] ?? '',
        'text': text,
        'gradientIndex': _selectedGradientIndex,
        'mediaUrl': _mediaUrl,
        'mediaType': _mediaType,
        'profilePictureUrl': widget.userProfile['profilePictureUrl'],
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Post a Status',
                  style: TextStyle(
                    fontSize: 20,
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
            const SizedBox(height: 12),
            // Preview box
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  gradient: _mediaType == 'text' ? statusGradients[_selectedGradientIndex] : null,
                  color: _mediaType != 'text' ? Colors.black87 : null,
                  image: _mediaType == 'image' && _mediaUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_mediaUrl!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.4),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: _isUploadingMedia
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_mediaType == 'video' && _mediaUrl != null)
                            const Icon(Icons.video_library, size: 48, color: Colors.white70),
                          TextField(
                            controller: _textController,
                            maxLines: 3,
                            maxLength: 120,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: _mediaType == 'text'
                                  ? "What rates or offers today?"
                                  : "Add a caption...",
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                              counterText: "",
                            ),
                            onChanged: (text) => setState(() {}),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_textController.text.length}/120 characters',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Media buttons row
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickAndUploadMedia('image'),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mediaType == 'image' ? const Color(0xFF4A3AFF) : Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickAndUploadMedia('video'),
                  icon: const Icon(Icons.video_collection_outlined),
                  label: const Text('Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mediaType == 'video' ? const Color(0xFF4A3AFF) : Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_mediaType != 'text') ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _mediaType = 'text';
                        _mediaUrl = null;
                      });
                    },
                  ),
                ],
              ],
            ),
            if (_mediaType == 'text') ...[
              const SizedBox(height: 8),
              const Text(
                'Select Theme Background',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(statusGradients.length, (index) {
                  final isSelected = _selectedGradientIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGradientIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: statusGradients[index],
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: const Color(0xFF4A3AFF), width: 3)
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading || _isUploadingMedia || (_textController.text.trim().isEmpty && _mediaUrl == null)
                  ? null
                  : _postStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A3AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Share status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoryProgressIndicators extends StatefulWidget {
  final int itemCount;
  final int currentIndex;
  final bool isPaused;
  final VoidCallback onCompleted;

  const StoryProgressIndicators({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    required this.isPaused,
    required this.onCompleted,
  });

  @override
  State<StoryProgressIndicators> createState() => _StoryProgressIndicatorsState();
}

class _StoryProgressIndicatorsState extends State<StoryProgressIndicators> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });

    _updatePlayState();
  }

  @override
  void didUpdateWidget(covariant StoryProgressIndicators oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animationController.reset();
      _animationController.forward();
    }
    _updatePlayState();
  }

  void _updatePlayState() {
    if (widget.isPaused) {
      _animationController.stop();
    } else {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        children: List.generate(widget.itemCount, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: index < widget.currentIndex
                  ? const LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 3,
                    )
                  : index > widget.currentIndex
                      ? const LinearProgressIndicator(
                          value: 0.0,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 3,
                        )
                      : AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _animationController.value,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 3,
                            );
                          },
                        ),
            ),
          );
        }),
      ),
    );
  }
}

class StatusViewerDialog extends StatefulWidget {
  final String userName;
  final String userRole;
  final String userCompany;
  final List<Map<String, dynamic>> statuses;
  final String currentUid;

  const StatusViewerDialog({
    super.key,
    required this.userName,
    required this.userRole,
    required this.userCompany,
    required this.statuses,
    required this.currentUid,
  });

  @override
  State<StatusViewerDialog> createState() => _StatusViewerDialogState();
}

class _StatusViewerDialogState extends State<StatusViewerDialog> {
  int _currentIndex = 0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
  }

  void _onStoryCompleted() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPaused = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    setState(() {
      _isPaused = false;
      if (dx < width * 0.3) {
        if (_currentIndex > 0) {
          _currentIndex--;
        }
      } else {
        if (_currentIndex < widget.statuses.length - 1) {
          _currentIndex++;
        } else {
          Navigator.pop(context);
        }
      }
    });
  }

  void _onLongPress() {
    setState(() {
      _isPaused = true;
    });
  }

  void _onLongPressEnd() {
    setState(() {
      _isPaused = false;
    });
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }
    
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Future<void> _deleteStatus(String statusId) async {
    try {
      await FirebaseFirestore.instance.collection('statuses').doc(statusId).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.statuses[_currentIndex];
    final text = currentStatus['text'] ?? '';
    final mediaUrl = currentStatus['mediaUrl'] as String?;
    final mediaType = currentStatus['mediaType'] ?? 'text';
    final gradientIdx = currentStatus['gradientIndex'] ?? 0;
    final timestamp = currentStatus['timestamp'];
    final statusDocId = currentStatus['id'] as String?;
    final isOwnStatus = currentStatus['uid'] == widget.currentUid;
    final mobile = currentStatus['mobile'] ?? '';

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onLongPress: _onLongPress,
        onLongPressEnd: (details) => _onLongPressEnd(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: mediaType == 'text'
                ? statusGradients[gradientIdx % statusGradients.length]
                : null,
            color: mediaType != 'text' ? Colors.black : null,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top Progress Indicators
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: StoryProgressIndicators(
                    itemCount: widget.statuses.length,
                    currentIndex: _currentIndex,
                    isPaused: _isPaused,
                    onCompleted: _onStoryCompleted,
                  ),
                ),
                
                // Header (User info, close button, delete button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        backgroundImage: currentStatus['profilePictureUrl'] != null
                            ? NetworkImage(currentStatus['profilePictureUrl'])
                            : null,
                        child: currentStatus['profilePictureUrl'] == null
                            ? Text(
                                widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              "${widget.userRole} • ${widget.userCompany} • ${_formatTimeAgo(timestamp)}",
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (isOwnStatus && statusDocId != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white70),
                          onPressed: () => _deleteStatus(statusDocId),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Main Status Content
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (mediaType == 'image' && mediaUrl != null)
                        Positioned.fill(
                          child: Image.network(
                            mediaUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      if (mediaType == 'video' && mediaUrl != null)
                        Positioned.fill(
                          child: StatusVideoPlayer(
                            videoUrl: mediaUrl,
                            isPaused: _isPaused,
                          ),
                        ),
                      if (mediaType == 'text')
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      if (mediaType != 'text' && text.isNotEmpty)
                        Positioned(
                          bottom: 24,
                          left: 24,
                          right: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Quick Actions Footer (Only if not own status)
                if (!isOwnStatus && mobile.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final Uri launchUri = Uri(
                                scheme: 'tel',
                                path: mobile,
                              );
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              try {
                                await launchUrl(launchUri);
                              } catch (e) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(content: Text('Could not call: $e')),
                                );
                              }
                            },
                            icon: const Icon(Icons.phone),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A3AFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              String cleanNumber = mobile.replaceAll(RegExp(r'[^0-9]'), '');
                              if (cleanNumber.length == 10) {
                                cleanNumber = '91$cleanNumber';
                              }
                              final Uri whatsappUri = Uri.parse("https://wa.me/$cleanNumber");
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              try {
                                await launchUrl(
                                  whatsappUri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (e) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(content: Text('Could not open WhatsApp: $e')),
                                );
                              }
                            },
                            icon: const Icon(Icons.message),
                            label: const Text('WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isPaused;

  const StatusVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isPaused,
  });

  @override
  State<StatusVideoPlayer> createState() => _StatusVideoPlayerState();
}

class _StatusVideoPlayerState extends State<StatusVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          if (!widget.isPaused) {
            _controller.play();
          }
          _controller.setLooping(false);
        }
      });
  }

  @override
  void didUpdateWidget(covariant StatusVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller.dispose();
      _isInitialized = false;
      _initializeVideo();
    } else if (_isInitialized) {
      if (widget.isPaused) {
        _controller.pause();
      } else {
        _controller.play();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
