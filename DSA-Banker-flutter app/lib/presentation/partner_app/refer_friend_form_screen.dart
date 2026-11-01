import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/api_service.dart';
import 'package:my_flutter_app/presentation/shared/thank_you_screen.dart';
import 'package:my_flutter_app/presentation/shared/file_upload_widget.dart';

class ReferFriendFormScreen extends StatefulWidget {
  const ReferFriendFormScreen({super.key});
  @override
  State<ReferFriendFormScreen> createState() => _ReferFriendFormScreenState();
}

class _ReferFriendFormScreenState extends State<ReferFriendFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _loanAmountController = TextEditingController();
  String? _selectedRelationship;
  String? _selectedLoanType;
  String? _documentUrl;
  bool _consentGiven = false;
  bool _isLoading = false;
  final List<String> _relationships = ['Friend', 'Colleague', 'Family', 'Relative', 'Neighbor', 'Acquaintance'];
  final List<String> _loanTypes = ['Personal Loan', 'Business Loan', 'Home Loan', 'Auto Loan', 'Credit Card', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _loanAmountController.dispose();
    super.dispose();
  }

  Future<void> _submitReferral() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please give consent to refer')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _api.createReferral(
        friendName: _nameController.text.trim(),
        friendMobile: _mobileController.text.trim(),
        friendEmail: _emailController.text.trim(),
        relationship: _selectedRelationship ?? 'Friend',
        loanType: _selectedLoanType ?? 'Personal Loan',
        estimatedAmount: _loanAmountController.text.trim(),
        consentGiven: true,
        documentUrl: _documentUrl,
        status: 'Invited',
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ThankYouScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text('Refer a Friend', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.of(context).pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A3AFF), Color(0xFF6C5CE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4A3AFF).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'UNLIMITED EARNINGS',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Refer a friend and earn Unlimited payout for each successful referral!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Instant lead registration with dedicated Lead ID & zero TAT delay',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel('Friend Name *'),
            _buildTextField(_nameController, 'Enter your friend name', icon: Icons.person),
            const SizedBox(height: 16),
            _buildLabel('Friend Mobile No. *'),
            _buildTextField(_mobileController, 'Enter mobile number', icon: Icons.phone, keyboardType: TextInputType.phone, validator: (v) => (v == null || !RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) ? 'Enter valid 10-digit number' : null),
            const SizedBox(height: 16),
            _buildLabel('Friend Email (Optional)'),
            _buildTextField(_emailController, 'Enter email address', icon: Icons.email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildLabel('Relationship *'),
            _buildDropdown(_selectedRelationship, _relationships, 'Select Relationship', (v) => setState(() => _selectedRelationship = v)),
            const SizedBox(height: 16),
            _buildLabel('Loan Type *'),
            _buildDropdown(_selectedLoanType, _loanTypes, 'Select Loan Type', (v) => setState(() => _selectedLoanType = v)),
            const SizedBox(height: 16),
            _buildLabel('Estimated Loan Amount (Optional)'),
            _buildTextField(
              _loanAmountController,
              'Enter estimated amount in ₹',
              prefixWidget: Container(
                width: 44,
                alignment: Alignment.center,
                child: const Text('₹', style: TextStyle(color: Color(0xFF4A3AFF), fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            
            // Document upload section
            _buildLabel('Attach Documents (Optional)'),
            Text(
              'Upload KYC, Salary slip or Business documents to speed up loan processing.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            FileUploadWidget(
              label: _documentUrl == null ? 'Upload Document (PDF, JPG, PNG)' : 'Change Document',
              storagePath: 'referrals/documents',
              onUploadComplete: (url) {
                setState(() {
                  _documentUrl = url;
                });
              },
            ),
            if (_documentUrl != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Document uploaded successfully',
                        style: TextStyle(color: Color(0xFF27AE60), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _documentUrl = null),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consentGiven,
              onChanged: (v) => setState(() => _consentGiven = v ?? false),
              title: const Text("I have my friend's consent to share their details", style: TextStyle(fontSize: 14)),
              activeColor: const Color(0xFF4A3AFF),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReferral,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3AFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Submit Referral', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
    ),
  );

  Widget _buildTextField(TextEditingController controller, String hint, {IconData? icon, Widget? prefixWidget, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixWidget ?? (icon != null ? Icon(icon, color: const Color(0xFF4A3AFF)) : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdown(String? value, List<String> items, String hint, Function(String?) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 5, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint),
        decoration: const InputDecoration(border: InputBorder.none),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Please select' : null,
      ),
    );
  }
}
