import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final url = await apiService.getBaseUrl();
    final key = await apiService.getApiKey();
    setState(() {
      _urlController.text = url ?? '';
      _keyController.text = key ?? '';
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await apiService.saveSettings(
      baseUrl: _urlController.text,
      apiKey: _keyController.text,
    );
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Color(0xFF238636),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });
    // Save first so the client uses current values
    await apiService.saveSettings(
      baseUrl: _urlController.text,
      apiKey: _keyController.text,
    );
    final ok = await apiService.testConnection();
    setState(() {
      _isTesting = false;
      _testSuccess = ok;
      _testResult = ok ? '✓ Connected successfully' : '✗ Could not connect to server';
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(title: 'Server Connection'),
          const SizedBox(height: 12),
          _SettingsField(
            controller: _urlController,
            label: 'Server URL',
            hint: 'http://100.x.x.x:8000',
            icon: Icons.dns_outlined,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          _SettingsField(
            controller: _keyController,
            label: 'API Key',
            hint: 'Your secret key',
            icon: Icons.key_outlined,
            obscureText: _obscureKey,
            suffix: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: const Color(0xFF8B949E),
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B949E),
                    side: const BorderSide(color: Color(0xFF30363D)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B949E)),
                        )
                      : const Icon(Icons.wifi_tethering, size: 16),
                  label: Text(
                    _isTesting ? 'Testing...' : 'Test Connection',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_testSuccess == true)
                    ? const Color(0xFF238636).withValues(alpha:0.15)
                    : Colors.red.shade900.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_testSuccess == true)
                      ? const Color(0xFF238636)
                      : Colors.red.shade800,
                ),
              ),
              child: Text(
                _testResult!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: (_testSuccess == true) ? const Color(0xFF3FB950) : Colors.red.shade300,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          _SectionHeader(title: 'About'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AboutRow(label: 'App', value: 'Spirit Connect v1.0.0'),
                const Divider(color: Color(0xFF30363D), height: 20),
                _AboutRow(label: 'Model', value: 'qwen3:35b via Ollama'),
                const Divider(color: Color(0xFF30363D), height: 20),
                _AboutRow(label: 'Privacy', value: '100% local — no cloud'),
                const Divider(color: Color(0xFF30363D), height: 20),
                _AboutRow(label: 'Network', value: 'Tailscale VPN'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF8B949E),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _SettingsField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: const Color(0xFF8B949E), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF484F58)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF8B949E)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF161B22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8B949E))),
        Text(value,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
      ],
    );
  }
}
