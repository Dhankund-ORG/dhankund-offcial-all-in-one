import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/api_service.dart';

class PersonalLoanFormScreen extends StatefulWidget {
  const PersonalLoanFormScreen({super.key});
  @override
  State<PersonalLoanFormScreen> createState() => _PersonalLoanFormScreenState();
}

class _PersonalLoanFormScreenState extends State<PersonalLoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  final _incomeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() { super.initState(); _prefillUserData(); }

  Future<void> _prefillUserData() async {
    try {
      final p = await _api.fetchMyProfile();
      if (!mounted) return;
      if ((p['email'] ?? '').toString().isNotEmpty) _emailController.text = p['email'].toString();
      if ((p['name'] ?? '').toString().isNotEmpty) _nameController.text = p['name'].toString();
      if ((p['mobile'] ?? '').toString().isNotEmpty) _mobileController.text = p['mobile'].toString();
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose(); _mobileController.dispose(); _emailController.dispose(); _amountController.dispose(); _incomeController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _api.createLoan({
        'loan_type': 'Personal Loan',
        'full_name': _nameController.text.trim(),
        'mobile_number': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
        'loan_amount': _amountController.text.trim(),
        'income': _incomeController.text.trim(),
        'status': 'Pending',
      });
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting application: \$e')));
    }
  }

  void _showSuccessDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0x1A27AE60), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: Color(0xFF27AE60), size: 64)),
            const SizedBox(height: 24),
            const Text('Congratulations', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            const Text('Our Representative will get back to you soon', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.4)),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3AFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Okay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
          ]),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.of(context).pop())),
      body: SafeArea(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _buildHeader(),
        const SizedBox(height: 32),
        _buildFormCard(),
        const SizedBox(height: 24),
      ]))),
    );
  }

  Widget _buildHeader() {
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16), margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4))]), child: Column(children: [
      Container(width: 76, height: 76, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0x1F4A3AFF), width: 1.5)), child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.account_balance, size: 36, color: Color(0xFF4A3AFF))))),
      const SizedBox(height: 12),
      const Text('Dhankund Loan Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: const Color(0x144A3AFF), borderRadius: BorderRadius.circular(20)), child: const Text('Personal Loan Application', style: TextStyle(fontSize: 12, color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold))),
    ]));
  }

  Widget _buildFormCard() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildLabel('Name *'),
      _buildTextField(controller: _nameController, hint: 'Enter your name', validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null),
      const SizedBox(height: 20),
      _buildLabel('Mobile No. *'),
      _buildTextField(controller: _mobileController, hint: 'Enter 10-digit mobile number', keyboardType: TextInputType.phone, validator: (v) => (v == null || !RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) ? 'Please enter a valid 10-digit number' : null),
      const SizedBox(height: 20),
      _buildLabel('Mail ID (Optional)'),
      _buildTextField(controller: _emailController, hint: 'Enter your email address', keyboardType: TextInputType.emailAddress, validator: (v) { if (v != null && v.trim().isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Please enter a valid email address'; return null; }),
      const SizedBox(height: 20),
      _buildLabel('Loan Amount *'),
      _buildTextField(controller: _amountController, hint: 'Enter required loan amount', prefix: 'Rs ', keyboardType: TextInputType.number, validator: (v) { if (v == null || v.trim().isEmpty) return 'Please enter loan amount'; final n = double.tryParse(v.trim()); return (n == null || n <= 0) ? 'Please enter a valid loan amount' : null; }),
      const SizedBox(height: 20),
      _buildLabel('Monthly Income (Optional)'),
      _buildTextField(controller: _incomeController, hint: 'Enter your monthly income', prefix: 'Rs ', keyboardType: TextInputType.number, validator: (v) { if (v == null || v.trim().isEmpty) return null; final n = double.tryParse(v.trim()); return (n == null || n <= 0) ? 'Please enter a valid income' : null; }),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _isLoading ? null : _submitApplication, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3AFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Apply Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
    ]));
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)));

  Widget _buildTextField({required TextEditingController controller, required String hint, String? prefix, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(controller: controller, keyboardType: keyboardType, validator: validator, style: const TextStyle(fontSize: 15, color: Colors.black87), decoration: InputDecoration(
      hintText: hint, prefixText: prefix, prefixStyle: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold), hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4A3AFF), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    ));
  }
}
