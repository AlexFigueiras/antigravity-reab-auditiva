import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../audio_engine/audio_engine.dart';
import '../../l10n/gen/app_localizations.dart';
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

  ColorScheme get _cs => Theme.of(context).colorScheme;

  Future<void> _completeOnboarding() async {
    if (_saving) return;
    setState(() => _saving = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
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
    if (_usesHearingAid != null) {
      await ListeningModeService().setFromUsesHearingAid(_usesHearingAid!);
    }
    if (mounted) {
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
                SnackBar(
                  content: Text(AppLocalizations.of(context).onboardingSaveError),
                  duration: const Duration(seconds: 5),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Text(l10n.onboardingWelcomeTitle,
            style: TextStyle(
                color: _cs.onSurface, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(
          l10n.onboardingWelcomeBody1,
          style: TextStyle(color: _cs.onSurfaceVariant, fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.onboardingWelcomeBody2,
          style: TextStyle(color: _cs.onSurfaceVariant, fontSize: 16, height: 1.6),
        ),
        const Spacer(),
        _nextButton(l10n.onboardingWelcomeButton),
      ],
    );
  }

  Widget _buildPage1() {
    final l10n = AppLocalizations.of(context);
    final options = [
      (l10n.onboardingAgeUnder50, "menor_50"),
      (l10n.onboardingAge50to65, "50_65"),
      (l10n.onboardingAge65to75, "65_75"),
      (l10n.onboardingAgeOver75, "maior_75"),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Text(l10n.onboardingAgeTitle,
            style: TextStyle(
                color: _cs.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        ...options.map((opt) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _optionButton(opt.$1,
              selected: _ageRange == opt.$2,
              onTap: () => setState(() => _ageRange = opt.$2)),
        )),
        const Spacer(),
        _nextButton(l10n.onboardingContinue, enabled: _ageRange != null),
      ],
    );
  }

  Widget _buildPage2() {
    final l10n = AppLocalizations.of(context);
    final options = [
      (l10n.onboardingDifficultyUnderstand, "entender_fala"),
      (l10n.onboardingDifficultyNoise, "barulho"),
      (l10n.onboardingDifficultyPhone, "telefone"),
      (l10n.onboardingDifficultyDirection, "localizacao"),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Text(l10n.onboardingDifficultyTitle,
            style: TextStyle(
                color: _cs.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l10n.onboardingDifficultySubtitle,
            style: TextStyle(color: _cs.onSurfaceVariant, fontSize: 14)),
        const SizedBox(height: 32),
        ...options.map((opt) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _optionButton(opt.$1,
              selected: _mainDifficulty == opt.$2,
              onTap: () => setState(() => _mainDifficulty = opt.$2)),
        )),
        const Spacer(),
        _nextButton(l10n.onboardingContinue, enabled: _mainDifficulty != null),
      ],
    );
  }

  Widget _buildPage3() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Text(l10n.onboardingHearingAidTitle,
            style: TextStyle(
                color: _cs.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingHearingAidSubtitle,
          style: TextStyle(color: _cs.onSurfaceVariant, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 24),
        _optionButton(l10n.onboardingHearingAidYes,
            selected: _usesHearingAid == true,
            onTap: () => setState(() => _usesHearingAid = true)),
        const SizedBox(height: 12),
        _optionButton(l10n.onboardingHearingAidNo,
            selected: _usesHearingAid == false,
            onTap: () => setState(() => _usesHearingAid = false)),
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
                    _usesHearingAid == true
                        ? l10n.listeningModeAided_instruction
                        : l10n.listeningModeUnaided_instruction,
                    style: TextStyle(
                        color: _cs.onSurface, fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Divider(color: _cs.onSurfaceVariant.withValues(alpha: 0.15)),
        const SizedBox(height: 16),
        Text(l10n.onboardingVolumeHint,
            style: TextStyle(color: _cs.onSurfaceVariant, fontSize: 14)),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cs.surface,
              foregroundColor: _cs.onSurface,
              side: BorderSide(color: _cs.onSurfaceVariant.withValues(alpha: 0.25)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: () =>
                AudioRehabEngine().playCalibrationTone(frequencyHz: 1000.0, durationSeconds: 2.0),
            icon: const Icon(Icons.volume_up),
            label: Text(l10n.onboardingPlayTone),
          ),
        ),
        const Spacer(),
        _nextButton(l10n.onboardingEnterApp, enabled: _usesHearingAid != null),
      ],
    );
  }

  Widget _optionButton(String label,
      {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? _cs.primary.withValues(alpha: 0.15)
              : _cs.surface,
          border: Border.all(
              color: selected ? _cs.primary : _cs.onSurfaceVariant.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? _cs.primary : _cs.onSurface, fontSize: 15)),
      ),
    );
  }

  Widget _nextButton(String label, {bool enabled = true}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? _cs.primary : _cs.onSurfaceVariant.withValues(alpha: 0.15),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
