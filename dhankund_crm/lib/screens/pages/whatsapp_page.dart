import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../whatsapp_service.dart';
import 'whatsapp_broadcast_page.dart';
import 'whatsapp_inbox_page.dart';
import 'whatsapp_templates_page.dart';

/// One WhatsApp entry in the sidebar. Everything WhatsApp lives behind it:
/// the inbox, the template manager and broadcasts, switched with a top menu.
class WhatsappPage extends StatefulWidget {
  const WhatsappPage({super.key});

  @override
  State<WhatsappPage> createState() => _WhatsappPageState();
}

class _WhatsappPageState extends State<WhatsappPage> with SingleTickerProviderStateMixin {
  final WhatsAppService _service = WhatsAppService();
  late final AnimationController _indicator;

  int _tab = 0;
  bool _configured = false;
  bool _statusKnown = false;
  String? _phoneHint;
  int _contacts = 0;
  int _activeCampaigns = 0;

  static const List<_WaTab> _tabs = [
    _WaTab('Inbox', Icons.forum_outlined),
    _WaTab('Templates', Icons.description_outlined),
    _WaTab('Broadcast', Icons.campaign_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _indicator = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 0);
    _loadStatus();
  }

  @override
  void dispose() {
    _indicator.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _service.fetchStatus();
      if (!mounted) return;
      setState(() {
        _configured = status['configured'] == true;
        _statusKnown = true;
        _phoneHint = status['phone_number_id']?.toString();
        _contacts = (status['contacts'] as num?)?.toInt() ?? 0;
        _activeCampaigns = (status['active_broadcasts'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusKnown = true);
    }
  }

  void _select(int index) {
    setState(() => _tab = index);
    _indicator.animateTo(index.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              WhatsappInboxPage(),
              WhatsappTemplatesPage(),
              WhatsappBroadcastPage(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.royalGold.withValues(alpha: 0.07),
            AppTheme.brightGold.withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFFE6ECF3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.royalGold, AppTheme.brightGold]),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WhatsApp',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text(
                    _configured
                        ? 'Connected${_phoneHint != null ? ' · …$_phoneHint' : ''} · $_contacts contacts'
                        : (_statusKnown ? 'Not configured — add the Worker secrets' : 'Checking connection…'),
                    style: TextStyle(
                      fontSize: 11,
                      color: _configured ? AppTheme.emeraldGreen : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (_activeCampaigns > 0)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.brightGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 8, height: 8,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brightGold),
                      ),
                      const SizedBox(width: 6),
                      Text('$_activeCampaigns running',
                          style: const TextStyle(fontSize: 10, color: AppTheme.brightGold, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              IconButton(
                tooltip: 'Refresh status',
                onPressed: _loadStatus,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _tabBar(),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Row(
              children: List.generate(_tabs.length, (index) {
                final selected = _tab == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _select(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.obsidianMedium : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? const Color(0xFFE1E8F0) : Colors.transparent,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(_tabs[index].icon,
                              size: 16, color: selected ? AppTheme.royalGold : AppTheme.textSecondary),
                          const SizedBox(width: 7),
                          Text(
                            _tabs[index].label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                            ),
                          ),
                          if (index == 2 && _activeCampaigns > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(color: AppTheme.emeraldGreen, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Thin accent line under the active tab, animated between positions.
            Positioned(
              bottom: 0,
              left: 0,
              child: AnimatedBuilder(
                animation: _indicator,
                builder: (_, __) {
                  return Container(
                    height: 2.5,
                    width: 64,
                    margin: EdgeInsets.only(left: _indicator.value * 112 + 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.royalGold, AppTheme.brightGold]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaTab {
  final String label;
  final IconData icon;
  const _WaTab(this.label, this.icon);
}
