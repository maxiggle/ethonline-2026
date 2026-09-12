import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/approval/cubit/approval_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final appRouter = AppRouter();

class Chapter2App extends StatelessWidget {
  const Chapter2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(authService: locator<AuthService>()),
        ),
        BlocProvider<DashboardCubit>(
          create: (_) =>
              DashboardCubit(apiService: locator<Chapter2ApiService>()),
        ),
        BlocProvider<ApprovalCubit>(
          create: (_) =>
              ApprovalCubit(apiService: locator<Chapter2ApiService>()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Chapter 2 Guardian',
        theme: Chapter2Theme.darkTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter.config(),
      ),
    );
  }
}
