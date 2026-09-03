import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_flutter_app/presentation/shared/thank_you_screen.dart';

class LoanApplicationScreen extends StatefulWidget {
  final String loanTitle;

  const LoanApplicationScreen({super.key, required this.loanTitle});

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  final _loanTypeController = TextEditingController(); // New controller
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loanTypeController.text = widget.loanTitle; //  Set initial value
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  Future<void> _submitApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to apply.')),
      );
      // Optional: Navigate to AuthScreen here
      return;
    }

    // Basic field check
    if (_nameController.text.isEmpty ||
        _mobileController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Mobile Validation
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_mobileController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
        ),
      );
      return;
    }

    // Email Validation
    if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(_emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    // Amount Validation
    if (double.tryParse(_amountController.text) == null ||
        double.parse(_amountController.text) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid loan amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('loan_applications').add({
        'user_id': user.uid, // Link to the user
        'loan_type': widget.loanTitle,
        'full_name': _nameController.text,
        'mobile_number': _mobileController.text,
        'email': _emailController.text,
        'loan_amount': _amountController.text,
        'address': _addressController.text,
        'submitted_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ThankYouScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting application: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Loan Application',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Loan Application Form',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please fill in all the required details to proceed with your loan application',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildLabel('Loan Type'),
            _buildTextField(
              controller: _loanTypeController,
              hint: '',
              readOnly: true, // Make it read-only
            ),
            const SizedBox(height: 16),
            _buildLabel('Full Name *'),
            _buildTextField(
              controller: _nameController,
              hint: 'Enter your full name',
            ),
            const SizedBox(height: 16),
            _buildLabel('Mobile Number *'),
            _buildTextField(
              controller: _mobileController,
              hint: 'Enter your 10-digit mobile number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildLabel('Email Address *'),
            _buildTextField(
              controller: _emailController,
              hint: 'Enter your email address',
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildLabel('Loan Amount *'),
            _buildTextField(
              controller: _amountController,
              hint: 'Enter loan amount',
              prefix: '₹ ',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildLabel('Complete Address *'),
            _buildTextField(
              controller: _addressController,
              hint: 'Enter your complete address with city, state and pincode',
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3AFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Application',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'By submitting this form, you agree to our Terms & Conditions and Privacy Policy',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? prefix,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

