import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/api_service.dart';
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
  final _api = ApiService();

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

  String? _selectedGender;
  String? _selectedSegment;
  String _selectedProfession = 'JOB';
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _segments = ['Personal Loan', 'Business Loan', 'Home Loan', 'Credit Cards', 'All', 'Other'];

  @override
  void initState() { super.initState(); _prefill(); }

  Future<void> _prefill() async {
    try {
      final p = await _api.fetchMyProfile();
      if (mounted) {
        if ((p['email'] ?? '').toString().isNotEmpty) _emailController.text = p['email'];
        if ((p['name'] ?? '').toString().isNotEmpty) _nameController.text = p['name'];
        if ((p['mobile'] ?? '').toString().isNotEmpty) _mobileController.text = p['mobile'];
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose(); _mobileController.dispose(); _emailController.dispose(); _companyController.dispose();
    _addressController.dispose(); _currentExpController.dispose(); _totalExpController.dispose();
    _partnerNameController.dispose(); _partnerMobileController.dispose(); _aboutController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final details = {
        'name': _nameController.text, 'mobile': _mobileController.text, 'email': _emailController.text,
        'gender': _selectedGender, 'gumastaUrl': _gumastaUrl, 'company': _companyController.text,
        'address': _addressController.text, 'currentExp': _currentExpController.text, 'totalExp': _totalExpController.text,
        'segment': _selectedSegment, 'profession': _selectedProfession, 'partnerName': _partnerNameController.text,
        'partnerMobile': _partnerMobileController.text, 'about': _aboutController.text, 'role': 'DSA',
      };
      await _api.submitRegistration(role: 'dsa', details: details);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DSA Registration Successful!')));
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const NewHomeScreen()), (route) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed. ' + friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(title: const Text('DSA Registration', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildSectionTitle('DSA Personal Details'),
            _buildFieldLabel('Name *'), _buildTextField(_nameController, 'Enter full name', Icons.person),
            _buildFieldLabel('Mobile No. *'), _buildTextField(_mobileController, 'Enter mobile number', Icons.phone, keyboardType: TextInputType.phone),
            _buildFieldLabel('Mail ID *'), _buildTextField(_emailController, 'Enter email address', Icons.email, keyboardType: TextInputType.emailAddress),
            _buildFieldLabel('Gender *'), _buildDropdownField(_selectedGender, _genders, 'Select Gender', (val) => setState(() => _selectedGender = val)),
            const SizedBox(height: 16),
            FileUploadWidget(label: 'Upload Gumasta License (Optional)', storagePath: 'dsa_gumasta', onUploadComplete: (url) => setState(() => _gumastaUrl = url)),
            const SizedBox(height: 24),
            _buildSectionTitle('Professional Info'),
            _buildFieldLabel('Company Name'), _buildTextField(_companyController, 'Enter company name', Icons.business),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Current Experience'), _buildTextField(_currentExpController, 'Years', Icons.work_history)])),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Total Experience'), _buildTextField(_totalExpController, 'Years', Icons.history)])),
            ]),
            _buildFieldLabel('Profession'), Row(children: [_buildRadioButton('JOB'), _buildRadioButton('SELF')]),
            _buildFieldLabel('Segment'), _buildDropdownField(_selectedSegment, _segments, 'Select Segment', (val) => setState(() => _selectedSegment = val)),
            const SizedBox(height: 24),
            _buildSectionTitle('Partner Reference'),
            _buildFieldLabel('Partner Name'), _buildTextField(_partnerNameController, 'Enter partner name', Icons.person_outline),
            _buildFieldLabel('Partner Mobile No.'), _buildTextField(_partnerMobileController, 'Partner mobile', Icons.phone_android, keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            _buildFieldLabel('Address'), _buildTextField(_addressController, 'Enter address', Icons.location_on, maxLines: 3),
            _buildFieldLabel('About'), _buildTextField(_aboutController, 'Tell us about yourself', Icons.note, maxLines: 3),
            const SizedBox(height: 32),
            CustomButton(text: 'Register DSA', onPressed: _submitForm, isLoading: _isLoading),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF))));
  Widget _buildFieldLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 8.0, top: 8.0), child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)));
  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]), child: TextFormField(controller: controller, keyboardType: keyboardType, maxLines: maxLines, decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: const Color(0xFF4A3AFF), size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)), validator: (value) => (hint.contains('*') && (value == null || value.isEmpty)) ? 'This field is required' : null));
  }
  Widget _buildDropdownField(String? value, List<String> items, String hint, Function(String?) onChanged) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]), child: DropdownButtonHideUnderline(child: DropdownButtonFormField<String>(value: value, hint: Text(hint), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged, decoration: const InputDecoration(border: InputBorder.none), validator: (val) => val == null ? 'Please select an option' : null)));
  }
  Widget _buildRadioButton(String value) => Row(children: [Radio<String>(value: value, groupValue: _selectedProfession, activeColor: const Color(0xFF4A3AFF), onChanged: (val) => setState(() => _selectedProfession = val!)), Text(value), const SizedBox(width: 20)]);
}
