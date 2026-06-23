import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/presentation/shared/custom_button.dart';
import 'package:my_flutter_app/presentation/shared/file_upload_widget.dart';
import 'package:my_flutter_app/presentation/shared/new_home_screen.dart';

class BankerFormScreen extends StatefulWidget {
  const BankerFormScreen({super.key});

  @override
  State<BankerFormScreen> createState() => _BankerFormScreenState();
}

class _BankerFormScreenState extends State<BankerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _idCardUrl;
  bool _isLoading = false;
  
  // Controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _currentExpController = TextEditingController();
  final _totalExpController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerMobileController = TextEditingController();
  final _areaManagerNameController = TextEditingController();
  final _areaManagerMobileController = TextEditingController();
  final _nomineeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _aboutController = TextEditingController();

  // Selection values
  String? _selectedGender;
  String? _selectedSegment;
  String _selectedProfession = 'JOB';

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _segments = ['HL', 'LAP', 'PL', 'BL', 'AUTO', 'All'];

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _currentExpController.dispose();
    _totalExpController.dispose();
    _managerNameController.dispose();
    _managerMobileController.dispose();
    _areaManagerNameController.dispose();
    _areaManagerMobileController.dispose();
    _nomineeNameController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        // Save registration
        await FirebaseFirestore.instance.collection('banker_registrations').add({
          'uid': user?.uid,
          'email': user?.email,
          'name': _nameController.text,
          'mobile': _mobileController.text,
          'gender': _selectedGender,
          'idCardUrl': _idCardUrl,
          'company': _companyController.text,
          'currentExp': _currentExpController.text,
          'totalExp': _totalExpController.text,
          'profession': _selectedProfession,
          'segment': _selectedSegment,
          'managerName': _managerNameController.text,
          'managerMobile': _managerMobileController.text,
          'areaManagerName': _areaManagerNameController.text,
          'areaManagerMobile': _areaManagerMobileController.text,
          'nomineeName': _nomineeNameController.text,
          'officeAddress': _addressController.text,
          'about': _aboutController.text,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        // Mark profile as completed and sync ALL details
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'name': _nameController.text,
            'mobile': _mobileController.text,
            'gender': _selectedGender,
            'role': 'Banker',
            'company': _companyController.text,
            'idCardUrl': _idCardUrl,
            'currentExp': _currentExpController.text,
            'totalExp': _totalExpController.text,
            'profession': _selectedProfession,
            'segment': _selectedSegment,
            'managerName': _managerNameController.text,
            'managerMobile': _managerMobileController.text,
            'areaManagerName': _areaManagerNameController.text,
            'areaManagerMobile': _areaManagerMobileController.text,
            'nomineeName': _nomineeNameController.text,
            'address': _addressController.text,
            'about': _aboutController.text,
            'profileCompleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banker Registration Successful!')),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const NewHomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Banker Registration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Personal Details'),
              _buildFieldLabel('Name *'),
              _buildTextField(_nameController, 'Enter full name', Icons.person),
              
              _buildFieldLabel('Mobile No. *'),
              _buildTextField(_mobileController, 'Enter mobile number', Icons.phone, keyboardType: TextInputType.phone),
              
              _buildFieldLabel('Mail ID *'),
              _buildTextField(_emailController, 'Enter email address', Icons.email, keyboardType: TextInputType.emailAddress),
              
              _buildFieldLabel('Gender *'),
              _buildDropdownField(_selectedGender, _genders, 'Select Gender', (val) => setState(() => _selectedGender = val)),
              
              _buildFieldLabel('Nominee Name'),
              _buildTextField(_nomineeNameController, 'Enter nominee name', Icons.person_outline),
              
              const SizedBox(height: 16),
              FileUploadWidget(
                label: 'Upload Banker ID Card (Optional)',
                storagePath: 'banker_ids',
                onUploadComplete: (url) => setState(() => _idCardUrl = url),
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Professional Info'),
              _buildFieldLabel('Company Name'),
              _buildTextField(_companyController, 'Enter company name', Icons.business),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Current Experience'),
                        _buildTextField(_currentExpController, 'Years', Icons.work_history),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Total Experience'),
                        _buildTextField(_totalExpController, 'Years', Icons.history),
                      ],
                    ),
                  ),
                ],
              ),
              
              _buildFieldLabel('Profession'),
              Row(
                children: [
                  _buildRadioButton('JOB'),
                  _buildRadioButton('SELF'),
                ],
              ),

              _buildFieldLabel('Segment (HL / LAP / PL / BL / AUTO / All)'),
              _buildDropdownField(_selectedSegment, _segments, 'Select Segment', (val) => setState(() => _selectedSegment = val)),

              const SizedBox(height: 24),
              _buildSectionTitle('Manager Hierarchy'),
              _buildFieldLabel('Level 1 / Manager Name'),
              _buildTextField(_managerNameController, 'Manager name', Icons.person_outline),
              
              _buildFieldLabel('Manager Mobile No.'),
              _buildTextField(_managerMobileController, 'Manager mobile', Icons.phone_android, keyboardType: TextInputType.phone),
              
              _buildFieldLabel('Level 2 / Area Manager Name'),
              _buildTextField(_areaManagerNameController, 'Area manager name', Icons.person_search),
              
              _buildFieldLabel('Area Manager Mobile No.'),
              _buildTextField(_areaManagerMobileController, 'Area manager mobile', Icons.contact_phone, keyboardType: TextInputType.phone),

              const SizedBox(height: 24),
              _buildSectionTitle('Additional Details'),
              _buildFieldLabel('Office Address'),
              _buildTextField(_addressController, 'Enter complete office address', Icons.location_on, maxLines: 3),
              
              _buildFieldLabel('Profile Note / About'),
              _buildTextField(_aboutController, 'Tell us about yourself', Icons.note, maxLines: 3),

              const SizedBox(height: 32),
              CustomButton(
                text: 'Register Banker',
                onPressed: _submitForm,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4A3AFF),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF4A3AFF), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (value) {
          if (hint.contains('*') && (value == null || value.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(String? value, List<String> items, String hint, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          hint: Text(hint),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(border: InputBorder.none),
          validator: (val) => val == null ? 'Please select an option' : null,
        ),
      ),
    );
  }

  Widget _buildRadioButton(String value) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: _selectedProfession,
          activeColor: const Color(0xFF4A3AFF),
          onChanged: (val) => setState(() => _selectedProfession = val!),
        ),
        Text(value),
        const SizedBox(width: 20),
      ],
    );
  }
}

