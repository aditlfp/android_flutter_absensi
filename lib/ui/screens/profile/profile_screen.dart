import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../utils/app_theme.dart';
import '../camera/camera_screen.dart';
import '../auth/login_screen.dart';
import 'settings/notifications_settings_screen.dart';
import 'settings/privacy_settings_screen.dart';
import 'settings/help_support_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.userModel;
          if (user == null) {
            return const Center(child: Text('User not found.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _ProfileHeader(user: user),
                const SizedBox(height: 24),
                _FaceRecognitionCard(user: user),
                const SizedBox(height: 24),
                _SettingsCard(),
                const SizedBox(height: 24),
                _SignOutButton(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            user.name.substring(0, 1).toUpperCase(),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(user.email, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.subtextColor)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(label: Text(user.department), avatar: const Icon(Icons.business_center_outlined)),
            const SizedBox(width: 8),
            Chip(label: Text(user.position), avatar: const Icon(Icons.work_outline)),
          ],
        ),
      ],
    );
  }
}

class _FaceRecognitionCard extends StatelessWidget {
  final UserModel user;
  const _FaceRecognitionCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final hasFaceData = user.faceEmbedding.isNotEmpty;
    final statusColor = hasFaceData ? AppTheme.successColor : AppTheme.warningColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Face Recognition', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(hasFaceData ? Icons.verified_user_rounded : Icons.error_outline_rounded, color: statusColor),
                const SizedBox(width: 12),
                Expanded(child: Text(hasFaceData ? 'Face data is registered' : 'No face data found')),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showUpdateFaceDialog(context),
                child: Text(hasFaceData ? 'Update Face Data' : 'Register Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateFaceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Face Recognition'),
        content: const Text('This will replace your existing face data. Are you sure you want to continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraScreen(isRegistration: true)));
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            ),
            _SettingsItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
            ),
            _SettingsItem(
              icon: Icons.security_outlined,
              title: 'Privacy & Security',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
            ),
            _SettingsItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
            ),
            _SettingsItem(icon: Icons.info_outline, title: 'About', onTap: () => _showAboutDialog(context)),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Face Attendance'),
        content: const Text('Version: 1.0.0\n\nBuilt with Flutter and Firebase.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showSignOutDialog(context),
      icon: const Icon(Icons.logout),
      label: const Text('Sign Out'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        foregroundColor: AppTheme.errorColor,
        elevation: 0,
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
