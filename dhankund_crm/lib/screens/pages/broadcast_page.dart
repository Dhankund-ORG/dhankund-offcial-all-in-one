import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final FirestoreService _firestoreService = FirestoreService();
  
  bool _sendWhatsapp = true;
  bool _sendEmail = true;
  
  final Map<String, bool> _audiences = {
    'DSAs': false,
    'Bankers': false,
    'Builder Partners': false,
    'Customers': false,
  };

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  bool _isSending = false;
  List<Map<String, dynamic>> _broadcastHistory = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Rebuild UI when text changes for live preview
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await _firestoreService.fetchBroadcastHistory();
    setState(() {
      _broadcastHistory = history;
      _isLoadingHistory = false;
    });
  }

  Future<void> _sendBroadcast() async {
    // Validation
    final selectedAudiences = _audiences.entries.where((e) => e.value).map((e) => e.key).toList();
    if (selectedAudiences.isEmpty) {
      _showError('Please select at least one target audience.');
      return;
    }
    if (!_sendWhatsapp && !_sendEmail) {
      _showError('Please select at least one communication channel.');
      return;
    }
    if (_sendEmail && _subjectController.text.trim().isEmpty) {
      _showError('Email subject is required.');
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _showError('Message body cannot be empty.');
      return;
    }

    setState(() => _isSending = true);

    try {
      // Simulate API delay for Twilio/SendGrid dispatch
      await Future.delayed(const Duration(seconds: 2));

      int estimatedRecipients = selectedAudiences.length * 45; // Mock calculation

      await _firestoreService.createBroadcast(
        audiences: selectedAudiences,
        sendWhatsapp: _sendWhatsapp,
        sendEmail: _sendEmail,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        recipientCount: estimatedRecipients,
      );

      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _audiences.updateAll((key, value) => false);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully broadcasted to $estimatedRecipients recipients!'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );

      _loadHistory();
    } catch (e) {
      _showError('Failed to send broadcast: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.rubyRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Compose Form
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: AppTheme.glassDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.campaign, color: AppTheme.royalGold, size: 28),
                        SizedBox(width: 12),
                        Text('Compose Broadcast', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reach thousands of partners and customers instantly via WhatsApp and Email.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
            
                    // Target Audience
                    const Text('1. TARGET AUDIENCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _audiences.keys.map((key) {
                        final isSelected = _audiences[key]!;
                        return InkWell(
                          onTap: () => setState(() => _audiences[key] = !isSelected),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.royalGold.withOpacity(0.15) : AppTheme.obsidianLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? AppTheme.royalGold : Colors.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, 
                                     color: isSelected ? AppTheme.royalGold : AppTheme.textSecondary, size: 18),
                                const SizedBox(width: 8),
                                Text(key, style: TextStyle(
                                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
            
                    // Channels
                    const Text('2. DELIVERY CHANNELS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildChannelToggle('WhatsApp', Icons.chat, _sendWhatsapp, (val) => setState(() => _sendWhatsapp = val)),
                        _buildChannelToggle('Email Blast', Icons.email, _sendEmail, (val) => setState(() => _sendEmail = val)),
                      ],
                    ),
                    const SizedBox(height: 32),
            
                    // Message Content
                    const Text('3. MESSAGE CONTENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    if (_sendEmail) ...[
                      TextFormField(
                        controller: _subjectController,
                        decoration: InputDecoration(
                          labelText: 'Email Subject',
                          hintText: 'e.g. Important Update: New Payout Slabs',
                          prefixIcon: const Icon(Icons.title, color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.obsidianLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _messageController,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: 'Message Body',
                        alignLabelWithHint: true,
                        hintText: 'Type your message here. Variables like {{name}} will be dynamically replaced.',
                        filled: true,
                        fillColor: AppTheme.obsidianLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSending ? null : _sendBroadcast,
                        icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.obsidianDark, strokeWidth: 2)) : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSending ? 'DISPATCHING...' : 'SEND BULK BROADCAST',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.royalGold,
                          foregroundColor: AppTheme.obsidianDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          
          // Right Column: Preview & History
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Preview Panel
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: AppTheme.glassDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.preview_outlined, color: AppTheme.textSecondary, size: 20),
                          SizedBox(width: 8),
                          Text('WHATSAPP PREVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.0)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCF8C6), // WhatsApp green tint
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          _messageController.text.isEmpty ? 'Your message will appear here...' : _messageController.text,
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // History Panel
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: AppTheme.glassDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('RECENT BROADCASTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0)),
                            Icon(Icons.history, color: AppTheme.royalGold, size: 18),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _isLoadingHistory
                              ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                              : _broadcastHistory.isEmpty
                                  ? const Center(child: Text('No broadcast history found.', style: TextStyle(color: AppTheme.textSecondary)))
                                  : ListView.separated(
                                      itemCount: _broadcastHistory.length,
                                      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                                      itemBuilder: (context, index) {
                                        final item = _broadcastHistory[index];
                                        final ts = item['timestamp'] as Timestamp?;
                                        final dateStr = ts != null 
                                          ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                                          : 'Just now';
                                        
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item['subject']?.isNotEmpty == true ? item['subject'] : 'No Subject',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(dateStr, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  if (item['send_whatsapp'] == true)
                                                    const Padding(
                                                      padding: EdgeInsets.only(right: 8.0),
                                                      child: Icon(Icons.chat, size: 14, color: AppTheme.emeraldGreen),
                                                    ),
                                                  if (item['send_email'] == true)
                                                    const Padding(
                                                      padding: EdgeInsets.only(right: 8.0),
                                                      child: Icon(Icons.email, size: 14, color: Colors.blue),
                                                    ),
                                                  Text('${item['recipient_count']} Recipients', style: const TextStyle(fontSize: 12, color: AppTheme.royalGold)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelToggle(String label, IconData icon, bool isActive, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!isActive),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.royalGold.withOpacity(0.15) : AppTheme.obsidianLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppTheme.royalGold : Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppTheme.royalGold : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            )),
            const SizedBox(width: 12),
            Switch(
              value: isActive,
              onChanged: onChanged,
              activeColor: AppTheme.royalGold,
              activeTrackColor: AppTheme.royalGold.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
