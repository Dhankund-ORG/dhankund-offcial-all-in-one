import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class SecureDeleteDialog extends StatefulWidget {
  final String title;
  final String content;
  final Future<void> Function() onDeleteConfirmed;

  const SecureDeleteDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onDeleteConfirmed,
  });

  @override
  State<SecureDeleteDialog> createState() => _SecureDeleteDialogState();
}

class _SecureDeleteDialogState extends State<SecureDeleteDialog> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate Admin
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        
        // Authentication successful, proceed with deletion
        await widget.onDeleteConfirmed();
        
        if (mounted) {
          Navigator.of(context).pop(true); // Return true indicating success
        }
      } else {
        setState(() => _errorMessage = 'Admin not logged in.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Re-authentication failed: $e");
      setState(() {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _errorMessage = 'Incorrect password. Deletion denied.';
        } else {
          _errorMessage = 'Authentication failed: ${e.message}';
        }
      });
    } catch (e) {
      debugPrint("Delete operation failed: $e");
      setState(() => _errorMessage = 'An error occurred during deletion.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.obsidianMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.rubyRed, width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.rubyRed, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.rubyRed),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.content,
              style: const TextStyle(color: AppTheme.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter Admin Password to Confirm:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Admin Password',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppTheme.obsidianLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              onSubmitted: (_) => _handleDelete(),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.rubyRed, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.rubyRed,
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Secure Delete'),
        ),
      ],
    );
  }
}
