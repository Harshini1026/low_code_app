import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/templates/templates_screen.dart';
import '../../screens/builder/builder_screen.dart';
import '../../screens/preview/preview_screen.dart';
import '../../screens/publish/publish_screen.dart';

class AppRouter {
  static final _key = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _key,
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth       = context.read<AuthProvider>();
      final loggedIn   = auth.isAuthenticated; // ✅ correct getter name
      final path       = state.fullPath ?? '';

      // Always allow splash through
      if (path == '/splash') return null;

      // Not logged in → send to login (except if already going there)
      if (!loggedIn && path != '/login') return '/login';

      // Logged in but on login page → send to home
      if (loggedIn && path == '/login') return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (c, s) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (c, s) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (c, s) => const HomeScreen(),
      ),
      GoRoute(
        path: '/templates',
        builder: (c, s) => const TemplatesScreen(),
      ),
      GoRoute(
        path: '/builder/:projectId',
        builder: (c, s) => BuilderScreen(
          projectId: s.pathParameters['projectId']!,
        ),
      ),
      GoRoute(
        path: '/preview/:projectId',
        builder: (c, s) => PreviewScreen(
          projectId: s.pathParameters['projectId']!,
        ),
      ),
      GoRoute(
        path: '/publish/:projectId',
        builder: (c, s) => PublishScreen(
          projectId: s.pathParameters['projectId']!,
        ),
      ),
    ],
  );
}