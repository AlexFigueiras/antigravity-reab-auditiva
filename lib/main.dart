import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ear_training/core/gamification_controller.dart';
import 'package:ear_training/core/spatial_controller.dart';
import 'package:ear_training/ui/screens/home_screen.dart';
import 'package:ear_training/ui/screens/auth_screen.dart';
import 'package:ear_training/ui/screens/onboarding_screen.dart';
import 'package:ear_training/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ear_training/services/event_buffer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização de Variáveis de Ambiente e Persistência [SEGURANÇA/INFRA]
  try {
    await dotenv.load(fileName: ".env");
    await SupabaseService().initialize();
    
    // RIGOR CLÍNICO: Sincronização de Telemetria Offline e Escuta de Hardware
    final buffer = SessionEventBuffer();
    await buffer.init();
    await buffer.syncOfflineTelemetry();
  } catch (e) {
    debugPrint("Erro na inicialização: $e");
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GamificationController()),
        ChangeNotifierProvider(create: (_) => SpatialController()),
      ],
      child: const EarTrainingApp(),
    ),
  );
}

class EarTrainingApp extends StatelessWidget {
  const EarTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return _buildMaterialApp(const AuthScreen());

    return FutureBuilder(
      future: Supabase.instance.client
          .from('profiles')
          .select('onboarding_completed')
          .eq('user_id', session.user.id)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMaterialApp(const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF4F8DF7)))));
        }
        if (snapshot.hasError) {
          debugPrint("Erro ao carregar perfil: ${snapshot.error}");
          // Falha de rede/perfil ausente: trata como onboarding pendente.
          return _buildMaterialApp(const OnboardingScreen());
        }
        final isCompleted = snapshot.data?['onboarding_completed'] ?? false;
        return _buildMaterialApp(isCompleted ? const HomeScreen() : const OnboardingScreen());
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

  Widget _buildMaterialApp(Widget home) {
    return MaterialApp(
      title: 'BOSYN - Auditory Rehabilitation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101418),
        primaryColor: const Color(0xFF4F8DF7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4F8DF7),
          surface: Color(0xFF1B2128),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1B2128),
          contentTextStyle: TextStyle(color: Color(0xFFF2F4F7), fontSize: 15),
          behavior: SnackBarBehavior.floating,
        ),
        // Acessibilidade (Fase 3): mais espaçamento e botões maiores para
        // o público 55-75 anos. O aumento de fonte é feito escalando o
        // textTheme (cujos estilos sempre têm fontSize definido), evitando
        // o assert 'fontSize != null' do TextStyle.apply que era disparado
        // ao escalar Text widgets cujo style não tinha fontSize.
        visualDensity: VisualDensity.comfortable,
        textTheme: _scaleTextTheme(ThemeData.dark().textTheme, 1.1),
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
