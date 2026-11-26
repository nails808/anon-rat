import 'package:flutter/material.dart';
import '../agent/agent_loop.dart';
import '../services/api.dart';
import '../services/c2.dart';
import '../theme/anon_theme.dart';
import '../widgets/brand_header.dart';

class _Protection {
  _Protection(this.id, this.title, this.subtitle, this.icon, {this.on = true});
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  bool on;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    required this.user,
    required this.agent,
    required this.c2,
    required this.onLogout,
  });

  final ApiService api;
  final AnonUser user;
  final AgentLoop agent;
  final C2Client c2;
  final VoidCallback onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final List<_Protection> items;
  String agentStatus = 'protected';
  String? deviceId;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    items = [
      _Protection('fingerprint', 'Fingerprint Spoofing', 'Masks browser & device identity', Icons.fingerprint),
      _Protection('proxy', 'Anonymous Proxy', 'Routes traffic through a secure network', Icons.public),
      _Protection('location', 'Location Obfuscation', 'Displays approximate location only', Icons.location_on_outlined),
      _Protection('agent', 'User-Agent Rotation', 'Randomises browser & OS signatures', Icons.sync),
      _Protection('dns', 'DNS Protection', 'Blocks DNS leak vectors', Icons.lock_outline),
      _Protection('tracker', 'Tracker Shield', 'Stops known ad & analytics domains', Icons.block),
    ];
    widget.agent.onStatus = (s) {
      if (mounted) setState(() => agentStatus = s);
    };
    widget.c2.deviceId().then((id) {
      if (mounted) setState(() => deviceId = id);
    });
  }

  int get _score => items.where((e) => e.on).length;

  @override
  Widget build(BuildContext context) {
    final allOn = items.every((e) => e.on);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.7),
            radius: 1.2,
            colors: [Color(0xFF2A1450), Color(0xFF100C1B), AnonColors.bg],
            stops: [0, 0.35, 0.8],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AnonColors.purple.withOpacity(0.5)),
                        color: const Color(0xFF1A1228),
                      ),
                      child: const Icon(Icons.person_outline, size: 18, color: AnonColors.purpleSoft),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.user.email,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                          Text(allOn ? 'Protection active' : 'Review recommended',
                              style: TextStyle(fontSize: 11, color: allOn ? AnonColors.green : AnonColors.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await widget.api.logout();
                        widget.onLogout();
                      },
                      icon: const Icon(Icons.logout, size: 20, color: AnonColors.muted),
                    ),
                  ],
                ),
              ),
              Expanded(child: _tab == 0 ? _home(allOn) : _settings()),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xEE120F1A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AnonColors.border),
                ),
                child: Row(children: [_navItem(0, Icons.shield_outlined, 'Shield'), _navItem(1, Icons.tune, 'Settings')]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final active = _tab == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: active ? const LinearGradient(colors: [Color(0xFF7B2ED2), Color(0xFFBD70FF)]) : null,
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: active ? Colors.white : AnonColors.muted),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : AnonColors.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _home(bool allOn) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        const BrandHeader(compact: true),
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AnonColors.purple),
              boxShadow: [BoxShadow(color: AnonColors.purple.withOpacity(0.28), blurRadius: 32)],
              gradient: const RadialGradient(center: Alignment(0, -0.25), colors: [Color(0xFF2B1644), Color(0xFF0C0914)]),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.power_settings_new, size: 34, color: AnonColors.purpleSoft),
                const SizedBox(height: 8),
                Text(allOn ? 'SHIELD ACTIVE' : 'PARTIAL COVER',
                    style: const TextStyle(letterSpacing: 1.4, fontSize: 12, color: Color(0xFFE6CAFF))),
                Text('$_score / ${items.length}',
                    style: const TextStyle(letterSpacing: 1, fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFD9AAFF))),
                const Text('layers on', style: TextStyle(fontSize: 11, color: AnonColors.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(allOn ? 'Your connection is fully cloaked.' : 'Turn on remaining layers for full cover.',
              style: const TextStyle(fontSize: 12, color: AnonColors.muted)),
        ),
        const SizedBox(height: 18),
        ...items.map(_card),
      ],
    );
  }

  Widget _settings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        const Text('Account', style: TextStyle(fontSize: 13, color: AnonColors.muted)),
        const SizedBox(height: 8),
        _tile(Icons.mail_outline, 'Email', widget.user.email),
        _tile(Icons.devices, 'Device id', deviceId == null ? '…' : '${deviceId!.substring(0, 8)}…'),
        _tile(Icons.cloud_done_outlined, 'Status', agentStatus),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            await widget.api.logout();
            widget.onLogout();
          },
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 12),
        const Text('Anon Privacy Console  ·  v3.0.0', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AnonColors.muted)),
      ],
    );
  }

  Widget _tile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AnonColors.border),
        color: const Color(0xCC14121C),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AnonColors.purpleSoft),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AnonColors.muted)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Widget _card(_Protection p) {
    return Opacity(
      opacity: p.on ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AnonColors.border),
          gradient: const LinearGradient(colors: [Color(0xF0171421), Color(0xF0100E18)]),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AnonColors.purple.withOpacity(0.12)),
            child: Icon(p.icon, color: AnonColors.purpleSoft, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(p.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AnonColors.muted, fontSize: 11)),
          ])),
          GestureDetector(
            onTap: () => setState(() => p.on = !p.on),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 43,
              height: 25,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: p.on ? const LinearGradient(colors: [Color(0xFF7B2ED2), Color(0xFFBD70FF)]) : null,
                color: p.on ? null : const Color(0xFF383342),
              ),
              alignment: p.on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(color: p.on ? Colors.white : const Color(0xFFBDB7C7), shape: BoxShape.circle),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
