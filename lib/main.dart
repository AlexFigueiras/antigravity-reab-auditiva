import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ear_training/core/gamification_controller.dart';
import 'package:ear_training/core/spatial_controller.dart';
import 'package:ear_training/services/locale_controller.dart';
import 'package:ear_training/services/theme_controller.dart';
import 'package:ear_training/ui/theme/app_palette.dart';
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
  
  // Inicialização de Variáveis de Ambiente e Persistência [SEGURANÇA/INFRA]
  try {
    await dotenv.load(fileName: ".env");
    await SupabaseService().initialize();
    
    // Inicialização do Google Mobile Ads (AdMob)
    await MobileAds.instance.initialize();
    
    // RIGOR CLÍNICO: Sincronização de Telemetria Offline e Escuta de Hardware
    final buffer = SessionEventBuffer();
    await buffer.init();
    await buffer.syncOfflineTelemetry();
  } catch (e) {
    debugPrint("Erro na inicialização: $e");
  }
  
  // Idioma: carrega a escolha salva antes de montar a UI, para o app já abrir
  // no idioma certo (sem flash). Se nada salvo, segue o idioma do device.
  final localeController = LocaleController();
  await localeController.load();

  // Visual: carrega o tema salvo antes de montar a UI (sem flash). Padrão claro.
  final themeController = ThemeController();
  await themeController.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GamificationController()),
        ChangeNotifierProvider(create: (_) => SpatialController()),
        ChangeNotifierProvider.value(value: localeController),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: const EarTrainingApp(),
    ),
  );
}

class EarTrainingApp extends StatelessWidget {
  const EarTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    // watch no idioma aqui (acima do MaterialApp): trocar de idioma reconstrói
    // o app inteiro com o novo locale.
    final locale = context.watch<LocaleController>().locale;
    // watch no tema aqui (acima do MaterialApp): trocar o visual reconstrói o
    // app inteiro com a nova paleta.
    final palette = context.watch<ThemeController>().palette;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return _buildMaterialApp(const AuthScreen(), locale, palette);

    return FutureBuilder(
      future: Supabase.instance.client
          .from('profiles')
          .select('onboarding_completed')
          .eq('user_id', session.user.id)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMaterialApp(Scaffold(body: Center(child: CircularProgressIndicator(color: palette.primary))), locale, palette);
        }
        if (snapshot.hasError) {
          debugPrint("Erro ao carregar perfil: ${snapshot.error}");
          // Falha de rede/perfil ausente: trata como onboarding pendente.
          return _buildMaterialApp(const OnboardingScreen(), locale, palette);
        }
        final isCompleted = snapshot.data?['onboarding_completed'] ?? false;
        return _buildMaterialApp(isCompleted ? const HomeScreen() : const OnboardingScreen(), locale, palette);
      },
    );
  }

  // Escala o tamanho de fonte de um TextTheme com segurança: só multiplica
  // estilos cujo fontSize não é nulo (apply() exige fontSize != null quando
  // fontSizeFactor != 1.0).
  static TextTheme _scaleTextTheme(TextTheme base, double factor) {
    TextStyle? scale(TextStyle? s) =>
        (s == null || s.fontSize == null) ? s : s.apply(fontSizeFactor: factor);
    return base.copyWith(
      displayLarge: scale(base.displayLarge),
      displayMedium: scale(base.displayMedium),
      displaySmall: scale(base.displaySmall),
      headlineLarge: scale(base.headlineLarge),
      headlineMedium: scale(base.headlineMedium),
      headlineSmall: scale(base.headlineSmall),
      titleLarge: scale(base.titleLarge),
      titleMedium: scale(base.titleMedium),
      titleSmall: scale(base.titleSmall),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }

  Widget _buildMaterialApp(Widget home, Locale? locale, AppPalette palette) {
    final isDark = palette.brightness == Brightness.dark;
    // Base coerente com o brilho da paleta, depois sobrescrevemos as cores de
    // marca. Assim os widgets do Material (diálogos, ripple, etc.) já nascem no
    // claro/escuro certo, e o texto escala igual nos dois temas.
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // i18n: o idioma efetivo vem do LocaleController (escolha do usuário) ou,
      // se null, do device. supportedLocales/delegates devem casar com os .arb.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: base.copyWith(
        scaffoldBackgroundColor: palette.bg,
        primaryColor: palette.primary,
        colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
          primary: palette.primary,
          surface: palette.card,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: palette.card,
          contentTextStyle: TextStyle(color: palette.textMain, fontSize: 15),
          behavior: SnackBarBehavior.floating,
        ),
        // Acessibilidade (Fase 3): mais espaçamento e botões maiores para
        // o público 55-75 anos. O aumento de fonte é feito escalando o
        // textTheme (cujos estilos sempre têm fontSize definido), evitando
        // o assert 'fontSize != null' do TextStyle.apply que era disparado
        // ao escalar Text widgets cujo style não tinha fontSize.
        visualDensity: VisualDensity.comfortable,
        textTheme: _scaleTextTheme(base.textTheme, 1.1),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 56),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: home,
    );
  }
}
