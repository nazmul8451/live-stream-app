import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/app_route.dart';
import 'core/dependency.dart';
import 'data/helpers/shared_prefe.dart';
import 'data/services/push_notification_service.dart';
import 'data/services/shorebird_service.dart';
import 'global/widgets/floating_live_stream_overlay.dart';
import 'view/screens/live_stream/controller/agora_live_controller.dart';
import 'data/services/stripe_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phone app is portrait-only (no rotation)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Catch framework errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("🔴 Flutter Error: ${details.exceptionAsString()}\nSTACK TRACE:\n${details.stack}");
  };

  // 1. Load environment variables safely
  // `.env` is a hidden file and Android's asset packaging drops it, so every
  // Android build ran without any config. Fall back to a visible copy.
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Environment file (.env) load error: $e");
    try {
      await dotenv.load(fileName: "assets/config/app.env");
      debugPrint("✅ Loaded environment from assets/config/app.env");
    } catch (e2) {
      debugPrint("⚠️ Environment fallback load error: $e2");
    }
  }

  // 2. Initialize Stripe publishable key safely
  try {
    String? key;
    if (dotenv.isInitialized) {
      key = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    }
    key ??= StripeConfig.publishableKey;
    if (key.isNotEmpty) {
      Stripe.publishableKey = key;
      Stripe.instance.applySettings();
    }
  } catch (e) {
    debugPrint("⚠️ Stripe init error: $e");
  }

  // 3. System UI Overlay Style
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  } catch (_) {}

  // 4. SharedPreferences initialization
  try {
    await SharePrefsHelper.init();
  } catch (e) {
    debugPrint("⚠️ SharePrefsHelper init error: $e");
  }

  // 5. Dependency Injection
  try {
    DependencyInjection.init();
  } catch (e) {
    debugPrint("⚠️ DependencyInjection init error: $e");
  }

  // 6. Initialize Push Notification Service (FCM & Local Notifications)
  try {
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint("⚠️ PushNotificationService init error: $e");
  }

  // 7. Initialize Shorebird Code Push Service
  try {
    await ShorebirdService.instance.init();
  } catch (e) {
    debugPrint("⚠️ ShorebirdService init error: $e");
  }

  String initialRoute = AppRoute.onboarding;
  try {
    final String accessToken = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    final bool isGuest = SharePrefsHelper.isGuest;
    final bool hasSeenOnboarding = SharePrefsHelper.getBool("hasSeenOnboarding");

    if (accessToken.isNotEmpty || isGuest) {
      initialRoute = AppRoute.main;
    } else if (hasSeenOnboarding) {
      initialRoute = AppRoute.login;
    } else {
      initialRoute = AppRoute.onboarding;
    }
  } catch (e) {
    debugPrint("⚠️ Route resolution error: $e");
    initialRoute = AppRoute.onboarding;
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 950),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AREIS',
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: 'Inter',
            // Material 3 paints a surface tint over the app bar as soon as
            // content scrolls under it. On these dark gradient screens that
            // reads as a grey bar appearing out of nowhere, so it is off for
            // every app bar rather than screen by screen.
            appBarTheme: const AppBarTheme(
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color(0xFF8B9BFF),
              selectionColor: Color(0x668B9BFF),
              selectionHandleColor: Color(0xFF8B9BFF),
            ),
          ),
          initialRoute: initialRoute,
          getPages: AppRoute.routes,
          routingCallback: (routing) {
            if (routing != null) {
              AppRoute.routeStream.add(routing.current);
              try {
                if (Get.isRegistered<AgoraLiveController>()) {
                  final ctrl = Get.find<AgoraLiveController>();
                  if (ctrl.isLive.value && !ctrl.isEnding.value) {
                    if (routing.current == AppRoute.hostLive || routing.current == AppRoute.viewerLive) {
                      ctrl.isMinimized.value = false;
                    }
                  } else {
                    ctrl.isMinimized.value = false;
                  }
                }
              } catch (_) {}
            }
          },
          builder: (context, widget) {
            return Stack(
              children: [
                if (widget != null) widget,
                const FloatingLiveStreamOverlay(),
              ],
            );
          },
        );
      },
    );
  }
}
