import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/attendance_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/models/attendance_model.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Present', 'Late', 'This Week', 'This Month'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          _buildFilterButton(context),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendanceProvider, child) {
          if (attendanceProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredAttendance = _filterAttendance(attendanceProvider.attendanceHistory);

          if (filteredAttendance.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => _refreshData(context),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SummaryCard(attendance: filteredAttendance, filter: _selectedFilter),
                const SizedBox(height: 24),
                ...filteredAttendance.map((att) => _AttendanceCard(attendance: att)),
              ],
            ),
          );
        },
      ),
    );
  }

  PopupMenuButton<String> _buildFilterButton(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _selectedFilter = value),
      icon: Icon(Icons.filter_list_rounded, color: Theme.of(context).primaryColor),
      itemBuilder: (context) => _filterOptions
          .map((filter) => PopupMenuItem(value: filter, child: Text(filter)))
          .toList(),
    );
  }

  List<AttendanceModel> _filterAttendance(List<AttendanceModel> attendance) {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Present':
        return attendance.where((a) => a.status == 'present').toList();
      case 'Late':
        return attendance.where((a) => a.status == 'late').toList();
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return attendance.where((a) => a.checkIn.isAfter(weekStart.subtract(const Duration(days: 1)))).toList();
      case 'This Month':
        return attendance.where((a) => a.checkIn.isAfter(DateTime(now.year, now.month, 1))).toList();
      default:
        return attendance;
    }
  }

  Future<void> _refreshData(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      await Provider.of<AttendanceProvider>(context, listen: false)
          .loadAttendanceHistory(authProvider.user!.uid);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Records Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your attendance history will appear here.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<AttendanceModel> attendance;
  final String filter;

  const _SummaryCard({required this.attendance, required this.filter});

  @override
  Widget build(BuildContext context) {
    final presentCount = attendance.where((a) => a.status == 'present').length;
    final lateCount = attendance.where((a) => a.status == 'late').length;
    final totalDays = attendance.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary for "$filter"', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(title: 'Total', value: totalDays.toString(), color: Colors.blue.shade700),
                _SummaryItem(title: 'On Time', value: presentCount.toString(), color: Theme.of(context).colorScheme.primary),
                _SummaryItem(title: 'Late', value: lateCount.toString(), color: Theme.of(context).colorScheme.tertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryItem({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final AttendanceModel attendance;

  const _AttendanceCard({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final statusColor = attendance.status == 'present' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary;
    final duration = attendance.checkOut?.difference(attendance.checkIn);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM dd').format(attendance.checkIn),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(attendance.status.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TimeItem(label: 'Check In', time: DateFormat('HH:mm').format(attendance.checkIn)),
                _TimeItem(label: 'Check Out', time: attendance.checkOut != null ? DateFormat('HH:mm').format(attendance.checkOut!) : '--:--'),
                if (duration != null) _TimeItem(label: 'Duration', time: '${duration.inHours}h ${duration.inMinutes % 60}m'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeItem extends StatelessWidget {
  final String label;
  final String time;

  const _TimeItem({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(time, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
