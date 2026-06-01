import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Request notification permission early
  await FirebaseMessaging.instance.requestPermission();

  // Show notifications even when the app is in the foreground
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const ProviderScope(child: FrientrippApp()));
}

class FrientrippApp extends ConsumerStatefulWidget {
  const FrientrippApp({super.key});

  @override
  ConsumerState<FrientrippApp> createState() => _FrientrippAppState();
}

class _FrientrippAppState extends ConsumerState<FrientrippApp> {
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  String? _currentToken;

  @override
  void initState() {
    super.initState();
    _setupNotificationHandlers();
    _setupTokenLifecycle();
  }

  @override
  void dispose() {
    _onMessageOpenedSub?.cancel();
    _onTokenRefreshSub?.cancel();
    super.dispose();
  }

  // ── Notification tap handling ───────────────────────────────────────────
  void _setupNotificationHandlers() {
    // App was in background → user tapped notification
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App was terminated → user tapped notification (cold start)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        // Defer to let the router initialize
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(message);
        });
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final tripId = message.data['tripId'];
    if (tripId != null && tripId is String && tripId.isNotEmpty) {
      ref.read(routerProvider).go('/trips/$tripId/messages');
    }
  }

  // ── FCM token lifecycle ─────────────────────────────────────────────────
  void _setupTokenLifecycle() {
    // Save/remove token when auth state changes
    ref.listenManual(currentUidProvider, (prev, next) async {
      final token = await FirebaseMessaging.instance.getToken();
      developer.log('FCM token: ${token ?? "null"}', name: 'FCM');
      if (token == null) return;
      _currentToken = token;

      final userRepo = ref.read(userRepositoryProvider);

      if (prev != null && prev != next) {
        try {
          await userRepo.removeFcmToken(prev, token);
          developer.log('Removed FCM token from user $prev', name: 'FCM');
        } catch (e) {
          developer.log('Failed to remove FCM token: $e', name: 'FCM');
        }
      }

      if (next != null) {
        try {
          await userRepo.addFcmToken(next, token);
          developer.log('Saved FCM token for user $next', name: 'FCM');
        } catch (e) {
          developer.log('Failed to save FCM token: $e', name: 'FCM');
        }
      }
    });

    // Handle token refreshes
    _onTokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;

      final userRepo = ref.read(userRepositoryProvider);

      if (_currentToken != null && _currentToken != newToken) {
        try {
          await userRepo.removeFcmToken(uid, _currentToken!);
        } catch (e) {
          developer.log('Failed to remove old FCM token: $e', name: 'FCM');
        }
      }

      _currentToken = newToken;
      try {
        await userRepo.addFcmToken(uid, newToken);
        developer.log('Saved refreshed FCM token for user $uid', name: 'FCM');
      } catch (e) {
        developer.log('Failed to save refreshed FCM token: $e', name: 'FCM');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Frientrip',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
