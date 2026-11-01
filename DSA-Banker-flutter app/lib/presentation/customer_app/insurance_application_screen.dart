import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/services/api_service.dart';

class InsuranceApplicationScreen extends StatefulWidget {
  final String insuranceType;

  const InsuranceApplicationScreen({
    super.key,
    required this.insuranceType,
  });

  @override
  State<InsuranceApplicationScreen> createState() => _InsuranceApplicationScreenState();
}

class _InsuranceApplicationScreenState extends State<InsuranceApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  bool _isSubmitting = false;

  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _yearlyIncomeController;
  String _selectedDependents = '2';
  String _selectedOccupation = 'Salaried';

  final List<String> _dependentsList = ['0', '1', '2', '3', '4', '5+'];
  final List<String> _occupationList = [
    'Salaried',
    'Self-Employed Professional',
    'Business Owner',
    'Trader / Retailer',
    'Agriculture',
    'Retired',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ApiClient.currentUserName ?? '');
    _dobController = TextEditingController();
    _mobileController = TextEditingController(text: ApiClient.currentUserMobile ?? '');
    _emailController = TextEditingController(text: ApiClient.currentUserEmail ?? '');
    _addressController = TextEditingController();
    _yearlyIncomeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _yearlyIncomeController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
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
      setState(() => _dobController.text = formatted);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await _api.submitInsuranceApplication({
        'insurance_type': widget.insuranceType,
        'name': _nameController.text.trim(),
        'dob': _dobController.text.trim(),
        'mobile_number': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'yearly_income': _yearlyIncomeController.text.trim(),
        'dependents': _selectedDependents,
        'occupation': _selectedOccupation,
      });

      if (!mounted) return;
      _showSuccessPopup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Failed to submit application: ' + friendlyErrorMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 54),
            ),
            const SizedBox(height: 20),
            const Text(
              'आवेदन सफलतापूर्वक प्राप्त हुआ!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1F)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Text(
                    'धन्यवाद! आपके ${widget.insuranceType} आवेदन के संबंध में हमारे बीमा प्रतिनिधि २ घंटे के भीतर आपसे संपर्क कर लेंगे।',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '(Our insurance representative will contact you within 2 hours to provide tailored coverage and premium options.)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to dashboard
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF093A7A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text('ठीक है / OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Apply for ${widget.insuranceType}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF093A7A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF093A7A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF093A7A), Color(0xFF0984E3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.insuranceType,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Get instant quotes & dedicated support within 2 hours.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Name
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            icon: Icons.person_outline,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter full name' : null,
                          ),
                          const SizedBox(height: 16),

                          // 2. DOB
                          _buildDateField(),
                          const SizedBox(height: 16),

                          // 3. Mobile Number
                          _buildTextField(
                            controller: _mobileController,
                            label: 'Mobile Number',
                            hint: 'Enter 10-digit mobile number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (val) {
                              if (val == null || val.trim().length != 10) return 'Please enter valid 10-digit mobile';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // 4. Mail ID
                          _buildTextField(
                            controller: _emailController,
                            label: 'Mail ID',
                            hint: 'e.g. yourname@gmail.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || !val.contains('@')) return 'Please enter valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // 5. Address
                          _buildTextField(
                            controller: _addressController,
                            label: 'Current Address',
                            hint: 'House/Flat No, Street, City, State, PIN',
                            icon: Icons.home_outlined,
                            maxLines: 2,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter address' : null,
                          ),
                          const SizedBox(height: 16),

                          // 6. Yearly income
                          _buildTextField(
                            controller: _yearlyIncomeController,
                            label: 'Yearly Income (₹)',
                            hint: 'e.g. ₹ 6,00,000',
                            icon: Icons.currency_rupee,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter yearly income' : null,
                          ),
                          const SizedBox(height: 16),

                          // 7. Dependents
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dependents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1F))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedDependents,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.people_outline, color: Color(0xFF093A7A), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                items: _dependentsList.map((d) => DropdownMenuItem(value: d, child: Text('$d Family Member(s)'))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedDependents = val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 8. Occupation
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Occupation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1F))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedOccupation,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.work_outline, color: Color(0xFF093A7A), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                items: _occupationList.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedOccupation = val);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF093A7A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Submit Application', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
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
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
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
        const Text('Date of Birth (DOB)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1F))),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDob,
          child: IgnorePointer(
            child: TextFormField(
              controller: _dobController,
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please select date of birth' : null,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'DD-MM-YYYY (Click to select)',
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
