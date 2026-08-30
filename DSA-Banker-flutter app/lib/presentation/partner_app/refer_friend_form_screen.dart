import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReferFriendFormScreen extends StatefulWidget {
  const ReferFriendFormScreen({super.key});

  @override
  State<ReferFriendFormScreen> createState() => _ReferFriendFormScreenState();
}

class _ReferFriendFormScreenState extends State<ReferFriendFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();

  String _relationship = 'Friend';
  String _selectedLoanType = 'Personal Loan';
  bool _hasConsent = false;
  bool _isLoading = false;

  final List<String> _relationships = [
    'Friend',
    'Family',
    'Colleague',
    'Other',
  ];

  final List<String> _loanTypes = [
    'Personal Loan',
    'Home Loan',
    'Business Loan',
    'Mortgage Loan',
    'Car Loan',
    'Commercial Vehicle Loan',
    'CC/OD Limit',
    'Commercial Construction Loan',
    'Education Loan',
    'Gold Loan',
    'Project Loan',
    'Machinery Loan',
    'Others',
  ];

  Future<void> _submitReferral() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please obtain and check the consent box to proceed.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to refer a friend.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('referrals').add({
        'referrer_id': user.uid,
        'friend_name': _nameController.text,
        'friend_mobile': _mobileController.text,
        'friend_email': _emailController.text,
        'relationship': _relationship,
        'loan_type': _selectedLoanType,
        'estimated_amount': _amountController.text,
        'consent_given': _hasConsent,
        'status': 'Invited', // Initial status
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Refer a New Friend',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Full Name *'),
              _buildTextField(
                controller: _nameController,
                hint: 'Friend\'s full name',
                validator: (value) =>
                    value!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Mobile Number *'),
              _buildTextField(
                controller: _mobileController,
                hint: '10-digit mobile number',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value!.isEmpty) return 'Mobile number is required';
                  if (!RegExp(r'^[0-9]{10}$').hasMatch(value))
                    return 'Invalid mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Email Address (Optional)'),
              _buildTextField(
                controller: _emailController,
                hint: 'friend@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _buildLabel('Relationship'),
              _buildDropdown(
                value: _relationship,
                items: _relationships,
                onChanged: (val) => setState(() => _relationship = val!),
              ),
              const SizedBox(height: 16),

              _buildLabel('Loan Type *'),
              _buildDropdown(
                value: _selectedLoanType,
                items: _loanTypes,
                onChanged: (val) => setState(() => _selectedLoanType = val!),
              ),
              const SizedBox(height: 16),

              _buildLabel('Estimated Loan Amount'),
              _buildTextField(
                controller: _amountController,
                hint: 'Enter amount',
                keyboardType: TextInputType.number,
                prefix: '₹ ',
              ),
              const SizedBox(height: 24),

              // Consent Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasConsent
                        ? const Color(0xFF4A3AFF)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _hasConsent,
                      onChanged: (val) => setState(() => _hasConsent = val!),
                      activeColor: const Color(0xFF4A3AFF),
                    ),
                    const Expanded(
                      child: Text(
                        "I have my friend's permission to share their contact details for a loan inquiry.",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReferral,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A3AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Referral',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
