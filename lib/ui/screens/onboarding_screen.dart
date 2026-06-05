import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../audio_engine/audio_engine.dart';
import '../../core/listening_mode.dart';
import '../../models/audiogram.dart';
import '../../screens/threshold_test_screen.dart';
import '../../services/listening_mode_service.dart';
import '../../services/supabase_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  String? _ageRange;
  String? _mainDifficulty;
  bool? _usesHearingAid;

  bool _saving = false;

  Future<void> _completeOnboarding() async {
    if (_saving) return;
    setState(() => _saving = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Não bloqueia a navegação se a rede falhar ou o perfil não existir:
      // o onboarding sempre avança, mesmo offline.
      try {
        await Supabase.instance.client.from('profiles').update({
          'onboarding_completed': true,
          'age_range': _ageRange,
          'main_difficulty': _mainDifficulty,
          'uses_hearing_aid': _usesHearingAid,
        }).eq('user_id', user.id).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint("Erro ao salvar onboarding (seguindo mesmo assim): $e");
      }
    }
    // Persiste a POLÍTICA DE ESCUTA (com/sem aparelho) localmente — é ela que liga
    // ou desliga o EQ clínico no treino. Sem aparelho → app compensa; com aparelho
    // → EQ desligado (o aparelho já compensa). Ver 0.4/1.1.
    if (_usesHearingAid != null) {
      await ListeningModeService().setFromUsesHearingAid(_usesHearingAid!);
    }
    if (mounted) {
      // Sugere o teste de audição logo após o onboarding — é a fundação da personalização
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const ThresholdTestScreen()),
      );
      if (result != null && mounted) {
        final leftEar = (result['left'] as List<AudiometryPoint>?) ?? [];
        final rightEar = (result['right'] as List<AudiometryPoint>?) ?? [];
        if (leftEar.isNotEmpty || rightEar.isNotEmpty) {
          try {
            final audiogram = Audiogram(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              patientId: 'local',
              date: DateTime.now(),
              leftEar: leftEar,
              rightEar: rightEar,
            );
            await SupabaseService().saveAudiogram(audiogram);
          } catch (e) {
            debugPrint("Erro ao salvar audiograma do onboarding: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Não consegui salvar o teste de audição. Verifique a conexão e refaça em Início."),
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: _page == 0
              ? _buildPage0()
              : _page == 1
                  ? _buildPage1()
                  : _page == 2
                      ? _buildPage2()
                      : _buildPage3(),
        ),
      ),
    );
  }

  Widget _buildPage0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text("Bem-vindo ao BOSYN", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text(
          "Este app foi feito para ajudar você a entender melhor as palavras — mesmo no barulho, mesmo ao telefone.",
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 16),
        const Text(
          "Com alguns minutos de treino por dia, seu cérebro aprende a distinguir sons que ficaram difíceis com o tempo.",
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
        ),
        const Spacer(),
        _nextButton("Vamos começar"),
      ],
    );
  }

  Widget _buildPage1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text("Qual é a sua faixa de idade?", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        ...[
          ("Menos de 50 anos", "menor_50"),
          ("50 a 65 anos", "50_65"),
          ("65 a 75 anos", "65_75"),
          ("Mais de 75 anos", "maior_75"),
        ].map((opt) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _optionButton(opt.$1, selected: _ageRange == opt.$2, onTap: () => setState(() => _ageRange = opt.$2)),
        )),
        const Spacer(),
        _nextButton("Continuar", enabled: _ageRange != null),
      ],
    );
  }

  Widget _buildPage2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text("O que mais dificulta sua audição?", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Escolha a que mais combina com você.", style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 32),
        ...[
          ("Entender o que as pessoas falam", "entender_fala"),
          ("Ouvir no barulho (restaurante, TV)", "barulho"),
          ("Escutar ao telefone", "telefone"),
          ("Perceber de onde vem o som", "localizacao"),
        ].map((opt) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _optionButton(opt.$1, selected: _mainDifficulty == opt.$2, onTap: () => setState(() => _mainDifficulty = opt.$2)),
        )),
        const Spacer(),
        _nextButton("Continuar", enabled: _mainDifficulty != null),
      ],
    );
  }

  Widget _buildPage3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text("Você usa aparelho auditivo?", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          "Isso decide como você vai fazer o teste e os treinos. Use sempre do mesmo jeito.",
          style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 24),
        _optionButton("Sim, uso regularmente", selected: _usesHearingAid == true, onTap: () => setState(() => _usesHearingAid = true)),
        const SizedBox(height: 12),
        _optionButton("Não uso aparelho", selected: _usesHearingAid == false, onTap: () => setState(() => _usesHearingAid = false)),
        // Explica em frase curta o que muda — clareza para o idoso (0.4).
        if (_usesHearingAid != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.10),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF8AB4F8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (_usesHearingAid == true
                            ? ListeningMode.aided
                            : ListeningMode.unaided)
                        .instruction,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        const Text("Ajuste o volume do seu fone até o tom soar confortável:", style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: () => AudioRehabEngine().playCalibrationTone(frequencyHz: 1000.0, durationSeconds: 2.0),
            icon: const Icon(Icons.volume_up),
            label: const Text("Tocar tom de teste"),
          ),
        ),
        const Spacer(),
        _nextButton("Entrar no app", enabled: _usesHearingAid != null),
      ],
    );
  }

  Widget _optionButton(String label, {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB).withOpacity(0.15) : const Color(0xFF1A1A1A),
          border: Border.all(color: selected ? const Color(0xFF2563EB) : Colors.white12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 15)),
      ),
    );
  }

  Widget _nextButton(String label, {bool enabled = true}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFF2563EB) : Colors.white12,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: enabled
            ? () {
                if (_page < 3) {
                  setState(() => _page++);
                } else {
                  _completeOnboarding();
                }
              }
            : null,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
