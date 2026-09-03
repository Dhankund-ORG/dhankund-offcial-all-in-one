import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/presentation/shared/custom_button.dart';
import 'package:my_flutter_app/presentation/shared/file_upload_widget.dart';
import 'package:my_flutter_app/presentation/shared/new_home_screen.dart';

class DsaFormScreen extends StatefulWidget {
  const DsaFormScreen({super.key});

  @override
  State<DsaFormScreen> createState() => _DsaFormScreenState();
}

class _DsaFormScreenState extends State<DsaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _gumastaUrl;
  bool _isLoading = false;
  
  // Controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  final _currentExpController = TextEditingController();
  final _totalExpController = TextEditingController();
  final _partnerNameController = TextEditingController();
  final _partnerMobileController = TextEditingController();
  final _aboutController = TextEditingController();

  // Selection values
  String? _selectedGender;
  String? _selectedSegment;
  String _selectedProfession = 'JOB';

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _segments = ['Personal Loan', 'Business Loan', 'Home Loan', 'Credit Cards', 'All', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _currentExpController.dispose();
    _totalExpController.dispose();
    _partnerNameController.dispose();
    _partnerMobileController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        // Save registration
        await FirebaseFirestore.instance.collection('dsa_registrations').add({
          'uid': user?.uid,
          'email': user?.email,
          'name': _nameController.text,
          'mobile': _mobileController.text,
          'gender': _selectedGender,
          'gumastaUrl': _gumastaUrl,
          'company': _companyController.text,
          'address': _addressController.text,
          'currentExp': _currentExpController.text,
          'totalExp': _totalExpController.text,
          'segment': _selectedSegment,
          'profession': _selectedProfession,
          'partnerName': _partnerNameController.text,
          'partnerMobile': _partnerMobileController.text,
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
            'role': 'DSA',
            'company': _companyController.text,
            'gumastaUrl': _gumastaUrl,
            'address': _addressController.text,
            'currentExp': _currentExpController.text,
            'totalExp': _totalExpController.text,
            'segment': _selectedSegment,
            'profession': _selectedProfession,
            'partnerName': _partnerNameController.text,
            'partnerMobile': _partnerMobileController.text,
            'about': _aboutController.text,
            'profileCompleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DSA Registration Successful!')),
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
          'DSA Registration',
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
              _buildSectionTitle('DSA Personal Details'),
              _buildFieldLabel('Name *'),
              _buildTextField(_nameController, 'Enter full name', Icons.person, required: true),
              
              _buildFieldLabel('Mobile No. *'),
              _buildTextField(_mobileController, 'Enter mobile number', Icons.phone, keyboardType: TextInputType.phone, required: true),
              
              _buildFieldLabel('Mail ID *'),
              _buildTextField(_emailController, 'Enter email address', Icons.email, keyboardType: TextInputType.emailAddress, required: true),
              
              _buildFieldLabel('Gender *'),
              _buildDropdownField(_selectedGender, _genders, 'Select Gender', (val) => setState(() => _selectedGender = val)),
              
              const SizedBox(height: 16),
              FileUploadWidget(
                label: 'Upload Gumasta Certificate (Optional)',
                storagePath: 'gumasta_docs',
                onUploadComplete: (url) => setState(() => _gumastaUrl = url),
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Professional Context'),
              _buildFieldLabel('Company Name'),
              _buildTextField(_companyController, 'Enter company name', Icons.business),
              
              _buildFieldLabel('Address'),
              _buildTextField(_addressController, 'Enter your address', Icons.location_on, maxLines: 2),

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
              
              _buildFieldLabel('Segment'),
              _buildDropdownField(_selectedSegment, _segments, 'Select Loan Segment', (val) => setState(() => _selectedSegment = val)),

              _buildFieldLabel('Profession'),
              Row(
                children: [
                  _buildRadioButton('JOB'),
                  _buildRadioButton('SELF'),
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Partner Information'),
              _buildFieldLabel('Any Partner Name'),
              _buildTextField(_partnerNameController, 'Enter partner name', Icons.people_outline),
              
              _buildFieldLabel('Partner Mobile No.'),
              _buildTextField(_partnerMobileController, 'Enter partner mobile', Icons.phone_android, keyboardType: TextInputType.phone),

              const SizedBox(height: 24),
              _buildSectionTitle('Background Info'),
              _buildFieldLabel('Profile Note / About'),
              _buildTextField(_aboutController, 'Details for manager review', Icons.description, maxLines: 3),

              const SizedBox(height: 32),
              CustomButton(
                text: 'Register as DSA',
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

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, bool required = false}) {
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
          final text = (value ?? '').trim();
          if (required && text.isEmpty) {
            return 'This field is required';
          }
          if (text.isNotEmpty && keyboardType == TextInputType.phone) {
            if (!RegExp(r'^[0-9]{10}$').hasMatch(text)) {
              return 'Please enter a valid 10-digit mobile number';
            }
          }
          if (text.isNotEmpty && keyboardType == TextInputType.emailAddress) {
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(text)) {
              return 'Please enter a valid email address';
            }
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

