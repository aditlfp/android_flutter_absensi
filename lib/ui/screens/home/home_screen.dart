import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/attendance_provider.dart';
import '../../../data/models/attendance_model.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/permissions.dart';
import '../camera/camera_screen.dart';
import '../attendance/attendance_history_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/home/action_button.dart';
import '../../widgets/home/status_item.dart';
import '../../widgets/home/activity_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    // No need to await here, let it run in the background
    PermissionHelper.requestAll();

    // Load data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        Provider.of<AttendanceProvider>(context, listen: false)
            .loadAttendanceHistory(authProvider.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomePage(),
      const AttendanceHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () {}, // TODO: Implement notifications
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.user != null) {
            await Provider.of<AttendanceProvider>(context, listen: false)
                .loadAttendanceHistory(authProvider.user!.uid);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              const SizedBox(height: 24),
              const _QuickActions(),
              const SizedBox(height: 24),
              const _TodayStatus(),
              const SizedBox(height: 24),
              const _RecentActivity(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.subtextColor,
              ),
            ),
            Text(
              authProvider.userModel?.name ?? 'User',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, AttendanceProvider>(
      builder: (context, auth, att, child) {
        final hasRegisteredFace = auth.userModel?.faceEmbedding.isNotEmpty ?? false;
        final hasCheckedIn = att.todayAttendance != null;
        final hasCheckedOut = att.todayAttendance?.checkOut != null;

        if (!hasRegisteredFace) {
          return ActionButton(
            icon: Icons.face_retouching_natural,
            title: 'Register Your Face',
            subtitle: 'Required for attendance',
            color: AppTheme.warningColor,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraScreen(isRegistration: true))),
          );
        }
        if (!hasCheckedIn) {
          return ActionButton(
            icon: Icons.login_rounded,
            title: 'Check In Now',
            subtitle: 'Start your workday',
            color: AppTheme.successColor,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraScreen())),
          );
        }
        if (!hasCheckedOut) {
          return ActionButton(
            icon: Icons.logout_rounded,
            title: 'Check Out',
            subtitle: 'End your workday',
            color: AppTheme.errorColor,
            onTap: () async {
              final success = await att.checkOut(auth.user!.uid);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked out successfully!')));
              }
            },
          );
        }
        return const SizedBox.shrink(); // Hide if all actions are done
      },
    );
  }
}

class _TodayStatus extends StatelessWidget {
  const _TodayStatus();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today\'s Status', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Consumer<AttendanceProvider>(
              builder: (context, att, child) {
                final today = att.todayAttendance;
                if (today == null) {
                  return const Center(child: Text('No attendance recorded yet today.'));
                }
                return Column(
                  children: [
                    StatusItem(
                      icon: Icons.login,
                      title: 'Check In',
                      value: DateFormat('HH:mm').format(today.checkIn),
                      status: today.status,
                    ),
                    if (today.checkOut != null) ...[
                      const Divider(height: 24),
                      StatusItem(
                        icon: Icons.logout,
                        title: 'Check Out',
                        value: DateFormat('HH:mm').format(today.checkOut!),
                        status: 'Completed',
                      ),
                    ]
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Consumer<AttendanceProvider>(
          builder: (context, att, child) {
            final history = att.attendanceHistory.take(3).toList();
            if (history.isEmpty) {
              return const Center(child: Text('No recent activity found.'));
            }
            return Column(
              children: history.map((item) => ActivityItem(attendance: item)).toList(),
            );
          },
        ),
      ],
    );
  }
}
