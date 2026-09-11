import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/approval/cubit/approval_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Chapter2App extends StatelessWidget {
  const Chapter2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardCubit>(
          create: (_) => DashboardCubit(
            apiService: locator<Chapter2ApiService>(),
          )..loadDashboardMetrics(),
        ),
        BlocProvider<ApprovalCubit>(
          create: (_) => ApprovalCubit(
            apiService: locator<Chapter2ApiService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Chapter 2',
        theme: Chapter2Theme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const CommandCenterShell(),
      ),
    );
  }
}

class CommandCenterShell extends StatefulWidget {
  const CommandCenterShell({super.key});

  @override
  State<CommandCenterShell> createState() => _CommandCenterShellState();
}

class _CommandCenterShellState extends State<CommandCenterShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Chapter2Theme.primaryCyan, size: 20),
            SizedBox(width: 8),
            Text('CHAPTER 2 GUARDIAN'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              context.read<DashboardCubit>().loadDashboardMetrics();
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          _selectedIndex == 0
              ? 'Command Center Dashboard'
              : _selectedIndex == 1
                  ? 'Agent Activity Timeline'
                  : 'Treasury Mandate Configuration',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Chapter2Theme.surface,
        selectedItemColor: Chapter2Theme.primaryCyan,
        unselectedItemColor: Chapter2Theme.textMuted,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_outlined),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_outlined),
            label: 'Mandate',
          ),
        ],
      ),
    );
  }
}
