import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/database_service.dart';
import '../../config/theme.dart';
import '../../state/providers.dart';
import '../../utils/responsive.dart';
import '../common/hexa_toast.dart';

enum SettingsView { main, profile, privacy, help, about }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsView _currentView = SettingsView.main;
  bool _showClearDialog = false;
  bool _isClearingData = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _nameController.dispose(); _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = (prefs.getString('user_full_name') ?? '').trim();
    final email = (prefs.getString('user_email') ?? '').trim();

    if (!mounted) return;
    setState(() {
      _nameController.text = fullName;
      _emailController.text = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    final pad = Responsive.pagePadding(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.pageBackground),
        child: Column(children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderColor))),
              child: Row(children: [
                GestureDetector(
                  onTap: () => _currentView == SettingsView.main ? context.pop() : setState(() => _currentView = SettingsView.main),
                  child: Container(
                    width: isTab ? 44 : 40,
                    height: isTab ? 44 : 40,
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary, size: isTab ? 22 : 20),
                  ),
                ),
                SizedBox(width: isTab ? 16 : 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text(_getSubtitle(), style: TextStyle(fontSize: isTab ? 13 : 12, color: AppTheme.textMuted)),
                  ],
                ),
              ]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: Responsive.constrain(context, child: _buildCurrentView()),
            ),
          ),
          if (_showClearDialog) _buildClearDialog(),
        ]),
      ),
    );
  }

  String _getSubtitle() {
    switch (_currentView) {
      case SettingsView.main: return 'Manage your preferences';
      case SettingsView.profile: return 'Personal information';
      case SettingsView.privacy: return 'Data & security';
      case SettingsView.help: return 'Get assistance';
      case SettingsView.about: return 'App information';
    }
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case SettingsView.main: return _buildMainView();
      case SettingsView.profile: return _buildProfileView();
      case SettingsView.privacy: return _buildPrivacyView();
      case SettingsView.help: return _buildHelpView();
      case SettingsView.about: return _buildAboutView();
    }
  }

  Widget _buildMainView() {
    final isTab = Responsive.isTablet(context);
    return Column(children: [
      _buildSection('General', [
        _buildTile(Icons.badge_outlined, 'Profile', 'Personal information', () => setState(() => _currentView = SettingsView.profile)),
      ]),
      SizedBox(height: isTab ? 18 : 16),
      _buildSection('Application', [
        _buildTile(Icons.verified_user_outlined, 'Privacy', 'Data & security', () => setState(() => _currentView = SettingsView.privacy)),
      ]),
      SizedBox(height: isTab ? 18 : 16),
      _buildSection('Support', [
        _buildTile(Icons.support_agent_outlined, 'Help & Support', 'Get assistance', () => setState(() => _currentView = SettingsView.help)),
        _buildTile(Icons.info_outline_rounded, 'About', 'App information', () => setState(() => _currentView = SettingsView.about)),
      ]),
      SizedBox(height: isTab ? 18 : 16),
      _buildSection('Data', [
        _buildTile(Icons.delete_sweep_outlined, 'Clear All Data', 'Reset everything', () => setState(() => _showClearDialog = true), isDanger: true),
      ]),
      SizedBox(height: isTab ? 36 : 32),
      SizedBox(
        width: isTab ? 100 : 80,
        height: isTab ? 100 : 80,
        // decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(isTab ? 24 : 20)),
        child: Image.asset(
          'assets/images/app_new_logo.png',
          // width: 150,
          // height: 300,
          // fit: BoxFit.contain,
        ),

        // Icon(Icons.biotech_outlined, color: Colors.white, size: isTab ? 48 : 40),
      ),
      SizedBox(height: isTab ? 16 : 12),
      const Text('Hexa-Cam', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      const Text('Version 2.0.0', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      const Text('Scientific Imaging & Microscopy', style: TextStyle(fontSize: 12, color: AppTheme.textDisabled)),
      SizedBox(height: isTab ? 34 : 30),
    ]);
  }

  Widget _buildSection(String title, List<Widget> items) {
    final isTab = Responsive.isTablet(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: isTab ? 13 : 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 1),
        ),
      ),
      Container(
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderColor)),
        child: Column(children: items.asMap().entries.map((e) => Column(children: [e.value, if (e.key < items.length - 1) const Divider(height: 1, color: AppTheme.borderColor, indent: 60)])).toList()),
      ),
    ]);
  }

  Widget _buildTile(IconData icon, String title, String subtitle, VoidCallback onTap, {bool isDanger = false}) {
    final isTab = Responsive.isTablet(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(isTab ? 18 : 16),
        child: Row(children: [
          Container(
            width: isTab ? 48 : 44,
            height: isTab ? 48 : 44,
            decoration: BoxDecoration(
              gradient: isDanger ? null : AppTheme.primaryGradient,
              color: isDanger ? const Color(0x14EF4444) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDanger ? AppTheme.danger : Colors.white, size: isTab ? 22 : 20),
          ),
          SizedBox(width: isTab ? 14 : 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: isTab ? 17 : 16, fontWeight: FontWeight.w500, color: isDanger ? AppTheme.danger : AppTheme.textPrimary)),
              Text(subtitle, style: TextStyle(fontSize: isTab ? 13 : 12, color: AppTheme.textMuted)),
            ]),
          ),
          Icon(Icons.chevron_right, color: AppTheme.textMuted, size: isTab ? 24 : 22),
        ]),
      ),
    );
  }

  Widget _buildProfileView() {
    final isTab = Responsive.isTablet(context);
    return Column(children: [
      _buildProfileField('Full Name', _nameController, Icons.badge_outlined),
      SizedBox(height: isTab ? 14 : 12),
      _buildProfileField('Email Address', _emailController, Icons.alternate_email_rounded),
      SizedBox(height: isTab ? 18 : 14),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Profile details are managed by your login account.',
          style: TextStyle(
            fontSize: isTab ? 13 : 12,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    ]);
  }

  Widget _buildProfileField(String label, TextEditingController controller, IconData icon) {
    final isTab = Responsive.isTablet(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: isTab ? 15 : 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
      SizedBox(height: isTab ? 8 : 6),
      TextField(
        controller: controller,
        readOnly: true,
        enabled: false,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: isTab ? 16 : 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppTheme.textMuted, size: isTab ? 22 : 20),
          filled: true,
          fillColor: AppTheme.bgTertiary,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isTab ? 14 : 12),
        ),
      ),
    ]);
  }

  Widget _buildPrivacyView() {
    final isTab = Responsive.isTablet(context);
    return Column(children: [
      Container(
        width: isTab ? 56 : 48,
        height: isTab ? 56 : 48,
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(isTab ? 18 : 16)),
        child: Icon(Icons.verified_user_outlined, color: Colors.white, size: isTab ? 32 : 28),
      ),
      SizedBox(height: isTab ? 18 : 16),
      Text('Privacy & Security', style: TextStyle(fontSize: isTab ? 22 : 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      SizedBox(height: isTab ? 14 : 12),
      Text(
        'Your privacy is our priority. All data in Hexa-Cam is stored locally on your device and is never transmitted to external servers.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: isTab ? 15 : 14, height: 1.5),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: isTab ? 14 : 12),
      Text(
        '• Images and annotations remain on your device\n• No cloud backup or synchronization\n• Complete control over your scientific data\n• No tracking or analytics',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: isTab ? 15 : 14, height: 1.5),
      ),
    ]);
  }

  Widget _buildHelpView() {
    final isTab = Responsive.isTablet(context);
    return Column(children: [
      Container(
        width: isTab ? 56 : 48,
        height: isTab ? 56 : 48,
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(isTab ? 18 : 16)),
        child: Icon(Icons.support_agent_outlined, color: Colors.white, size: isTab ? 32 : 28),
      ),
      SizedBox(height: isTab ? 18 : 16),
      Text('Help & Support', style: TextStyle(fontSize: isTab ? 22 : 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      SizedBox(height: isTab ? 18 : 16),
      Container(
        padding: EdgeInsets.all(isTab ? 18 : 16),
        decoration: BoxDecoration(color: AppTheme.bgTertiary, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.mail_outline_rounded, color: AppTheme.primary, size: isTab ? 22 : 20),
            SizedBox(width: isTab ? 10 : 8),
            Text('Email Support', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: isTab ? 16 : 14)),
          ]),
          SizedBox(height: isTab ? 6 : 4),
          Text('support@hexacam.com', style: TextStyle(color: AppTheme.primary, fontSize: isTab ? 14 : 13)),
        ]),
      ),
      SizedBox(height: isTab ? 14 : 12),
      Container(
        padding: EdgeInsets.all(isTab ? 18 : 16),
        decoration: BoxDecoration(color: AppTheme.bgTertiary, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick Tips', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: isTab ? 16 : 14)),
          SizedBox(height: isTab ? 10 : 8),
          Text(
            '• Tap the Measure button to show measurements\n• Without calibration, measurements are shown in px\n• Use two fingers to zoom in/out\n• Long press to access calibration settings\n• Export reports as PDF from download options',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: isTab ? 14 : 13, height: 1.5),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildAboutView() {
    final isTab = Responsive.isTablet(context);
    return Column(children: [
      Container(
        width: isTab ? 88 : 80,
        height: isTab ? 88 : 80,
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(isTab ? 26 : 24)),
        child: Icon(Icons.biotech_outlined, color: Colors.white, size: isTab ? 48 : 44),
      ),
      SizedBox(height: isTab ? 18 : 16),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFFA78BFA), Color(0xFF818CF8), Color(0xFF22D3EE)]).createShader(bounds),
        child: Text('Hexa-Cam', style: TextStyle(fontSize: isTab ? 32 : 28, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      SizedBox(height: isTab ? 6 : 4),
      Text('Version 2.0.0', style: TextStyle(color: AppTheme.textMuted, fontSize: isTab ? 14 : 12)),
      SizedBox(height: isTab ? 18 : 16),
      Text(
        'Advanced scientific imaging and microscopy application designed for researchers and scientists.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: isTab ? 16 : 14, height: 1.5),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: isTab ? 10 : 8),
      Text(
        'Features include real-time measurements, annotation tools, calibration systems, and comprehensive reporting.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: isTab ? 16 : 14, height: 1.5),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: isTab ? 26 : 24),
      Text(
        '© 2024 Hexa-Cam Inc. All rights reserved.',
        style: TextStyle(color: AppTheme.textMuted, fontSize: isTab ? 13 : 12),
      ),
      Text(
        'Made with precision for scientific excellence',
        style: TextStyle(color: AppTheme.textMuted, fontSize: isTab ? 13 : 12),
      ),
    ]);
  }

  Widget _buildClearDialog() {
    final isTab = Responsive.isTablet(context);
    return GestureDetector(
      onTap: () => setState(() => _showClearDialog = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: EdgeInsets.all(isTab ? 28 : 24),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: isTab ? 64 : 56,
                  height: isTab ? 64 : 56,
                  decoration: BoxDecoration(color: const Color(0x14EF4444), borderRadius: BorderRadius.circular(isTab ? 18 : 16)),
                  child: Icon(Icons.delete_sweep_outlined, color: AppTheme.danger, size: isTab ? 32 : 28),
                ),
                SizedBox(height: isTab ? 18 : 16),
                Text(
                  'Clear All Data?',
                  style: TextStyle(fontSize: isTab ? 20 : 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                SizedBox(height: isTab ? 10 : 8),
                Text(
                  'This will permanently delete all folders, images, and settings. This action cannot be undone.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: isTab ? 15 : 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isTab ? 22 : 20),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _showClearDialog = false),
                      style: TextButton.styleFrom(padding: EdgeInsets.symmetric(vertical: isTab ? 14 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: AppTheme.bgTertiary),
                      child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontSize: isTab ? 15 : 14)),
                    ),
                  ),
                  SizedBox(width: isTab ? 14 : 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isClearingData ? null : _clearAllData,
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: isTab ? 14 : 12), backgroundColor: AppTheme.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isClearingData
                          ? SizedBox(
                              width: isTab ? 18 : 16,
                              height: isTab ? 18 : 16,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Clear All', style: TextStyle(color: Colors.white, fontSize: isTab ? 15 : 14)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearAllData() async {
    setState(() => _isClearingData = true);
    try {
      await foldersController.clearAll();
      await calibrationController.clearAll();
      await storageService.clear();
      await MediaDatabase.clearAll();
      if (!mounted) return;
      setState(() {
        _showClearDialog = false;
        _isClearingData = false;
        _currentView = SettingsView.main;
      });
      HexaToast.show(context, 'All app data cleared',
          type: HexaToastType.success);
      context.go('/folders');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isClearingData = false);
      HexaToast.show(context, 'Unable to clear app data',
          type: HexaToastType.error);
    }
  }
}


