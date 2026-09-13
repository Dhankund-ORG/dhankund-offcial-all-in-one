import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/api_service.dart';

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});
  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _isLoading = true);
    try {
      final banners = await _api.fetchBanners();
      if (mounted) setState(() { _banners = banners; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addBanner() {
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    final colorCtrl = TextEditingController(text: '0xFF4A3AFF');
    final imageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Banner'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(controller: subtitleCtrl, decoration: const InputDecoration(labelText: 'Subtitle')),
              const SizedBox(height: 8),
              TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'Color Hex (e.g. 0xFF4A3AFF)')),
              const SizedBox(height: 8),
              TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Image URL (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                // We use ApiClient directly since we don't have post in ApiService easily accessible outside
                await ApiClient.post('/api/v1/banners', {
                  'title': titleCtrl.text,
                  'subtitle': subtitleCtrl.text,
                  'color_hex': colorCtrl.text,
                  'image_url': imageCtrl.text,
                  'is_active': true
                });
                _loadBanners();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBanner(String id) async {
    setState(() => _isLoading = true);
    try {
      await ApiClient.delete('/api/v1/banners/$id');
      _loadBanners();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Banners')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _banners.isEmpty
              ? const Center(child: Text('No banners found.'))
              : ListView.builder(
                  itemCount: _banners.length,
                  itemBuilder: (context, index) {
                    final b = _banners[index];
                    return ListTile(
                      title: Text((b['title'] ?? '').toString()),
                      subtitle: Text((b['subtitle'] ?? '').toString()),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteBanner((b['id'] ?? '').toString()),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBanner,
        child: const Icon(Icons.add),
      ),
    );
  }
}
