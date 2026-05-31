import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/trips/trip_list_screen.dart';
import 'screens/trip/trip_shell.dart';
import 'screens/trip/dashboard_screen.dart';
import 'screens/trip/lodging_screen.dart';
import 'screens/trip/supplies_screen.dart';
import 'screens/trip/carpool_screen.dart';
import 'screens/trip/group_screen.dart';
import 'screens/trip/messages_screen.dart';
import 'screens/trip/expenses_screen.dart';
import 'screens/trip/manage_screen.dart';
import 'screens/trip/history_screen.dart';
import 'screens/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;
      final onAuthScreen = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!isLoggedIn && !onAuthScreen) return '/login';
      if (isLoggedIn && onAuthScreen) return '/trips';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/trips', builder: (_, __) => const TripListScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

      // 5-tab trip shell
      ShellRoute(
        builder: (context, state, child) => TripShell(child: child),
        routes: [
          GoRoute(
            path: '/trips/:tripId/dashboard',
            builder: (_, s) =>
                DashboardScreen(tripId: s.pathParameters['tripId']!),
          ),
          GoRoute(
            path: '/trips/:tripId/lodging',
            builder: (_, s) =>
                LodgingScreen(tripId: s.pathParameters['tripId']!),
          ),
          GoRoute(
            path: '/trips/:tripId/supplies',
            builder: (_, s) =>
                SuppliesScreen(tripId: s.pathParameters['tripId']!),
          ),
          GoRoute(
            path: '/trips/:tripId/carpool',
            builder: (_, s) =>
                CarpoolScreen(tripId: s.pathParameters['tripId']!),
          ),
          GoRoute(
            path: '/trips/:tripId/messages',
            builder: (_, s) =>
                MessagesScreen(tripId: s.pathParameters['tripId']!),
          ),
        ],
      ),

      // Group screen (pushed from dashboard, no longer a tab)
      GoRoute(
        path: '/trips/:tripId/group',
        builder: (_, s) =>
            GroupScreen(tripId: s.pathParameters['tripId']!),
      ),

      // Pushed routes (full-screen, no shell)
      GoRoute(
        path: '/trips/:tripId/expenses',
        builder: (_, s) =>
            ExpensesScreen(tripId: s.pathParameters['tripId']!),
      ),
      GoRoute(
        path: '/trips/:tripId/manage',
        builder: (_, s) =>
            ManageScreen(tripId: s.pathParameters['tripId']!),
      ),
      GoRoute(
        path: '/trips/:tripId/history',
        builder: (_, s) =>
            HistoryScreen(tripId: s.pathParameters['tripId']!),
      ),
    ],
  );
});
