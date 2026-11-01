import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../api_service.dart';
import '../../cloudflare_r2_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class BannersPage extends StatefulWidget {
  const BannersPage({super.key});

  @override
  State<BannersPage> createState() => _BannersPageState();
}

class _BannersPageState extends State<BannersPage> {
  final ApiService _api = ApiService();
  final CloudflareR2Service _r2 = CloudflareR2Service();

  bool _isLoading = true;
  List<Map<String, dynamic>> _banners = [];

  final List<String> _presetColors = [
    '0xFF093A7A', // Deep Navy
    '0xFF27AE60', // Emerald Green
    '0xFF0984E3', // Royal Blue
    '0xFF6C5CE7', // Purple
    '0xFFE17055', // Terracotta
    '0xFFD63031', // Crimson Red
  ];

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.fetchBanners();
      if (mounted) {
        setState(() {
          _banners = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(String id, bool currentStatus) async {
    try {
      await _api.updateBannerStatus(id, !currentStatus);
      _loadBanners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteBanner(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Banner', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this promotional banner?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
        await _api.deleteBanner(id);
        _loadBanners();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banner deleted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete banner: $e')),
          );
        }
      }
    }
  }

  void _showAddBannerDialog() {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    String selectedColor = _presetColors.first;
    String? uploadedImageUrl;
    bool isUploadingImage = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: AppTheme.royalGold),
              SizedBox(width: 10),
              Text('Create New App Banner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Title / Offer Heading', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Special Personal Loan Offer',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Subtitle / Offer Description', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: subtitleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Lowest interest rates starting @ 10.49% p.a.',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Theme Background Color', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: _presetColors.map((hex) {
                      final c = Color(int.parse(hex));
                      final isSelected = selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Image Upload Section
                  const Text('Banner Image (Optional - Overrides Background)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (uploadedImageUrl != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            uploadedImageUrl!.startsWith('http') ? uploadedImageUrl! : (ApiClient.baseUrl + (uploadedImageUrl!.startsWith('/') ? uploadedImageUrl! : '/$uploadedImageUrl')),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setDialogState(() => uploadedImageUrl = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: isUploadingImage
                          ? null
                          : () async {
                              try {
                                final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                                if (res != null && res.files.isNotEmpty) {
                                  final file = res.files.single;
                                  if (file.bytes != null) {
                                    setDialogState(() => isUploadingImage = true);
                                    final ext = file.extension ?? 'png';
                                    final fileName = 'banners/${DateTime.now().millisecondsSinceEpoch}_banner.$ext';
                                    final url = await _r2.uploadDocument(fileName, file.bytes!);
                                    setDialogState(() {
                                      uploadedImageUrl = url;
                                      isUploadingImage = false;
                                    });
                                  }
                                }
                              } catch (e) {
                                setDialogState(() => isUploadingImage = false);
                              }
                            },
                      icon: isUploadingImage
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                      label: Text(isUploadingImage ? 'Uploading Image to R2...' : 'Select Banner Image File', style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                    ),
                  const SizedBox(height: 20),

                  // Live Preview Box
                  const Text('Live Mobile Preview', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    height: 90,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(int.parse(selectedColor)),
                      borderRadius: BorderRadius.circular(16),
                      image: (uploadedImageUrl != null && uploadedImageUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(uploadedImageUrl!.startsWith('http') ? uploadedImageUrl! : (ApiClient.baseUrl + (uploadedImageUrl!.startsWith('/') ? uploadedImageUrl! : '/$uploadedImageUrl'))),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (uploadedImageUrl == null || uploadedImageUrl!.isEmpty)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                titleController.text.isNotEmpty ? titleController.text : 'Sample Banner Heading',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitleController.text.isNotEmpty ? subtitleController.text : 'Sample offer description text goes here',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty && (uploadedImageUrl == null || uploadedImageUrl!.isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter banner title or select an image')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await _api.createBanner(
                          title: titleController.text.trim(),
                          subtitle: subtitleController.text.trim(),
                          colorHex: selectedColor,
                          imageUrl: uploadedImageUrl,
                          isActive: true,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          _loadBanners();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Banner created and published successfully!')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save banner: $e')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalGold,
                foregroundColor: Colors.black,
              ),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Publish Banner', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Promotional Banners',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage dynamic auto-sliding banners shown on the mobile app home screen (5-second intervals).',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddBannerDialog,
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Add New Banner', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalGold,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                : _banners.isEmpty
                    ? Center(
                        child: GlassCard(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.view_carousel_outlined, size: 48, color: Colors.white30),
                              const SizedBox(height: 16),
                              const Text('No Promotional Banners Found', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text('Click "Add New Banner" above to publish your first mobile app offer banner.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _showAddBannerDialog,
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalGold, foregroundColor: Colors.black),
                                child: const Text('Create Banner Now'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 450,
                          mainAxisExtent: 220,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _banners.length,
                        itemBuilder: (context, index) {
                          final banner = _banners[index];
                          final id = (banner['id'] ?? '').toString();
                          final title = (banner['title'] ?? '').toString();
                          final subtitle = (banner['subtitle'] ?? '').toString();
                          final colorHex = (banner['color_hex'] ?? '0xFF093A7A').toString();
                          final color = Color(int.tryParse(colorHex) ?? 0xFF093A7A);
                          final rawImg = banner['image_url'];
                          final bool isActive = (banner['is_active'] == 1 || banner['is_active'] == true);
                          final String? imageUrl = (rawImg != null && rawImg.toString().isNotEmpty)
                              ? (rawImg.toString().startsWith('http') ? rawImg.toString() : (ApiClient.baseUrl + (rawImg.toString().startsWith('/') ? rawImg.toString() : '/$rawImg')))
                              : null;

                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Banner Visual Preview
                                Container(
                                  height: 100,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(12),
                                    image: (imageUrl != null && imageUrl.isNotEmpty)
                                        ? DecorationImage(
                                            image: NetworkImage(imageUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: (imageUrl == null || imageUrl.isEmpty)
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ],
                                        )
                                      : null,
                                ),
                                const Spacer(),

                                // Actions & Status
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: isActive ? Colors.green : Colors.grey),
                                      ),
                                      child: Text(
                                        isActive ? 'Active on App' : 'Inactive',
                                        style: TextStyle(color: isActive ? Colors.green : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(isActive ? Icons.visibility : Icons.visibility_off, color: isActive ? Colors.white70 : Colors.grey, size: 20),
                                      tooltip: isActive ? 'Deactivate' : 'Activate',
                                      onPressed: () => _toggleStatus(id, isActive),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      tooltip: 'Delete Banner',
                                      onPressed: () => _deleteBanner(id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
