import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_flutter_app/services/api_service.dart';
import 'package:my_flutter_app/services/cloudflare_r2_service.dart';

const List<List<Color>> gradientStories = [
  [Color(0xFF4A3AFF), Color(0xFF6C5DD3)],
  [Color(0xFF27AE60), Color(0xFF2ECC71)],
  [Color(0xFFE17055), Color(0xFFFDCB6E)],
  [Color(0xFF0984E3), Color(0xFF74B9FF)],
  [Color(0xFFE84393), Color(0xFFFD79A8)],
  [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
  [Color(0xFFD63031), Color(0xFFFAB1A0)],
  [Color(0xFF00B894), Color(0xFF55EFC4)],
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
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 70,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasActiveStatus ? const LinearGradient(colors: [Color(0xFF4A3AFF), Color(0xFF6C5DD3)]) : null,
                border: hasActiveStatus ? null : Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0x1A4A3AFF),
                      backgroundImage: profilePictureUrl != null ? CachedNetworkImageProvider(profilePictureUrl!) : null,
                      child: profilePictureUrl == null ? const Icon(Icons.person, color: Color(0xFF4A3AFF)) : null,
                    ),
                    if (isMe && !hasActiveStatus)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFF4A3AFF), shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
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
  final VoidCallback? onStatusAdded;

  const AddStatusDialog({
    super.key,
    required this.userProfile,
    required this.uid,
    this.onStatusAdded,
  });

  @override
  State<AddStatusDialog> createState() => _AddStatusDialogState();
}

class _AddStatusDialogState extends State<AddStatusDialog> {
  final _textController = TextEditingController();
  int _selectedGradient = 0;
  Uint8List? _imageBytes;
  int _rotationQuarterTurns = 0;
  bool _isSaving = false;
  final _api = ApiService();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final f = result.files.single;
        Uint8List? bytes = f.bytes;
        if (bytes == null && f.path != null) {
          bytes = await io.File(f.path!).readAsBytes();
        }
        if (bytes != null) {
          // Open crop screen
          final cropped = await Navigator.push<Uint8List?>(
            context,
            MaterialPageRoute(builder: (context) => StatusCropScreen(initialBytes: bytes!)),
          );
          if (cropped != null) {
            setState(() {
              _imageBytes = cropped;
              _rotationQuarterTurns = 0;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: ' + friendlyErrorMessage(e))));
      }
    }
  }

  void _rotateImage() {
    if (_imageBytes == null) return;
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  Future<void> _cropCurrent() async {
    if (_imageBytes == null) return;
    final cropped = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (context) => StatusCropScreen(initialBytes: _imageBytes!)),
    );
    if (cropped != null) {
      setState(() {
        _imageBytes = cropped;
        _rotationQuarterTurns = 0;
      });
    }
  }

  Future<void> _postStatus() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write something or select a photo.')));
      return;
    }
    setState(() => _isSaving = true);
    String? mediaUrl;
    String mediaType = 'text';
    try {
      if (_imageBytes != null) {
        mediaUrl = await CloudflareR2Service().uploadFile(
          bytes: _imageBytes!,
          folderPath: 'status_media',
          extension: 'png',
        );
        mediaType = 'image';
      }
      await _api.createStatus(
        text: text,
        gradientIndex: _selectedGradient,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onStatusAdded?.call();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status uploaded! It will automatically expire in 24 hours.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post status: ' + friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Status (24h Expiry)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // Status Text Editor with Gradient
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientStories[_selectedGradient]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _textController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Type your message or announcement...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Gradient Selector
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: gradientStories.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => setState(() => _selectedGradient = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientStories[index]),
                        shape: BoxShape.circle,
                        border: _selectedGradient == index ? Border.all(color: Colors.black87, width: 3) : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Selected Image Box with Rotate & Crop Tools
              if (_imageBytes != null) ...[
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RotatedBox(
                          quarterTurns: _rotationQuarterTurns,
                          child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _imageBytes = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _rotateImage,
                      icon: const Icon(Icons.rotate_right, size: 18, color: Color(0xFF4A3AFF)),
                      label: const Text('Rotate 90°', style: TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: _cropCurrent,
                      icon: const Icon(Icons.crop, size: 18, color: Color(0xFF27AE60)),
                      label: const Text('Crop Image', style: TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library, color: Color(0xFF27AE60)),
                  label: const Text('Add Status Photo (Rotate & Crop Available)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _postStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3AFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Post Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
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
  final VoidCallback? onDeleted;

  const StatusViewerDialog({
    super.key,
    required this.userName,
    required this.userRole,
    required this.userCompany,
    required this.statuses,
    required this.currentUid,
    this.onDeleted,
  });

  @override
  State<StatusViewerDialog> createState() => _StatusViewerDialogState();
}

class _StatusViewerDialogState extends State<StatusViewerDialog> {
  late PageController _pageController;
  int _currentPage = 0;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteStatus(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Status?'),
        content: const Text('Are you sure you want to delete this status story immediately?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deleteStatus(id);
        widget.onDeleted?.call();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status deleted successfully!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete status: ' + friendlyErrorMessage(e))));
        }
      }
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = widget.currentUid.isNotEmpty ? widget.currentUid : (ApiClient.currentUserId ?? '');

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.statuses.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final status = widget.statuses[index];
                final text = (status['text'] ?? '').toString();
                final gradientIndex = (status['gradientIndex'] ?? 0) as int;
                final gradient = gradientStories[gradientIndex % gradientStories.length];
                final rawMedia = status['mediaUrl'];
                final String? mediaUrl = (rawMedia != null && rawMedia.toString().isNotEmpty)
                    ? (rawMedia.toString().startsWith('http') ? rawMedia.toString() : (ApiClient.baseUrl + (rawMedia.toString().startsWith('/') ? rawMedia.toString() : '/$rawMedia')))
                    : null;
                final mediaType = (status['mediaType'] ?? 'text').toString();

                final statusUid = (status['uid'] ?? status['userId'] ?? '').toString();
                final isOwn = currentUid.isNotEmpty && (statusUid == currentUid);

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 100),
                          if (mediaUrl != null && mediaType == 'image')
                            Expanded(
                              child: Center(
                                child: CachedNetworkImage(
                                  imageUrl: mediaUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 64, color: Colors.white54),
                                ),
                              ),
                            )
                          else if (text.isNotEmpty)
                            const Spacer(),
                          if (text.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(color: (mediaUrl != null) ? Colors.black54 : Colors.transparent),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
                              ),
                            ),
                          if (mediaUrl != null && mediaType == 'image')
                            const SizedBox(height: 32)
                          else if (text.isNotEmpty)
                            const Spacer(),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('${widget.userRole} • ${_formatTime(status['timestamp'])}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (isOwn)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                                    tooltip: 'Delete Status',
                                    onPressed: () => _confirmDeleteStatus((status['id'] ?? '').toString()),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: (_currentPage + 1) / widget.statuses.length,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (widget.statuses.length > 1) ...[
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () {
                    if (_currentPage > 0) _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: const SizedBox(width: 60, child: Icon(Icons.chevron_left, color: Colors.white54, size: 36)),
                ),
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () {
                    if (_currentPage < widget.statuses.length - 1) _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: const SizedBox(width: 60, child: Icon(Icons.chevron_right, color: Colors.white54, size: 36)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusCropScreen extends StatefulWidget {
  final Uint8List initialBytes;
  const StatusCropScreen({super.key, required this.initialBytes});

  @override
  State<StatusCropScreen> createState() => _StatusCropScreenState();
}

class _StatusCropScreenState extends State<StatusCropScreen> {
  final GlobalKey _cropKey = GlobalKey();
  bool _isCropping = false;
  int _rotationQuarterTurns = 0;

  Future<void> _cropAndReturn() async {
    setState(() => _isCropping = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      RenderRepaintBoundary? boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Could not find render object");
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Could not convert image to bytes");
      Uint8List croppedBytes = byteData.buffer.asUint8List();
      if (mounted) Navigator.pop(context, croppedBytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not crop status image.')));
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  void _rotate() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Crop & Rotate Status Photo', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right, color: Colors.white),
            tooltip: 'Rotate 90°',
            onPressed: _rotate,
          ),
          if (!_isCropping)
            TextButton(
              onPressed: _cropAndReturn,
              child: const Text('APPLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      width: 320,
                      height: 400,
                      decoration: BoxDecoration(border: Border.all(color: Colors.white30, width: 1.5)),
                      child: RepaintBoundary(
                        key: _cropKey,
                        child: InteractiveViewer(
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          minScale: 0.8,
                          maxScale: 5.0,
                          child: RotatedBox(
                            quarterTurns: _rotationQuarterTurns,
                            child: Image.memory(widget.initialBytes, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                color: Colors.black87,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _rotate,
                        icon: const Icon(Icons.rotate_right, color: Colors.white),
                        label: const Text('Rotate 90°', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                      ),
                      ElevatedButton.icon(
                        onPressed: _cropAndReturn,
                        icon: const Icon(Icons.crop, color: Colors.white),
                        label: const Text('Crop & Use', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3AFF)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isCropping)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }
}
