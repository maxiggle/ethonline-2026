import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/splash/splash_screen.dart';
import 'package:chapter2/features/auth/view/login_screen.dart';
import 'package:chapter2/features/onboarding/view/onboarding_screen.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/features/services/remote/services_api_service.dart';
import 'package:chapter2/features/services/view/purchase_detail_screen.dart';
import 'package:chapter2/features/settings/view/settings_screen.dart';
import 'package:chapter2/features/shell/main_shell_screen.dart';
import 'package:chapter2/features/x402_approvals/view/x402_approvals_screen.dart';
import 'package:flutter/material.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SplashRoute.page, initial: true),
    AutoRoute(page: LoginRoute.page),
    AutoRoute(page: OnboardingRoute.page),
    AutoRoute(page: MainShellRoute.page),
    AutoRoute(page: SettingsRoute.page),
    AutoRoute(page: X402ApprovalsRoute.page),
    AutoRoute(page: PurchaseDetailRoute.page),
  ];
}
