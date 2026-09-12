import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_flutter_app/services/api_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/cloudflare_r2_service.dart';
import 'package:my_flutter_app/presentation/auth/welcome_screen.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:io' as io;
import 'package:my_flutter_app/presentation/shared/edit_profile_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isUploading = false;
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  final _api = ApiService();

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    try {
      final p = await _api.fetchMyProfile();
      if (mounted) setState(() { _profile = p; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && (result.files.single.path != null || result.files.single.bytes != null)) {
        final file = result.files.single;
        if (ApiClient.currentUserId == null) return;
        final croppedBytes = await Navigator.push<Uint8List?>(context, MaterialPageRoute(builder: (context) => ImageCropScreen(file: file)));
        if (croppedBytes == null) return;
        setState(() => _isUploading = true);
        final downloadUrl = await CloudflareR2Service().uploadFile(bytes: croppedBytes, folderPath: 'profile_pictures', extension: 'png');
        await _api.updateProfile({'profilePictureUrl': downloadUrl});
        if (mounted) { setState(() { _profile['profilePictureUrl'] = downloadUrl; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated successfully!'))); }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload profile picture. ' + friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A3AFF)))
        : RefreshIndicator(
            color: const Color(0xFF4A3AFF),
            onRefresh: _loadProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                _buildHeader(context, _profile['name'] ?? 'User Name', _profile['email'] ?? ApiClient.currentUserEmail ?? 'No Email', (_profile['role'] ?? 'Partner').toString().toUpperCase(), _profile['profilePictureUrl'] as String?, _profile, ApiClient.currentUserId ?? ''),
                const SizedBox(height: 24),
                _buildInfoSection(_profile),
                const SizedBox(height: 24),
                _buildLogoutButton(context),
                const SizedBox(height: 40),
              ]),
            ),
          ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String email, String role, String? profilePictureUrl, Map<String, dynamic> fullData, String uid) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4A3AFF), Color(0xFF6C5DD3)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () async { final updated = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(fullData: fullData, collectionName: '', uid: uid))); if (updated == true) _loadProfile(); })]),
        GestureDetector(onTap: _isUploading ? null : _pickAndUploadImage, child: Stack(children: [
          Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: CircleAvatar(radius: 50, backgroundColor: Colors.white, backgroundImage: profilePictureUrl != null ? NetworkImage(profilePictureUrl) : null, child: profilePictureUrl == null ? const Icon(Icons.person, size: 60, color: Color(0xFF4A3AFF)) : null)),
          if (_isUploading) Positioned.fill(child: Container(decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Center(child: CircularProgressIndicator(color: Colors.white)))),
          if (!_isUploading) Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFF27AE60), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
        ])),
        const SizedBox(height: 16),
        Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1))),
        const SizedBox(height: 16),
        Text(email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ]),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> data) {
    List<Widget> details = [];
    final company = data['company'] ?? 'Independent';
    details.add(_buildDetailTile(Icons.business_center_outlined, 'Company', company.toString()));
    details.add(_buildDetailTile(Icons.phone_outlined, 'Mobile', (data['mobile'] ?? 'Not provided').toString()));
    details.add(_buildDetailTile(Icons.location_on_outlined, 'Address', (data['address'] ?? data['officeAddress'] ?? data['current_address'] ?? 'Not provided').toString()));
    final nomineeName = data['nomineeName'];
    if (nomineeName != null && nomineeName.toString().isNotEmpty) details.add(_buildDetailTile(Icons.people_outline, 'Nominee Name', nomineeName.toString()));
    final excludedKeys = ['name', 'email', 'role', 'profilePictureUrl', 'company', 'mobile', 'address', 'officeAddress', 'current_address', 'nomineeName', 'uid', 'id', 'timestamp', 'profileCompleted', 'kycCompleted', 'bankDetailsCompleted', 'kycPan', 'kycAadhaar', 'kycDocUrl', 'bankName', 'bankAccountHolder', 'bankAccountNumber', 'bankIfsc', 'bankProofUrl', 'updatedAt', 'createdAt'];
    data.forEach((key, value) {
      if (!excludedKeys.contains(key) && value != null && value.toString().isNotEmpty) {
        String label = key.replaceAll(RegExp(r'(?<=[a-z])[A-Z]'), r' $&');
        label = label.replaceAll('_', ' ');
        label = label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : key;
        details.add(_buildDetailTile(Icons.info_outline, label, value.toString()));
      }
    });
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('FULL DETAILS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
      const SizedBox(height: 16), _buildDetailCard(details),
      const SizedBox(height: 24),
      const Text('ACCOUNT STATS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
      const SizedBox(height: 16),
      _buildDetailCard([_buildDetailTile(Icons.verified_user_outlined, 'KYC', (data['kycCompleted'] == true) ? 'Completed' : 'Pending'), _buildDetailTile(Icons.account_balance_outlined, 'Bank Details', (data['bankDetailsCompleted'] == true) ? 'Linked' : 'Not Linked')]),
    ]));
  }

  Widget _buildDetailCard(List<Widget> children) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: children));
  Widget _buildDetailTile(IconData icon, String label, String value) => ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF4A3AFF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF4A3AFF), size: 20)), title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)));

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: ElevatedButton(
      onPressed: () async { await AuthService().logout(); if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false); },
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red, elevation: 0, side: const BorderSide(color: Colors.redAccent, width: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), minimumSize: const Size(double.infinity, 56)),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout), SizedBox(width: 8), Text('Logout Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
    ));
  }
}

class ImageCropScreen extends StatefulWidget {
  final PlatformFile file;
  const ImageCropScreen({super.key, required this.file});
  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final GlobalKey _cropKey = GlobalKey();
  bool _isCropping = false;

  Future<void> _cropAndReturn() async {
    setState(() => _isCropping = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      RenderRepaintBoundary? boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Could not find repaint boundary");
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Could not convert image to bytes");
      Uint8List croppedBytes = byteData.buffer.asUint8List();
      if (mounted) Navigator.pop(context, croppedBytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not crop image. Please try again.')));
    } finally { if (mounted) setState(() => _isCropping = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Crop Profile Picture', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), actions: [if (!_isCropping) TextButton(onPressed: _cropAndReturn, child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))]),
      body: Stack(children: [
        Column(children: [
          Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Container(width: 300, height: 300, decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 1)), child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(child: RepaintBoundary(key: _cropKey, child: InteractiveViewer(boundaryMargin: EdgeInsets.zero, minScale: 1.0, maxScale: 5.0, child: _buildImageWidget()))),
            IgnorePointer(child: Positioned.fill(child: CustomPaint(painter: CropOverlayPainter()))),
          ]))))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), color: Colors.black87, child: Column(children: [const Icon(Icons.crop_free, color: Colors.white70, size: 28), const SizedBox(height: 12), const Text('Pinch to Zoom & Drag to Position', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), Text('Only the area inside the circular border will be saved as your profile picture.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 13))])),
        ]),
        if (_isCropping) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
      ]),
    );
  }

  Widget _buildImageWidget() {
    if (kIsWeb) { if (widget.file.bytes != null) return Image.memory(widget.file.bytes!, fit: BoxFit.cover); }
    else { if (widget.file.path != null) return Image.file(io.File(widget.file.path!), fit: BoxFit.cover); else if (widget.file.bytes != null) return Image.memory(widget.file.bytes!, fit: BoxFit.cover); }
    return const Center(child: Text("Could not load image", style: TextStyle(color: Colors.white)));
  }
}

class CropOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.5);
    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()..addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2));
    final path = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(path, paint);
    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, borderPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
