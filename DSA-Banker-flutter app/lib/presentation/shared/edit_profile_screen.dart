import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/services/api_service.dart';

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
  final _api = ApiService();
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _altMobileController;
  late TextEditingController _dobController;
  late TextEditingController _panController;
  late TextEditingController _addressController;
  late TextEditingController _companyNameController;
  late TextEditingController _companyAddressController;

  @override
  void initState() {
    super.initState();
    final d = widget.fullData;
    _nameController = TextEditingController(text: (d['name'] ?? ApiClient.currentUserName ?? '').toString());
    _mobileController = TextEditingController(text: (d['mobile'] ?? ApiClient.currentUserMobile ?? '').toString());
    _emailController = TextEditingController(text: (d['email'] ?? ApiClient.currentUserEmail ?? '').toString());
    _altMobileController = TextEditingController(text: (d['alternateMobile'] ?? d['alternate_mobile'] ?? '').toString());
    _dobController = TextEditingController(text: (d['dob'] ?? '').toString());
    _panController = TextEditingController(text: (d['panNumber'] ?? d['pan_number'] ?? d['kycPan'] ?? '').toString().toUpperCase());
    _addressController = TextEditingController(text: (d['address'] ?? d['current_address'] ?? '').toString());
    _companyNameController = TextEditingController(text: (d['companyName'] ?? d['company'] ?? '').toString());
    _companyAddressController = TextEditingController(text: (d['companyAddress'] ?? d['company_address'] ?? d['officeAddress'] ?? '').toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _altMobileController.dispose();
    _dobController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime initial = DateTime(1995, 1, 1);
    if (_dobController.text.isNotEmpty) {
      try {
        final parts = _dobController.text.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else {
            initial = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF093A7A),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted = '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
      setState(() {
        _dobController.text = formatted;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final patch = <String, dynamic>{
        'alternateMobile': _altMobileController.text.trim(),
        'dob': _dobController.text.trim(),
        'panNumber': _panController.text.trim().toUpperCase(),
        'address': _addressController.text.trim(),
        'company': _companyNameController.text.trim(),
        'companyName': _companyNameController.text.trim(),
        'companyAddress': _companyAddressController.text.trim(),
      };
      await _api.updateProfile(patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF27AE60),
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile updated successfully!'),
              ],
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to update profile: ' + friendlyErrorMessage(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Edit Profile Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF093A7A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF093A7A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verified Account Information Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF093A7A).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF093A7A).withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified, color: Color(0xFF093A7A), size: 20),
                              SizedBox(width: 8),
                              Text('Verified Primary Info', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF093A7A), fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Name, primary mobile number and email ID are locked for account security.', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          const SizedBox(height: 12),
                          _buildLockedRow(Icons.person_outline, 'Name', _nameController.text),
                          const SizedBox(height: 8),
                          _buildLockedRow(Icons.phone_android, 'Primary Mobile', _mobileController.text),
                          const SizedBox(height: 8),
                          _buildLockedRow(Icons.email_outlined, 'Email Address', _emailController.text),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Editable Fields Section Header
                    const Text(
                      'EDITABLE PROFILE DETAILS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Alternate Mobile Number
                          _buildTextField(
                            controller: _altMobileController,
                            label: 'Alternate Mobile Number',
                            hint: 'Enter 10-digit alternate mobile',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Date of Birth
                          _buildDateField(),
                          const SizedBox(height: 18),

                          // PAN Card Number
                          _buildTextField(
                            controller: _panController,
                            label: 'Pan Card Number',
                            hint: 'e.g. ABCDE1234F',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Residential Address
                          _buildTextField(
                            controller: _addressController,
                            label: 'Full Address',
                            hint: 'House/Flat No, Street, City, State, PIN',
                            icon: Icons.home_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 18),

                          // Company Name
                          _buildTextField(
                            controller: _companyNameController,
                            label: 'Company Name',
                            hint: 'Enter company or business name',
                            icon: Icons.business_outlined,
                          ),
                          const SizedBox(height: 18),

                          // Company Address
                          _buildTextField(
                            controller: _companyAddressController,
                            label: 'Company Address',
                            hint: 'Office / Business location, Area, City',
                            icon: Icons.location_city_outlined,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF093A7A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_outlined, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Save Profile Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLockedRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF093A7A)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
          Expanded(child: Text(value.isNotEmpty ? value : 'Not set', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis)),
          const Icon(Icons.lock, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1F))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF093A7A), size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF093A7A), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date of Birth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1F))),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          child: IgnorePointer(
            child: TextFormField(
              controller: _dobController,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'DD-MM-YYYY (Click to select date)',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF093A7A), size: 20),
                suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF093A7A)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
