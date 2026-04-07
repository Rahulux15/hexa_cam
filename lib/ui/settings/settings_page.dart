import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/database_service.dart';
import '../../config/app_version.dart';
import '../../config/theme.dart';
import '../../state/app_registry.dart';
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

  /// `null` while loading; empty string if [PackageInfo] failed.
  String? _appVersionLabel;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersionLabel = AppVersion.formatLabel(info));
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersionLabel = '');
    }
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
                  onTap: () => _currentView == SettingsView.main
                      ? Get.back<void>()
                      : setState(() => _currentView = SettingsView.main),
                  child: Container(
                    width: isTab ? 44 : 40,
                    height: isTab ? 44 : 40,
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary, size: isTab ? 22 : 20),
                  ),
                ),
                SizedBox(width: isTab ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text(
                        _getSubtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: isTab ? 13 : 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                pad,
                pad,
                pad,
                pad + MediaQuery.paddingOf(context).bottom + 12,
              ),
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
        width: isTab ? 260 : 220,
        height: isTab ? 120 : 96,
        child: Image.asset(
          'assets/images/report_logo.png',
          fit: BoxFit.fitWidth,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/about_logo.png',
            fit: BoxFit.fitWidth,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
      SizedBox(height: isTab ? 12 : 10),
      _buildAboutVersionLine(isTab),
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
    final titleStyle = TextStyle(
      color: AppTheme.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: isTab ? 16 : 14,
    );
    final bodyStyle = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: isTab ? 14 : 13,
      height: 1.5,
    );

    Widget policyCard({
      required String heading,
      required String body,
      IconData? icon,
    }) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTab ? 18 : 16),
        decoration: BoxDecoration(
          color: AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppTheme.primary, size: isTab ? 22 : 20),
                  SizedBox(width: isTab ? 10 : 8),
                ],
                Expanded(child: Text(heading, style: titleStyle)),
              ],
            ),
            SizedBox(height: isTab ? 10 : 8),
            SelectableText(body, style: bodyStyle),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: isTab ? 56 : 48,
            height: isTab ? 56 : 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(isTab ? 18 : 16),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
              size: isTab ? 32 : 28,
            ),
          ),
        ),
        SizedBox(height: isTab ? 18 : 16),
        Text(
          'Privacy Policy for Hexa-Cam',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isTab ? 22 : 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: isTab ? 18 : 16),
        policyCard(
          heading: 'Owner',
          icon: Icons.business_outlined,
          body:
              'Quasmo India Microscope Company\nAll Rights Reserved',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Introduction',
          icon: Icons.info_outline_rounded,
          body:
              'Hexa-Cam is a cross-platform microscopy imaging application developed and maintained by Quasmo India Microscope Company. This policy aligns with GDPR, the Indian Information Technology Act (2000), and other applicable frameworks. Hexa-Cam does not collect, store, or transmit personal data.',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Principles of Data Protection',
          icon: Icons.rule_folder_outlined,
          body:
              '• Lawfulness, fairness, and transparency\n'
              '• Purpose limitation\n'
              '• Data minimization\n'
              '• Accuracy\n'
              '• Storage limitation\n'
              '• Integrity and confidentiality',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Information We Do Not Collect',
          icon: Icons.not_interested_outlined,
          body:
              '• Personal identifiers (name, email, phone number, institution)\n'
              '• Location data, browsing history, or analytics\n'
              '• Images, videos, annotations, or calibration data outside your device\n'
              '• Third-party trackers, cookies, or advertising identifiers',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Local Device Usage',
          icon: Icons.phone_android_outlined,
          body:
              'All media assets (images, videos, annotations, reports) remain on your device. Calibration and measurement data are stored locally for scientific accuracy. You can create, edit, delete, and export your data at any time.',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Security and Privacy by Design',
          icon: Icons.security_outlined,
          body:
              '• Offline-first architecture; app functions without internet for core usage\n'
              '• No transmission of user media/data to Quasmo or third parties\n'
              '• Sensitive operations are handled on-device',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Permissions We Take',
          icon: Icons.admin_panel_settings_outlined,
          body:
              'Hexa-Cam requests only functional permissions:\n'
              '• Camera: to capture microscope photos/videos\n'
              '• Photos/Media/Files or Storage: to save, read, and export images/videos/reports\n'
              '• (Platform dependent) Microphone may be requested by video capture APIs on some devices\n\n'
              'Hexa-Cam does NOT request location, contacts, advertising ID, or background tracking permissions.',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Sharing and Disclosure',
          icon: Icons.share_outlined,
          body:
              'Since Hexa-Cam does not collect personal data, there is no sharing or disclosure of personal information. Reports and exports are created only at your request and remain under your control.',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'User Rights (GDPR and Indian IT Act)',
          icon: Icons.gavel_outlined,
          body:
              'We acknowledge the rights to access, rectification, erasure, portability, restriction of processing, and objection. As Hexa-Cam is local-first and does not centrally collect user data, control remains on your device.',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Children\'s Privacy',
          icon: Icons.child_care_outlined,
          body:
              'Hexa-Cam is intended for professional and educational use. It is not designed for children under 13. We do not knowingly collect data from minors.',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Data Retention',
          icon: Icons.storage_outlined,
          body:
              'Data remains on your device until you delete it. No external servers store user data. Diagnostic logs are limited to device-level troubleshooting and are not transmitted.',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Policy Updates',
          icon: Icons.update_outlined,
          body:
              'If new features introduce data handling, this policy will be updated in app changelogs and version notes.',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Contact Information',
          icon: Icons.support_agent_outlined,
          body:
              'Email: support@quasmoindianmicroscope.com\n'
              'Toll-Free: 1800-419-4979\n'
              'Location: #84, HSIDC Industrial Area, Ambala Cantt. – 133 001, Haryana, INDIA',
        ),
        SizedBox(height: isTab ? 12 : 10),
        policyCard(
          heading: 'Ownership and Rights',
          icon: Icons.copyright_outlined,
          body:
              'Hexa-Cam is the intellectual property of Quasmo India Microscope Company. Unauthorized reproduction, distribution, or modification is prohibited.\n\n© 2026 Quasmo India Microscope Company. All rights reserved.',
        ),
      ],
    );
  }

  Widget _buildHelpView() {
    final isTab = Responsive.isTablet(context);
    final titleStyle = TextStyle(
      color: AppTheme.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: isTab ? 16 : 14,
    );
    final bodyStyle = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: isTab ? 14 : 13,
      height: 1.45,
    );
    final linkStyle = TextStyle(
      color: AppTheme.primary,
      fontSize: isTab ? 14 : 13,
      height: 1.4,
    );

    Widget helpCard({
      required IconData icon,
      required String heading,
      required List<Widget> children,
    }) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTab ? 18 : 16),
        decoration: BoxDecoration(
          color: AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppTheme.primary, size: isTab ? 22 : 20),
                SizedBox(width: isTab ? 10 : 8),
                Expanded(
                  child: Text(heading, style: titleStyle),
                ),
              ],
            ),
            ...children,
          ],
        ),
      );
    }

    Widget labeledBlock(String label, String value, {bool selectable = true}) {
      return Padding(
        padding: EdgeInsets.only(top: isTab ? 12 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: bodyStyle.copyWith(fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
            SizedBox(height: isTab ? 4 : 2),
            selectable
                ? SelectableText(value, style: linkStyle)
                : Text(value, style: bodyStyle),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: isTab ? 56 : 48,
            height: isTab ? 56 : 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(isTab ? 18 : 16),
            ),
            child: Icon(Icons.support_agent_outlined, color: Colors.white, size: isTab ? 32 : 28),
          ),
        ),
        SizedBox(height: isTab ? 18 : 16),
        Text(
          'Help & Support',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isTab ? 22 : 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: isTab ? 8 : 6),
        Text(
          'Quasmo Indian Microscope',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isTab ? 14 : 13,
            color: AppTheme.textMuted,
          ),
        ),
        SizedBox(height: isTab ? 18 : 16),
        helpCard(
          icon: Icons.location_on_outlined,
          heading: 'Location',
          children: [
            Padding(
              padding: EdgeInsets.only(top: isTab ? 10 : 8),
              child: SelectableText(
                '# 84, HSIDC Industrial Area, Ambala Cantt. – 133 001, Haryana, INDIA',
                style: bodyStyle,
              ),
            ),
          ],
        ),
        SizedBox(height: isTab ? 12 : 10),
        helpCard(
          icon: Icons.phone_outlined,
          heading: 'Phone',
          children: [
            labeledBlock('Dheeraj Bahl (MD)', '+91 9215 617 707'),
            labeledBlock('Ujjwal Bahl (MD)', '+91 8926 666 632'),
          ],
        ),
        SizedBox(height: isTab ? 12 : 10),
        helpCard(
          icon: Icons.mail_outline_rounded,
          heading: 'Email',
          children: [
            labeledBlock('Sales', 'sales@quasmoindianmicroscope.com'),
            labeledBlock('Tender Enquiries', 'quasmo.mechanical@gmail.com'),
            labeledBlock('General Inquiries', 'info@quasmoindianmicroscope.com'),
          ],
        ),
        SizedBox(height: isTab ? 12 : 10),
        helpCard(
          icon: Icons.headset_mic_outlined,
          heading: 'Technical Support',
          children: [
            labeledBlock('Email', 'support@quasmoindianmicroscope.com'),
            labeledBlock('Toll-Free (Front Desk)', '1800-419-4979'),
          ],
        ),
        SizedBox(height: isTab ? 12 : 10),
        helpCard(
          icon: Icons.lightbulb_outline_rounded,
          heading: 'Quick Tips',
          children: [
            Padding(
              padding: EdgeInsets.only(top: isTab ? 10 : 8),
              child: Text(
                '• Use the Distance tool in the image viewer for length measurements; calibrate each lens in Settings for µm and other units.\n'
                '• Without calibration, measurements are shown in pixels (px).\n'
                '• Pinch to zoom where supported, or use Fullscreen in the image viewer for a larger view.\n'
                '• Configure microscope calibrations under Settings for accurate readings.\n'
                '• From Download options: save marked photos or videos to your device, or generate PDF reports.',
                style: bodyStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAboutVersionLine(bool isTab) {
    final style = TextStyle(color: AppTheme.textMuted, fontSize: isTab ? 14 : 12);
    if (_appVersionLabel == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Version ', style: style),
          SizedBox(
            width: isTab ? 14 : 12,
            height: isTab ? 14 : 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      );
    }
    if (_appVersionLabel!.isEmpty) {
      return Text('Version unavailable', style: style);
    }
    return Text('Version ${_appVersionLabel!}', style: style);
  }

  Widget _buildAboutView() {
    final isTab = Responsive.isTablet(context);
    final bodyStyle = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: isTab ? 16 : 14,
      height: 1.5,
    );
    final headingStyle = TextStyle(
      color: AppTheme.textPrimary,
      fontSize: isTab ? 18 : 16,
      fontWeight: FontWeight.w700,
    );
    final footStyle = TextStyle(
      color: AppTheme.textMuted,
      fontSize: isTab ? 13 : 12,
      height: 1.45,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isTab ? 22 : 20),
            child: Image.asset(
              'assets/images/report_logo.png',
              width: isTab ? 220 : 180,
              height: isTab ? 130 : 106,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: isTab ? 88 : 80,
                  height: isTab ? 88 : 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(isTab ? 26 : 24),
                  ),
                  child: Icon(Icons.biotech_outlined, color: Colors.white, size: isTab ? 48 : 44),
                );
              },
            ),
          ),
        ),
        SizedBox(height: isTab ? 18 : 16),
        Center(child: _buildAboutVersionLine(isTab)),
        SizedBox(height: isTab ? 18 : 16),
        Text(
          'Introduction',
          style: headingStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 8 : 6),
        Text(
          'Hexa-Cam is a cross-platform microscopy imaging application designed to empower researchers, educators, and professionals with advanced imaging, annotation, and reporting tools. Built with Flutter, Hexa-Cam delivers precision, efficiency, and reliability across Android, iOS, Web, Windows, macOS, and Linux.',
          style: bodyStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 16 : 14),
        Text(
          'Vision',
          style: headingStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 8 : 6),
        Text(
          'Our vision is to simplify and enhance scientific imaging workflows by providing dependable tools for capturing, measuring, annotating, and documenting microscopic data. Hexa-Cam is committed to supporting laboratories, classrooms, and industries with professional-grade solutions.',
          style: bodyStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 16 : 14),
        Text(
          'Key Features',
          style: headingStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 8 : 6),
        Text(
          '• Cross-platform compatibility for seamless use across devices\n'
          '• Real-time camera preview with annotation capabilities\n'
          '• Calibrated measurement system supporting multiple scientific units\n'
          '• Professional PDF report generation with embedded images and metadata\n'
          '• Offline-first architecture ensuring functionality without internet connectivity',
          style: bodyStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 16 : 14),
        Text(
          'Our Story',
          style: headingStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 8 : 6),
        Text(
          'Hexa-Cam was created in 2026 to address the growing need for accurate, efficient, and collaborative scientific imaging solutions. Since its inception, it has been trusted by researchers, lab technicians, educators, and quality control professionals worldwide.',
          style: bodyStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 16 : 14),
        Text(
          'Business Value',
          style: headingStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 8 : 6),
        Text(
          '• Accuracy: Calibrated measurements ensure scientific precision\n'
          '• Efficiency: Digital workflows replace manual documentation\n'
          '• Collaboration: Shareable reports and standardized formats\n'
          '• Compliance: Professional documentation supports regulatory requirements',
          style: bodyStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 16 : 14),
        Text(
          'Most Important Statement',
          style: headingStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 8 : 6),
        Text(
          'HEXA-CAM is developed and maintained by Quasmo India Microscope Company. All rights reserved.',
          style: bodyStyle.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 16 : 14),
        Text(
          'Contact Information',
          style: headingStyle,
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 8 : 6),
        SelectableText(
          'Email: support@quasmoindianmicroscope.com\n'
          'Toll-Free: 1800-419-4979\n'
          'Location: #84, HSIDC Industrial Area, Ambala Cantt. – 133 001, Haryana, INDIA',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: isTab ? 15 : 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          textAlign: TextAlign.left,
        ),
        SizedBox(height: isTab ? 10 : 8),
        SelectableText(
          'https://www.quasmoindianmicroscope.com/',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: isTab ? 15 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isTab ? 26 : 24),
        Text(
          '© 2026 Quasmo India Microscope Company. All rights reserved.',
          style: footStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
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
      Get.offAllNamed<void>('/folders');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isClearingData = false);
      HexaToast.show(context, 'Unable to clear app data',
          type: HexaToastType.error);
    }
  }
}


