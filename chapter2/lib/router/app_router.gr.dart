// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [DashboardScreen]
class DashboardRoute extends PageRouteInfo<DashboardRouteArgs> {
  DashboardRoute({
    Key? key,
    void Function(int)? onNavigateToTab,
    List<PageRouteInfo>? children,
  }) : super(
         DashboardRoute.name,
         args: DashboardRouteArgs(key: key, onNavigateToTab: onNavigateToTab),
         initialChildren: children,
       );

  static const String name = 'DashboardRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DashboardRouteArgs>(
        orElse: () => const DashboardRouteArgs(),
      );
      return DashboardScreen(
        key: args.key,
        onNavigateToTab: args.onNavigateToTab,
      );
    },
  );
}

class DashboardRouteArgs {
  const DashboardRouteArgs({this.key, this.onNavigateToTab});

  final Key? key;

  final void Function(int)? onNavigateToTab;

  @override
  String toString() {
    return 'DashboardRouteArgs{key: $key, onNavigateToTab: $onNavigateToTab}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DashboardRouteArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [LoginScreen]
class LoginRoute extends PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    Key? key,
    VoidCallback? onLoginSuccess,
    List<PageRouteInfo>? children,
  }) : super(
         LoginRoute.name,
         args: LoginRouteArgs(key: key, onLoginSuccess: onLoginSuccess),
         initialChildren: children,
       );

  static const String name = 'LoginRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () => const LoginRouteArgs(),
      );
      return LoginScreen(key: args.key, onLoginSuccess: args.onLoginSuccess);
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.key, this.onLoginSuccess});

  final Key? key;

  final VoidCallback? onLoginSuccess;

  @override
  String toString() {
    return 'LoginRouteArgs{key: $key, onLoginSuccess: $onLoginSuccess}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginRouteArgs) return false;
    return key == other.key && onLoginSuccess == other.onLoginSuccess;
  }

  @override
  int get hashCode => key.hashCode ^ onLoginSuccess.hashCode;
}

/// generated route for
/// [MainShellScreen]
class MainShellRoute extends PageRouteInfo<void> {
  const MainShellRoute({List<PageRouteInfo>? children})
    : super(MainShellRoute.name, initialChildren: children);

  static const String name = 'MainShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MainShellScreen();
    },
  );
}

/// generated route for
/// [OnboardingScreen]
class OnboardingRoute extends PageRouteInfo<OnboardingRouteArgs> {
  OnboardingRoute({
    Key? key,
    int initialStep = 0,
    List<PageRouteInfo>? children,
  }) : super(
         OnboardingRoute.name,
         args: OnboardingRouteArgs(key: key, initialStep: initialStep),
         initialChildren: children,
       );

  static const String name = 'OnboardingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<OnboardingRouteArgs>(
        orElse: () => const OnboardingRouteArgs(),
      );
      return OnboardingScreen(key: args.key, initialStep: args.initialStep);
    },
  );
}

class OnboardingRouteArgs {
  const OnboardingRouteArgs({this.key, this.initialStep = 0});

  final Key? key;

  final int initialStep;

  @override
  String toString() {
    return 'OnboardingRouteArgs{key: $key, initialStep: $initialStep}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OnboardingRouteArgs) return false;
    return key == other.key && initialStep == other.initialStep;
  }

  @override
  int get hashCode => key.hashCode ^ initialStep.hashCode;
}

/// generated route for
/// [SplashScreen]
class SplashRoute extends PageRouteInfo<void> {
  const SplashRoute({List<PageRouteInfo>? children})
    : super(SplashRoute.name, initialChildren: children);

  static const String name = 'SplashRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SplashScreen();
    },
  );
}
