import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UserProfileCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String role;

  const UserProfileCard({
    super.key,
    required this.data,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Unknown';
    final company = data['company'] ?? 'No Company';
    final experience = data['totalExp'] ?? '0';
    final mobile = data['mobile'] ?? '';
    final segment = data['segment'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: data['profilePictureUrl'] == null
                        ? const LinearGradient(
                            colors: [Color(0xFF4A3AFF), Color(0xFF6C5DD3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    image: data['profilePictureUrl'] != null
                        ? DecorationImage(
                            image: NetworkImage(data['profilePictureUrl']),
                            fit: BoxFit.cover,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: data['profilePictureUrl'] == null
                      ? const Icon(Icons.person, color: Colors.white, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.verified, color: Colors.blue[400], size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$role • $company",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(Icons.work_outline, "$experience Years Exp"),
                _buildInfoItem(Icons.category_outlined, segment),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4A3AFF).withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Call',
                    icon: Icons.phone,
                    color: const Color(0xFF4A3AFF),
                    onTap: () async {
                      if (mobile.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mobile number not available')),
                        );
                        return;
                      }
                      final Uri launchUri = Uri(
                        scheme: 'tel',
                        path: mobile,
                      );
                      try {
                        await launchUrl(launchUri);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not initiate call: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'WhatsApp',
                    icon: Icons.message,
                    color: const Color(0xFF27AE60),
                    onTap: () async {
                      if (mobile.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mobile number not available')),
                        );
                        return;
                      }
                      // Sanitize phone number (keep only digits)
                      String cleanNumber = mobile.replaceAll(RegExp(r'[^0-9]'), '');
                      if (cleanNumber.length == 10) {
                        cleanNumber = '91$cleanNumber'; // Default to India country code
                      }
                      final Uri whatsappUri = Uri.parse("https://wa.me/$cleanNumber");
                      try {
                        await launchUrl(
                          whatsappUri,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open WhatsApp: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
