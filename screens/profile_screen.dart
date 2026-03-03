import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/auth_service.dart';
import '../services/deal_service.dart';
import '../services/wishlist_service.dart';
import '../services/cross_platform_auth_service.dart';
import '../providers/theme_provider.dart';
import '../themes/app_theme.dart';
import '../utils/open_support_form.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final CrossPlatformAuthService _authService = CrossPlatformAuthService();
  final DealService _dealService = DealService();
  final WishlistService _wishlistService = WishlistService();

  int _wishlistCount = 0;
  int _totalSavings = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final wishlist = await _wishlistService.getWishlist();
      if (mounted) {
        setState(() {
          _wishlistCount = wishlist.length;
          _totalSavings = wishlist.fold(
            0,
            (sum, deal) => sum + (deal.savings?.toInt() ?? 0),
          );
        });
      }
    } catch (e) {}
  }

  Future<void> _loadUserProfile() async {
    await _authService.refreshCurrentUser();
    await _loadUserData();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildUserInfoSection(user),

            const SizedBox(height: 24),

            _buildSettingsSection(),

            const SizedBox(height: 24),

            _buildLegalSection(),

            const SizedBox(height: 24),

            _buildSignOutButton(),
          ],
        ),
      ),
    );
  }

  void _toggleTheme() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.toggleTheme();
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Sign Out', style: TextStyle(color: Colors.red[600])),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      try {
        await _authService.signOut();
        await _wishlistService.clearWishlist();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
        }
      }
    }
  }

  Future<void> _switchAccount() async {
    final shouldSwitch = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Switch Account'),
          content: const Text(
            'Are you sure you want to switch to a different account? Your current session will end.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Switch Account',
                style: TextStyle(color: Colors.blue[600]),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSwitch == true) {
      try {
        await _authService.signOut();
        await _wishlistService.clearWishlist();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error switching account: $e')),
          );
        }
      }
    }
  }

  Widget _buildUserInfoSection(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[100]!, Colors.blue[200]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue[600],
            child: user?.photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      user.photoUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.network(
                          'https://lh3.googleusercontent.com/a/default-user=s64',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            );
                          },
                        );
                      },
                    ),
                  )
                : Image.network(
                    'https://lh3.googleusercontent.com/a/default-user=s64',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      );
                    },
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Demo User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'demo@example.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user?.isAdmin == true
                        ? Colors.red[100]
                        : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user?.isAdmin == true ? 'Owner' : 'Member',
                    style: TextStyle(
                      color: user?.isAdmin == true
                          ? Colors.red[700]
                          : Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  final themeMode = themeProvider.themeMode;
                  return ListTile(
                    leading: Icon(
                      themeMode == ThemeMode.light
                          ? Icons.light_mode
                          : themeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : Icons.brightness_auto,
                      color: Colors.blue[600],
                    ),
                    title: const Text('Theme'),
                    subtitle: Text('Current: ${themeMode.name.toUpperCase()}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _toggleTheme,
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.switch_account, color: Colors.blue[600]),
                title: const Text('Switch Account'),
                subtitle: const Text('Sign in with a different account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _switchAccount,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.refresh, color: Colors.blue[600]),
                title: const Text('Refresh Data'),
                subtitle: const Text('Sync latest deals'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  _dealService.setOfflineMode(false);
                  await _dealService.getDeals(limit: 20);
                  await _loadUserData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data refreshed')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Legal & Support',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.privacy_tip, color: Colors.blue[600]),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLegalPage('privacy'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.description, color: Colors.blue[600]),
                title: const Text('Terms & Conditions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLegalPage('terms'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.info, color: Colors.blue[600]),
                title: const Text('Disclaimer'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLegalPage('disclaimer'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.help, color: Colors.blue[600]),
                title: const Text('Help & Support'),
                subtitle: const Text(' No personal information is required.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openSupportForm(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.info, color: Colors.blue[600]),
                title: const Text('App Version'),
                trailing: FutureBuilder<String>(
                  future: PackageInfo.fromPlatform().then(
                    (info) => info.version,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text("v${snapshot.data}");
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showLegalPage(String type) {
    final titles = {
      'privacy': 'Privacy Policy',
      'terms': 'Terms & Conditions',
      'disclaimer': 'Disclaimer',
    };

    final content = {
      'privacy': _getPrivacyPolicyContent(),
      'terms': _getTermsContent(),
      'disclaimer': _getDisclaimerContent(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LegalPage(title: titles[type]!, content: content[type]!),
      ),
    );
  }

  String _getPrivacyPolicyContent() {
    return '''
Privacy Policy

Last updated: ${DateTime.now().toString().split(' ')[0]}

1. Information We Collect
- We collect information you provide directly to us
- We automatically collect certain information when you use our app
- We may collect information from third-party sources

2. How We Use Your Information
- To provide and improve our services
- To communicate with you
- To personalize your experience
- To ensure security and prevent fraud

3. Information Sharing
- We do not sell your personal information
- We may share information with service providers
- We may disclose information if required by law

4. Data Security
- We implement appropriate security measures
- We cannot guarantee absolute security
- We notify you of security incidents

5. Your Rights
- Access to your personal information
- Correction of inaccurate information
- Deletion of your information
- Opt-out of certain processing

6. Contact Us
If you have questions about this Privacy Policy, please contact us.
''';
  }

  String _getTermsContent() {
    return '''
Terms & Conditions

Last updated: ${DateTime.now().toString().split(' ')[0]}

1. Acceptance of Terms
By using this app, you agree to these terms and conditions.

2. Use of Service
- You may use the service for personal, non-commercial purposes
- You agree not to misuse the service
- We reserve the right to modify or discontinue the service

3. User Accounts
- You are responsible for maintaining account security
- You must provide accurate information
- You are responsible for all activities under your account

4. Content
- We do not guarantee the accuracy of deal information
- Prices and availability may change
- We are not responsible for external links

5. Limitation of Liability
- We provide the service "as is"
- We are not liable for indirect or consequential damages
- Our liability is limited to the extent permitted by law

6. Termination
- We may terminate or suspend access immediately
- You may terminate your account at any time

7. Changes to Terms
- We may update these terms from time to time
- Continued use constitutes acceptance of changes

8. Contact Information
For questions about these terms, please contact us.
''';
  }

  String _getDisclaimerContent() {
    return '''
Disclaimer

Last updated: ${DateTime.now().toString().split(' ')[0]}

1. Not a Seller
- We are not the seller of any products or services
- We do not manufacture, own, or stock any products
- All transactions are directly with third-party merchants

2. Information Accuracy
- We strive to provide accurate deal information
- We cannot guarantee the accuracy of all information
- Prices, availability, and terms may change without notice

3. External Links
- Our app may contain links to external websites
- We are not responsible for external website content
- We do not endorse or guarantee external services

4. No Guarantees
- We do not guarantee deals will remain available
- We do not guarantee the quality of products or services
- We do not guarantee price accuracy

5. Limitation of Responsibility
- We are not liable for any damages arising from use of our app
- We are not liable for any disputes with merchants
- Use of our app is at your own risk

6. Deal Verification
- Users are responsible for verifying deal terms
- Users should read merchant terms and conditions
- Users should contact merchants directly for issues

7. Changes
- We reserve the right to modify this disclaimer
- It is your responsibility to stay informed of changes

For questions about this disclaimer, please contact us.
''';
  }
}

class LegalPage extends StatelessWidget {
  final String title;
  final String content;

  const LegalPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
      ),
    );
  }
}
