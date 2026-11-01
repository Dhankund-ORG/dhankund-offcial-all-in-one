import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:io' as io;

import 'package:my_flutter_app/services/api_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/cloudflare_r2_service.dart';
import 'package:my_flutter_app/presentation/auth/welcome_screen.dart';
import 'package:my_flutter_app/presentation/shared/edit_profile_screen.dart';
import 'package:my_flutter_app/presentation/shared/manage_banners_screen.dart' as manage_banners;

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isUploading = false;
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  final _api = ApiService();

  bool _isBiometricEnabled = false;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLocalPreferences();
  }

  Future<void> _loadLocalPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
          _selectedLanguage = prefs.getString('app_language') ?? 'English';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _api.fetchMyProfile();
      if (mounted) {
        setState(() {
          _profile = p;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      Uint8List? rawBytes = file.bytes;
      if (rawBytes == null && file.path != null) {
        rawBytes = await io.File(file.path!).readAsBytes();
      }
      if (rawBytes == null) {
        throw Exception("Could not read image file bytes.");
      }

      final croppedBytes = await Navigator.push<Uint8List?>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropScreen(initialBytes: rawBytes!),
        ),
      );

      if (croppedBytes == null) return;

      setState(() => _isUploading = true);
      final downloadUrl = await CloudflareR2Service().uploadFile(
        bytes: croppedBytes,
        folderPath: 'profile_pictures',
        extension: 'png',
      );

      if (downloadUrl == null) {
        throw Exception("Failed to upload image to cloud storage. Please try again.");
      }

      await _api.updateProfile({'profilePictureUrl': downloadUrl});

      if (mounted) {
        setState(() {
          _profile['profilePictureUrl'] = downloadUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF27AE60),
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile picture updated successfully!'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to update profile picture: ' + friendlyErrorMessage(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatSinceDate(dynamic dateVal) {
    if (dateVal == null || dateVal.toString().isEmpty) return 'Nov 2026';
    try {
      final dt = DateTime.parse(dateVal.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateVal.toString();
    }
  }

  void _showUpdateMpinDialog() {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Color(0xFF093A7A)),
            SizedBox(width: 8),
            Text('Update MPIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create a 4-digit security PIN to quickly and securely unlock your Dhankund app.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'New 4-Digit MPIN',
                  prefixIcon: const Icon(Icons.pin, color: Color(0xFF093A7A)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.length != 4) return 'Please enter 4 digits';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Confirm New MPIN',
                  prefixIcon: const Icon(Icons.check, color: Color(0xFF093A7A)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val != newPinController.text) return 'PIN does not match';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('app_mpin', newPinController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF27AE60),
                      content: Text('MPIN updated successfully! Use this to open app.'),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF093A7A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Update PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    setState(() {
      _isBiometricEnabled = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Biometric authentication enabled' : 'Biometric authentication disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showFaqsDialog() {
    final faqs = [
      {'q': 'What loan services does Dhankund offer?', 'a': 'Dhankund offers Personal Loans, Business Loans, Home Loans, Loan Against Property (LAP), Commercial Vehicle Loans, and Loan Transfers with top banks and NBFCs.'},
      {'q': 'How quickly are referrals and payouts processed?', 'a': 'Once your referred client completes loan disbursal, payout commission is automatically approved and credited to your verified bank account.'},
      {'q': 'How do I complete KYC & Bank details?', 'a': 'Navigate to your profile or KYC screen to upload PAN, Aadhaar, and bank account proof for instant digital verification.'},
      {'q': 'Is my data secure with Dhankund?', 'a': 'Yes, Dhankund utilizes encrypted Cloudflare edge storage and secure authentication ensuring complete privacy of all financial records.'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.help_outline, color: Color(0xFF093A7A)),
                  SizedBox(width: 8),
                  Text('Frequently Asked Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF093A7A))),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: faqs.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, i) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(faqs[i]['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(faqs[i]['a']!, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpSupportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Dhankund Help & Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF093A7A))),
            const SizedBox(height: 6),
            const Text('We are available 24x7 to assist you with loan queries and technical help.', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.email_outlined, color: Colors.blue)),
              title: const Text('Email Support', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('info@dhankund.com'),
              onTap: () async {
                final uri = Uri.parse('mailto:info@dhankund.com?subject=Support%20Request%20-%20Dhankund%20App');
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF27AE60).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.phone_outlined, color: Color(0xFF27AE60))),
              title: const Text('Customer Helpline', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('+91 91799 99999 / +91 98260 00000'),
              onTap: () async {
                final uri = Uri.parse('tel:+919179999999');
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Language / भाषा चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English (Default)', style: TextStyle(fontWeight: FontWeight.w600)),
              value: 'English',
              groupValue: _selectedLanguage,
              activeColor: const Color(0xFF093A7A),
              onChanged: (val) async {
                if (val != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_language', val);
                  setState(() => _selectedLanguage = val);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('हिंदी (Hindi)', style: TextStyle(fontWeight: FontWeight.w600)),
              value: 'Hindi',
              groupValue: _selectedLanguage,
              activeColor: const Color(0xFF093A7A),
              onChanged: (val) async {
                if (val != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_language', val);
                  setState(() => _selectedLanguage = val);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _inviteFriends() {
    final customId = _profile['customerId'] ?? _profile['partnerId'] ?? _profile['customId'] ?? 'DK100';
    final inviteText = 'Apply for instant loans and track financial services on Dhankund Global App! Use my referral code: $customId. Download here: https://dhankund.com/app';
    Clipboard.setData(ClipboardData(text: inviteText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF093A7A),
        content: Row(
          children: [
            Icon(Icons.share, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('Invitation link and referral code copied! Share with friends.')),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF093A7A)))
          : RefreshIndicator(
              color: const Color(0xFF093A7A),
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 20),
                    _buildFullDetailsSection(),
                    const SizedBox(height: 20),
                    _buildPersonalDetailsSection(),
                    const SizedBox(height: 20),
                    _buildOtherSection(),
                    const SizedBox(height: 20),
                    _buildAccountStatsSection(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final name = (_profile['name'] ?? ApiClient.currentUserName ?? 'User Name').toString();
    final role = (_profile['role'] ?? ApiClient.currentUserRole ?? 'Partner').toString();
    final isCustomer = role.toLowerCase().contains('customer');

    final String idLabel = isCustomer ? 'Customer ID' : 'Partner ID';
    final String sinceLabel = isCustomer ? 'Customer Since' : 'Partner Since';

    final String uniqueId = isCustomer
        ? (_profile['customerId'] ?? _profile['customId'] ?? 'CUST-100234').toString()
        : (_profile['partnerId'] ?? _profile['customId'] ?? 'DK-PTR-100234').toString();

    final String sinceDate = _formatSinceDate(_profile['sinceDate'] ?? _profile['createdAt']);
    final profilePicUrl = _profile['profilePictureUrl'] as String?;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      child: Column(
        children: [
          // Top action bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF093A7A)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        fullData: _profile,
                        collectionName: '',
                        uid: ApiClient.currentUserId ?? _profile['id']?.toString() ?? '',
                      ),
                    ),
                  );
                  if (updated == true) _loadProfile();
                },
                icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                label: const Text('Edit Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF093A7A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Profile Picture with Camera Badge
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF093A7A).withOpacity(0.2), width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty)
                        ? NetworkImage(profilePicUrl)
                        : null,
                    child: (profilePicUrl == null || profilePicUrl.isEmpty)
                        ? const Icon(Icons.person, size: 54, color: Color(0xFF093A7A))
                        : null,
                  ),
                ),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
                if (!_isUploading)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFF093A7A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // User Name
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1F)),
          ),
          const SizedBox(height: 6),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF093A7A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(color: Color(0xFF093A7A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 18),

          // 4. Role-Specific ID and Since Date Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(idLabel.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              uniqueId,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF093A7A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: uniqueId));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$idLabel copied!'), duration: const Duration(seconds: 1)));
                            },
                            child: const Icon(Icons.copy, size: 13, color: Color(0xFF093A7A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(sinceLabel.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(
                        sinceDate,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullDetailsSection() {
    final mobile = (_profile['mobile'] ?? ApiClient.currentUserMobile ?? 'Not provided').toString();
    final altMobile = (_profile['alternateMobile'] ?? _profile['alternate_mobile'] ?? 'Not provided').toString();
    final email = (_profile['email'] ?? ApiClient.currentUserEmail ?? 'Not provided').toString();
    final dob = (_profile['dob'] ?? 'Not provided').toString();
    final pan = (_profile['panNumber'] ?? _profile['pan_number'] ?? _profile['kycPan'] ?? 'Not provided').toString().toUpperCase();
    final address = (_profile['address'] ?? _profile['current_address'] ?? 'Not provided').toString();
    final company = (_profile['companyName'] ?? _profile['company'] ?? 'Not provided').toString();
    final companyAddress = (_profile['companyAddress'] ?? _profile['company_address'] ?? _profile['officeAddress'] ?? 'Not provided').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FULL DETAILS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                _buildTile(Icons.phone_outlined, 'Mobile Number', mobile),
                const Divider(height: 1, indent: 60),
                _buildTile(Icons.phone_android_outlined, 'Alternate Mobile Number', altMobile),
                const Divider(height: 1, indent: 60),
                _buildTile(Icons.email_outlined, 'Email ID', email),
                const Divider(height: 1, indent: 60),
                _buildTile(Icons.calendar_today_outlined, 'Date of Birth', dob),
                const Divider(height: 1, indent: 60),
                _buildTile(Icons.credit_card_outlined, 'Pan Card Number', pan),
                const Divider(height: 1, indent: 60),
                _buildTile(Icons.home_outlined, 'Address', address),
                const Divider(height: 1, indent: 60),
                _buildTile(Icons.business_outlined, 'Company Name', company),
                const Divider(height: 1, indent: 60),
                _buildTile(Icons.location_city_outlined, 'Company Address', companyAddress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERSONAL DETAILS & SECURITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                // MPIN Update
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF093A7A).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.pin_outlined, color: Color(0xFF093A7A), size: 20),
                  ),
                  title: const Text('MPIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('App unlock security pin', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: ElevatedButton(
                    onPressed: _showUpdateMpinDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF093A7A),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const Divider(height: 1, indent: 60),

                // Enable Biometric
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF27AE60).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.fingerprint, color: Color(0xFF27AE60), size: 20),
                  ),
                  title: const Text('Enable Biometric', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(_isBiometricEnabled ? 'Biometric login is ON' : 'Biometric login is OFF', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Switch(
                    value: _isBiometricEnabled,
                    activeColor: const Color(0xFF27AE60),
                    onChanged: _toggleBiometric,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OTHER PREFERENCES & SUPPORT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                // FAQs
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0984E3).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.help_outline, color: Color(0xFF0984E3), size: 20)),
                  title: const Text('FAQs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Frequently asked questions & solutions', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: _showFaqsDialog,
                ),
                const Divider(height: 1, indent: 60),

                // Help & Support
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE17055).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.support_agent, color: Color(0xFFE17055), size: 20)),
                  title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Contact helpline or email info@dhankund.com', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: _showHelpSupportDialog,
                ),
                const Divider(height: 1, indent: 60),

                // Language
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.translate, color: Color(0xFF6C5CE7), size: 20)),
                  title: const Text('Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Selected: $_selectedLanguage (English/Hindi)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: _showLanguageDialog,
                ),
                const Divider(height: 1, indent: 60),

                // Invite Friends
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE84393).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.card_giftcard, color: Color(0xFFE84393), size: 20)),
                  title: const Text('Invite Friends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Share Dhankund app with peers and earn rewards', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.share, size: 18, color: Color(0xFF093A7A)),
                  onTap: _inviteFriends,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACCOUNT STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildTile(
                  Icons.verified_user_outlined,
                  'KYC Verification',
                  (_profile['kycCompleted'] == true) ? 'Verified' : 'Pending Verification',
                ),
                const Divider(height: 1, indent: 60),
                _buildTile(
                  Icons.account_balance_outlined,
                  'Bank Account Details',
                  (_profile['bankDetailsCompleted'] == true) ? 'Linked' : 'Not Linked',
                ),
                if (ApiClient.currentUserRole?.toLowerCase() == 'admin' || _profile['role']?.toString().toLowerCase() == 'admin') ...[
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF27AE60).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.view_carousel, color: Color(0xFF27AE60), size: 20)),
                    title: const Text('Manage Banners', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const manage_banners.ManageBannersScreen())),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF093A7A).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF093A7A), size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () async {
          await AuthService().logout();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (route) => false,
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.red,
          elevation: 0,
          side: const BorderSide(color: Colors.redAccent, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 52),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 18),
            SizedBox(width: 8),
            Text('Logout Session', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class ImageCropScreen extends StatefulWidget {
  final Uint8List initialBytes;
  const ImageCropScreen({super.key, required this.initialBytes});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final GlobalKey _cropKey = GlobalKey();
  bool _isCropping = false;
  int _rotationQuarterTurns = 0;

  Future<void> _cropAndReturn() async {
    setState(() => _isCropping = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      RenderRepaintBoundary? boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Could not find repaint boundary");
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Could not convert image to bytes");
      Uint8List croppedBytes = byteData.buffer.asUint8List();
      if (mounted) Navigator.pop(context, croppedBytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not crop image. Please try again.')));
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  void _rotate() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Position & Rotate Photo', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right, color: Colors.white),
            tooltip: 'Rotate 90°',
            onPressed: _rotate,
          ),
          if (!_isCropping)
            TextButton(
              onPressed: _cropAndReturn,
              child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 1)),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              key: _cropKey,
                              child: InteractiveViewer(
                                boundaryMargin: const EdgeInsets.all(double.infinity),
                                minScale: 1.0,
                                maxScale: 5.0,
                                child: RotatedBox(
                                  quarterTurns: _rotationQuarterTurns,
                                  child: Image.memory(widget.initialBytes, fit: BoxFit.contain),
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: Positioned.fill(
                              child: CustomPaint(painter: CropOverlayPainter()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                color: Colors.black87,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _rotate,
                            icon: const Icon(Icons.rotate_right, color: Colors.white),
                            label: const Text('Rotate 90°', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Pinch to Zoom & Drag to Position', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(
                        'The circle area will be saved as your profile picture.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isCropping) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.5);
    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()..addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2));
    final path = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(path, paint);
    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
