import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  int _step = 0; // 0=email, 1=otp, 2=new password
  bool _loading = false;
  String? _error;
  String? _resetToken;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() { _error = 'Please enter a valid email'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    final err = await _auth.forgotPassword(email);
    setState(() { _loading = false; });
    if (err != null) {
      setState(() { _error = err; });
    } else {
      setState(() { _step = 1; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your email')));
      }
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() { _error = 'Please enter the 6-digit OTP'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await _auth.verifyOtp(email, otp);
    setState(() { _loading = false; });
    if (result != null && result['error'] != null) {
      setState(() { _error = result['error'].toString(); });
    } else if (result != null && result['reset_token'] != null) {
      setState(() { _resetToken = result['reset_token'].toString(); _step = 2; });
    } else {
      setState(() { _error = 'OTP verification failed'; });
    }
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (password.length < 6) {
      setState(() { _error = 'Password must be at least 6 characters'; });
      return;
    }
    if (password != confirm) {
      setState(() { _error = 'Passwords do not match'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    final err = await _auth.resetPassword(_resetToken!, password);
    setState(() { _loading = false; });
    if (err != null) {
      setState(() { _error = err; });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully! Please login.'), backgroundColor: Colors.green));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
        if (_step > 0) { setState(() { _step = _step - 1; }); } else { Navigator.pop(context); }
      })),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              if (_step == 0) ...[
                Icon(Icons.lock_reset, size: 64, color: Colors.deepPurple.shade300),
                const SizedBox(height: 16),
                Text('Enter your email and we will send you an OTP to reset your password.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 32),
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 24),
                _buildButton('Send OTP', _sendOtp),
              ],
              if (_step == 1) ...[
                Icon(Icons.password, size: 64, color: Colors.deepPurple.shade300),
                const SizedBox(height: 16),
                Text('Enter the 6-digit OTP sent to ' + _emailController.text.trim(), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 32),
                TextField(controller: _otpController, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 8), decoration: InputDecoration(counterText: '', labelText: 'OTP', prefixIcon: const Icon(Icons.pin_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 24),
                _buildButton('Verify OTP', _verifyOtp),
                const SizedBox(height: 16),
                TextButton(onPressed: _loading ? null : _sendOtp, child: const Text('Resend OTP')),
              ],
              if (_step == 2) ...[
                Icon(Icons.lock_open, size: 64, color: Colors.deepPurple.shade300),
                const SizedBox(height: 16),
                Text('Set a new password for your account.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 32),
                TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'New Password', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: _confirmPasswordController, obscureText: true, decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 24),
                _buildButton('Reset Password', _resetPassword),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _loading ? null : onPressed, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
  }
}