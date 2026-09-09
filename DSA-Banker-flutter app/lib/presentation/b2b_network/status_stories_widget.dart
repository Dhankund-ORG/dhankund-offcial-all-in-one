import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
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
  const StatusCircle({super.key, required this.label, required this.hasActiveStatus, required this.isMe, this.profilePictureUrl, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 70,
        child: Column(children: [
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
              child: Stack(children: [
                CircleAvatar(radius: 28, backgroundColor: const Color(0x1A4A3AFF), backgroundImage: profilePictureUrl != null ? NetworkImage(profilePictureUrl!) : null, child: profilePictureUrl == null ? const Icon(Icons.person, color: Color(0xFF4A3AFF)) : null),
                if (isMe && !hasActiveStatus)
                  Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF4A3AFF), shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 12))),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87)),
        ]),
      ),
    );
  }
}

class AddStatusDialog extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final String uid;
  final VoidCallback? onStatusAdded;
  const AddStatusDialog({super.key, required this.userProfile, required this.uid, this.onStatusAdded});
  @override
  State<AddStatusDialog> createState() => _AddStatusDialogState();
}

class _AddStatusDialogState extends State<AddStatusDialog> {
  final _textController = TextEditingController();
  int _selectedGradient = 0;
  PlatformFile? _selectedFile;
  bool _isSaving = false;
  final _api = ApiService();

  @override
  void dispose() { _textController.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null) setState(() => _selectedFile = result.files.single);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: \$e')));
    }
  }

  Future<void> _postStatus() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write something or add a photo')));
      return;
    }
    setState(() => _isSaving = true);
    String? mediaUrl;
    String mediaType = 'text';
    try {
      if (_selectedFile != null) {
        final extension = _selectedFile!.extension ?? 'jpg';
        Uint8List fileBytes;
        if (kIsWeb || _selectedFile!.bytes != null) {
          fileBytes = _selectedFile!.bytes!;
        } else {
          fileBytes = await io.File(_selectedFile!.path!).readAsBytes();
        }
        mediaUrl = await CloudflareR2Service().uploadFile(bytes: fileBytes, folderPath: 'status_media', extension: extension);
        mediaType = 'image';
      }
      await _api.createStatus(text: text, gradientIndex: _selectedGradient, mediaUrl: mediaUrl, mediaType: mediaType);
      if (mounted) {
        Navigator.pop(context);
        widget.onStatusAdded?.call();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status posted!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post status: \$e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 480),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Add Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF))),
              IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: LinearGradient(colors: gradientStories[_selectedGradient]), borderRadius: BorderRadius.circular(16)),
              child: TextField(controller: _textController, maxLines: 3, style: const TextStyle(color: Colors.white, fontSize: 16), decoration: const InputDecoration(hintText: 'Type your status...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: gradientStories.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => setState(() => _selectedGradient = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 50,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: gradientStories[index]), shape: BoxShape.circle, border: _selectedGradient == index ? Border.all(color: Colors.black, width: 3) : null),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedFile != null)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: kIsWeb ? Image.memory(_selectedFile!.bytes!, height: 120, width: double.infinity, fit: BoxFit.cover) : Image.file(io.File(_selectedFile!.path!), height: 120, width: double.infinity, fit: BoxFit.cover)),
                Positioned(right: 8, top: 8, child: GestureDetector(onTap: () => setState(() => _selectedFile = null), child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, color: Colors.white, size: 18)))),
              ])
            else
              OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_library, color: Color(0xFF27AE60)), label: const Text('Add Photo (Optional)')),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _postStatus,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3AFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(double.infinity, 48)),
              child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Post Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ]),
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
  const StatusViewerDialog({super.key, required this.userName, required this.userRole, required this.userCompany, required this.statuses, required this.currentUid});
  @override
  State<StatusViewerDialog> createState() => _StatusViewerDialogState();
}

class _StatusViewerDialogState extends State<StatusViewerDialog> {
  late PageController _pageController;
  int _currentPage = 0;
  final _api = ApiService();

  @override
  void initState() { super.initState(); _pageController = PageController(); }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  Future<void> _deleteStatus(String id) async {
    try {
      await _api.deleteStatus(id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: \$e')));
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString());
      final diff = DateTime.now().difference(dt);
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.statuses.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final status = widget.statuses[index];
              final text = (status['text'] ?? '').toString();
              final gradientIndex = (status['gradientIndex'] ?? 0) as int;
              final gradient = gradientStories[gradientIndex % gradientStories.length];
              final mediaUrl = status['mediaUrl'];
              final mediaType = (status['mediaType'] ?? 'text').toString();
              final isOwn = (status['uid'] ?? '') == widget.currentUid;
              return Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                child: Stack(children: [
                  if (mediaUrl != null && mediaUrl.toString().isNotEmpty && mediaType == 'image')
                    Center(child: Image.network(mediaUrl.toString(), fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 64, color: Colors.white54))),
                  if (text.isNotEmpty)
                    Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500)))),
                  Positioned(top: 40, left: 16, right: 16, child: Row(children: [
                    const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${widget.userRole} - ${_formatTime(status['timestamp'])}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
                    if (isOwn) IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: () => _deleteStatus((status['id'] ?? '').toString())),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  ])),
                  Positioned(bottom: 0, left: 0, right: 0, child: LinearProgressIndicator(value: (_currentPage + 1) / widget.statuses.length, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 3)),
                ]),
              );
            },
          ),
          if (widget.statuses.length > 1) ...[
            Positioned(left: 4, top: 0, bottom: 0, child: GestureDetector(onTap: () { if (_currentPage > 0) _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); }, child: const SizedBox(width: 60, child: Icon(Icons.chevron_left, color: Colors.white54)))),
            Positioned(right: 4, top: 0, bottom: 0, child: GestureDetector(onTap: () { if (_currentPage < widget.statuses.length - 1) _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); }, child: const SizedBox(width: 60, child: Icon(Icons.chevron_right, color: Colors.white54)))),
          ],
        ]),
      ),
    );
  }
}
