import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_app.dart';
import 'services/firebase_service.dart';
import 'services/cross_platform_auth_service.dart';
import 'services/ad_service.dart';
import 'services/push_notification_service.dart';
import 'providers/theme_provider.dart';
import 'themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FirebaseService.initialize();

    final authService = CrossPlatformAuthService();
    await authService.initialize();

    await PushNotificationService().initialize();

    if (AdService.isSupported) {
      await MobileAds.instance.initialize();
      AdService().initializeAds();
    }

    print('✅ App initialized successfully');
  } catch (e) {
    print('❌ App initialization failed: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const BudgetDealsApp());
}

class BudgetDealsApp extends StatelessWidget {
  const BudgetDealsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Budget Deals',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/main': (context) => const MainApp(),
            },
          );
        },
      ),
    );
  }
}
