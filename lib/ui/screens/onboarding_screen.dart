import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../audio_engine/audio_engine.dart';
import 'home_screen.dart';

/// SCREEN: Onboarding e Calibração [ORQUESTRADOR]
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Atualiza status no Supabase [SSOT]
      await Supabase.instance.client
          .from('profiles')
          .update({'onboarding_completed': true})
          .eq('user_id', user.id);
    }
    
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: const Color(0xFF0A0A0A),
      pages: [
        PageViewModel(
          title: "NEUROPLASTICIDADE",
          body: "O BOSYN utiliza o método de 'Minimal Pairs' para remapear como seu cérebro processa frequências agudas perdida.",
          decoration: _pageDecoration(),
        ),
        PageViewModel(
          title: "CHECK DE HARDWARE",
          body: "Ajuste o volume do seu dispositivo até que o tom de calibração esteja confortável e nítido.",
          footer: _buildCalibrationControl(),
          decoration: _pageDecoration(),
        ),
        PageViewModel(
          title: "MODO COCKPIT",
          body: "Você está prestes a entrar em um ambiente de treinamento de alta precisão. Concentração total exigida.",
          decoration: _pageDecoration(),
        ),
      ],
      onDone: () => _completeOnboarding(context),
      onSkip: () => _completeOnboarding(context),
      showSkipButton: true,
      skip: const Text("PULAR", style: TextStyle(color: Colors.white24, fontSize: 10)),
      next: const Icon(Icons.arrow_forward, color: Color(0xFF00FF41)),
      done: const Text("ENTRAR NO COCKPIT", style: TextStyle(color: Color(0xFF00FF41), fontWeight: FontWeight.bold, fontSize: 10)),
      dotsDecorator: const DotsDecorator(
        size: Size(10, 10),
        color: Colors.white12,
        activeColor: Color(0xFF00FF41),
        activeSize: Size(22, 10),
        activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
      ),
    );
  }

  Widget _buildCalibrationControl() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: const Color(0xFF00FF41),
              side: const BorderSide(color: Color(0xFF00FF41)),
              shape: const BeveledRectangleBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: () => AudioRehabEngine().playCalibrationTone(frequencyHz: 1000.0, durationSeconds: 2.0),
            icon: const Icon(Icons.volume_up),
            label: const Text("TESTAR TOM (1kHz)", style: TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  PageDecoration _pageDecoration() {
    return const PageDecoration(
      titleTextStyle: TextStyle(color: Color(0xFF00FF41), fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace', letterSpacing: 2),
      bodyTextStyle: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'monospace'),
      pageColor: Color(0xFF0A0A0A),
      imagePadding: EdgeInsets.zero,
    );
  }
}
