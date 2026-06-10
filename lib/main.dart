import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Channel used to display FCM messages that arrive while the app is in the
/// foreground on Android (Android never shows those automatically).
const _androidChannel = AndroidNotificationChannel(
  'messages',
  'Messages',
  description: 'New trip messages and announcements',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Request notification permission early
  final settings = await FirebaseMessaging.instance.requestPermission();
  debugPrint('FCM: permission status = ${settings.authorizationStatus}');

  // iOS: show notifications even when the app is in the foreground
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
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  String? _currentToken;

  @override
  void initState() {
    super.initState();
    _setupForegroundNotifications();
    _setupNotificationHandlers();
    _setupTokenLifecycle();
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    _onTokenRefreshSub?.cancel();
    super.dispose();
  }

  // ── Foreground display (Android only) ───────────────────────────────────
  Future<void> _setupForegroundNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return;

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final tripId = response.payload;
        if (tripId != null && tripId.isNotEmpty) {
          ref.read(routerProvider).go('/trips/$tripId/messages');
        }
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['tripId'] as String?,
      );
    });
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

  /// Fetches the FCM token, tolerating the iOS race where the APNS token
  /// isn't available yet (getToken throws apns-token-not-set until it is).
  Future<String?> _getFcmToken() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (!kIsWeb && Platform.isIOS) {
          final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken == null) {
            debugPrint('FCM: APNS token not ready (attempt ${attempt + 1})');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        }
        return await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint('FCM: getToken failed (attempt ${attempt + 1}): $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    debugPrint('FCM: giving up fetching token');
    return null;
  }

  void _setupTokenLifecycle() {
    // Save/remove token when auth state changes (fireImmediately covers the
    // already-logged-in cold start and hot restart cases)
    ref.listenManual(currentUidProvider, fireImmediately: true,
        (prev, next) async {
      if (prev == next && _currentToken != null) return;

      final token = await _getFcmToken();
      debugPrint('FCM: token = ${token ?? "null"}');
      if (token == null) return;
      _currentToken = token;

      final userRepo = ref.read(userRepositoryProvider);

      if (prev != null && prev != next) {
        try {
          await userRepo.removeFcmToken(prev, token);
          debugPrint('FCM: removed token from user $prev');
        } catch (e) {
          debugPrint('FCM: failed to remove token: $e');
        }
      }

      if (next != null) {
        try {
          await userRepo.addFcmToken(next, token);
          debugPrint('FCM: saved token for user $next');
        } catch (e) {
          debugPrint('FCM: failed to save token: $e');
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
          debugPrint('FCM: failed to remove old token: $e');
        }
      }

      _currentToken = newToken;
      try {
        await userRepo.addFcmToken(uid, newToken);
        debugPrint('FCM: saved refreshed token for user $uid');
      } catch (e) {
        debugPrint('FCM: failed to save refreshed token: $e');
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
