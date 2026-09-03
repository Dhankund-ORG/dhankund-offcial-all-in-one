import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> fullData;
  final String collectionName;
  final String uid;

  const EditProfileScreen({
    super.key,
    required this.fullData,
    required this.collectionName,
    required this.uid,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  // Fields that shouldn't be edited or displayed as standard text fields
  final List<String> _excludedFields = ['uid', 'profileCompleted', 'timestamp', 'profilePictureUrl'];
  
  // Fields that are strictly read-only
  final List<String> _readOnlyFields = ['name', 'mobile', 'email', 'role'];

  @override
  void initState() {
    super.initState();
    // Initialize controllers for all fields except excluded ones
    widget.fullData.forEach((key, value) {
      if (!_excludedFields.contains(key)) {
        _controllers[key] = TextEditingController(text: value?.toString() ?? '');
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{};
      _controllers.forEach((key, controller) {
        // Do not update read-only fields
        if (!_readOnlyFields.contains(key)) {
          updates[key] = controller.text.trim();
        }
      });

      if (updates.isNotEmpty) {
        // Update specific registration collection
        final query = await FirebaseFirestore.instance
            .collection(widget.collectionName)
            .where('uid', isEqualTo: widget.uid)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection(widget.collectionName)
              .doc(query.docs.first.id)
              .update(updates);
        }

        // Also update users collection if company was changed
        final userUpdates = <String, dynamic>{};
        if (updates.containsKey('company')) {
          userUpdates['company'] = updates['company'];
        }
        
        if (userUpdates.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .update(userUpdates);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatLabel(String key) {
    // Convert camelCase or snake_case to Title Case
    String label = key.replaceAll(RegExp(r'(?<=[a-z])[A-Z]'), r' $&');
    label = label.replaceAll('_', ' ');
    if (label.isEmpty) return key;
    return label[0].toUpperCase() + label.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    // Sort keys to show read-only fields first
    final keys = _controllers.keys.toList();
    keys.sort((a, b) {
      bool aReadOnly = _readOnlyFields.contains(a);
      bool bReadOnly = _readOnlyFields.contains(b);
      if (aReadOnly && !bReadOnly) return -1;
      if (!aReadOnly && bReadOnly) return 1;
      return a.compareTo(b);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4A3AFF),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Name, Mobile No, Email ID, and Role cannot be modified after registration.',
                              style: TextStyle(color: Colors.blue, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...keys.map((key) {
                      final isReadOnly = _readOnlyFields.contains(key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: _controllers[key],
                          readOnly: isReadOnly,
                          style: TextStyle(
                            color: isReadOnly ? Colors.grey[700] : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: _formatLabel(key),
                            filled: true,
                            fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isReadOnly ? Colors.grey[300]! : Colors.grey[400]!,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isReadOnly ? Colors.grey[300]! : Colors.grey[300]!,
                              ),
                            ),
                            suffixIcon: isReadOnly ? const Icon(Icons.lock_outline, color: Colors.grey, size: 20) : null,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A3AFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
