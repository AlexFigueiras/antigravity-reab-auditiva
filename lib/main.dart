import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ear_training/core/gamification_controller.dart';
import 'package:ear_training/core/spatial_controller.dart';
import 'package:ear_training/core/theme_notifier.dart';
import 'package:ear_training/services/locale_controller.dart';
import 'package:ear_training/theme/app_theme.dart';
import 'package:ear_training/l10n/gen/app_localizations.dart';
import 'package:ear_training/ui/screens/home_screen.dart';
import 'package:ear_training/ui/screens/auth_screen.dart';
import 'package:ear_training/ui/screens/onboarding_screen.dart';
import 'package:ear_training/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ear_training/services/event_buffer.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    await SupabaseService().initialize();
    await MobileAds.instance.initialize();
    final buffer = SessionEventBuffer();
    await buffer.init();
    await buffer.syncOfflineTelemetry();
  } catch (e) {
    debugPrint("Erro na inicialização: $e");
  }

  final localeController = LocaleController();
  await localeController.load();

  final themeNotifier = ThemeNotifier();
  await themeNotifier.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GamificationController()),
        ChangeNotifierProvider(create: (_) => SpatialController()),
        ChangeNotifierProvider.value(value: localeController),
        ChangeNotifierProvider.value(value: themeNotifier),
      ],
      child: const EarTrainingApp(),
    ),
  );
}

class EarTrainingApp extends StatelessWidget {
  const EarTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final themeMode = context.watch<ThemeNotifier>().mode;
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) return _buildApp(const AuthScreen(), locale, themeMode);

    return FutureBuilder(
      future: Supabase.instance.client
          .from('profiles')
          .select('onboarding_completed')
          .eq('user_id', session.user.id)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildApp(
            const Scaffold(body: Center(child: CircularProgressIndicator())),
            locale,
            themeMode,
          );
        }
        if (snapshot.hasError) {
          return _buildApp(const OnboardingScreen(), locale, themeMode);
        }
        final isCompleted = snapshot.data?['onboarding_completed'] ?? false;
        return _buildApp(
          isCompleted ? const HomeScreen() : const OnboardingScreen(),
          locale,
          themeMode,
        );
      },
    );
  }

  Widget _buildApp(Widget home, Locale? locale, ThemeMode themeMode) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: home,
    );
  }
}
