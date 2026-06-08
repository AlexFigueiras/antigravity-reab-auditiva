import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../audio_engine/audio_engine.dart';
import '../../models/audiogram.dart';
import '../../core/outcome_test_bank.dart';
import '../../core/adaptive_staircase.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/audio_accessibility.dart';
import '../../services/locale_controller.dart';
import '../../services/supabase_service.dart';

class OutcomeTestScreen extends StatefulWidget {
  const OutcomeTestScreen({super.key});

  @override
  State<OutcomeTestScreen> createState() => _OutcomeTestScreenState();
}

class _OutcomeTestScreenState extends State<OutcomeTestScreen> {
  ColorScheme get _cs => Theme.of(context).colorScheme;
  Color get _card => _cs.surface;
  Color get _primary => _cs.primary;
  Color get _textMain => _cs.onSurface;
  Color get _textSoft => _cs.onSurfaceVariant;
  Color get _correctColor => _cs.tertiary;

  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();

  // Staircase 2-down/1-up para estimar o SRT (Speech Reception Threshold)
  final _srtStaircase = AdaptiveStaircase(
    start: 10.0,
    floor: -10.0,
    ceiling: 20.0,
    stepDown: 2.0,
    stepUp: 2.0,
    minReversalsForEstimate: 6,
  );

  bool _isTesting = false;
  bool _finished = false;
  int _currentTrial = 0;
  static const int _totalTrials = 20;

  MatrixSentence? _currentSentence;
  
  // Escolhas do usuário para a frase atual (índice 0 a 4)
  String? _selectedName;
  String? _selectedVerb;
  String? _selectedNumber;
  String? _selectedNoun;
  String? _selectedAdjective;

  int _activeCategoryIndex = 0; // 0: Nome, 1: Verbo, 2: Número, 3: Substantivo, 4: Adjetivo
  int _correctWordsInLastTrial = 0;
  bool _evaluated = false;

  final List<Map<String, dynamic>> _testLog = [];
  int _correctTrialsCount = 0;
  double _finalSrt = 0.0;

  @override
  void initState() {
    super.initState();
    // Inicializa o motor de áudio caso necessário
    _engine.initializeEngine(Audiogram(
      id: "OUTCOME_TEST",
      date: DateTime.now(),
      patientId: "OUTCOME",
      leftEar: [],
      rightEar: [],
    ));
    // Mesmo referencial de volume do teste de audição e dos treinos: esta tela
    // inicializa o motor sozinha (não passa pelo AudioServiceManager), então o
    // ramp precisa ser chamado aqui. Sem isso, o SRT seria medido num volume
    // possivelmente diferente do teste de audição. Ver SYSTEM.md §4.2.
    AudioAccessibility.rampToReferenceVolume();
  }

  @override
  void dispose() {
    _engine.stop();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _isTesting = true;
      _finished = false;
      _currentTrial = 0;
      _correctTrialsCount = 0;
      _testLog.clear();
      _srtStaircase.reset();
    });
    _nextTrial();
  }

  void _nextTrial() {
    if (_currentTrial >= _totalTrials) {
      _finishTest();
      return;
    }

    final lang = context.read<LocaleController>().audioLanguageCode;
    setState(() {
      _currentTrial++;
      _currentSentence = lang == 'en'
          ? generateRandomMatrixSentenceEn()
          : generateRandomMatrixSentence();
      _selectedName = null;
      _selectedVerb = null;
      _selectedNumber = null;
      _selectedNoun = null;
      _selectedAdjective = null;
      _activeCategoryIndex = 0;
      _evaluated = false;
    });

    _playStimulus();
  }

  Future<void> _playStimulus() async {
    if (_currentSentence == null) return;
    await _engine.playCocktailStimulus(
      text: _currentSentence!.text,
      snrDb: _srtStaircase.current,
      noiseEnvironment: 'RESTAURANTE',
    );
  }

  void _selectWord(String word) {
    if (_evaluated) return;
    setState(() {
      switch (_activeCategoryIndex) {
        case 0:
          _selectedName = word;
          break;
        case 1:
          _selectedVerb = word;
          break;
        case 2:
          _selectedNumber = word;
          break;
        case 3:
          _selectedNoun = word;
          break;
        case 4:
          _selectedAdjective = word;
          break;
      }

      if (_activeCategoryIndex < 4) {
        _activeCategoryIndex++;
      }
    });
  }

  bool get _isSentenceComplete =>
      _selectedName != null &&
      _selectedVerb != null &&
      _selectedNumber != null &&
      _selectedNoun != null &&
      _selectedAdjective != null;

  void _confirmSentence() {
    if (!_isSentenceComplete || _evaluated) return;

    final target = _currentSentence!;
    int correctWords = 0;
    if (_selectedName == target.name) correctWords++;
    if (_selectedVerb == target.verb) correctWords++;
    if (_selectedNumber == target.number) correctWords++;
    if (_selectedNoun == target.noun) correctWords++;
    if (_selectedAdjective == target.adjective) correctWords++;

    // Na audiologia, considera-se acerto se o paciente acertou 50% ou mais das palavras
    final bool isTrialCorrect = correctWords >= 3;

    setState(() {
      _evaluated = true;
      _correctWordsInLastTrial = correctWords;
      if (isTrialCorrect) {
        _correctTrialsCount++;
      }
    });

    _srtStaircase.respond(isTrialCorrect);

    _testLog.add({
      'trial': _currentTrial,
      'target': target.text,
      'selected': '$_selectedName $_selectedVerb $_selectedNumber $_selectedNoun $_selectedAdjective',
      'correct_words': correctWords,
      'success': isTrialCorrect,
      'snr_db': _srtStaircase.current,
    });
  }

  Future<void> _finishTest() async {
    final srt = _srtStaircase.estimate ?? _srtStaircase.current;
    setState(() {
      _isTesting = false;
      _finished = true;
      _finalSrt = srt;
    });

    try {
      await _supabase.saveOutcomeTest(
        srtDb: srt,
        totalTrials: _totalTrials,
        correctAnswers: _correctTrialsCount,
        metadata: {
          'log': _testLog,
        },
      );
    } catch (e) {
      debugPrint("Erro ao salvar teste de desfecho: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).outcomeTestTitle,
          style: TextStyle(color: _textMain, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: _textMain),
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _finished
              ? _buildResultView()
              : _isTesting
                  ? _buildTestView()
                  : _buildWelcomeView(),
        ),
      ),
    );
  }

  Widget _buildWelcomeView() {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.hearing, color: _primary, size: 72),
        const SizedBox(height: 28),
        Text(
          l10n.outcomeTestMatrixTitle,
          style: TextStyle(color: _textMain, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.outcomeTestDescription1,
          style: TextStyle(color: _textSoft, fontSize: 16, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.outcomeTestDescription2,
          style: TextStyle(color: _textSoft, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _startTest,
            child: Text(
              l10n.outcomeTestStart,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestView() {
    final l10n = AppLocalizations.of(context);
    final lang = context.read<LocaleController>().audioLanguageCode;
    final isEn = lang == 'en';
    final categories = isEn
        ? ["Name", "Verb", "Number", "Colour", "Object"]
        : ["Nome", "Verbo", "Número", "Objeto", "Cor"];
    final List<List<String>> vocabularies = isEn
        ? [MATRIX_NAMES_EN, MATRIX_VERBS_EN, MATRIX_NUMBERS_EN, MATRIX_ADJECTIVES_EN, MATRIX_NOUNS_EN]
        : [MATRIX_NAMES, MATRIX_VERBS, MATRIX_NUMBERS, MATRIX_NOUNS, MATRIX_ADJECTIVES];

    final currentVocab = vocabularies[_activeCategoryIndex];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.outcomeTestSentenceProgress(
                _currentTrial.toString(), _totalTrials.toString()),
              style: TextStyle(color: _textSoft, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              l10n.outcomeTestDifficulty((-_srtStaircase.current.toInt()).toString()),
              style: TextStyle(color: _primary.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _currentTrial / _totalTrials,
          backgroundColor: _textSoft.withValues(alpha: 0.12),
          color: _primary,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 24),

        // Frase reconstruída (5 caixas de palavra)
        Row(
          children: List.generate(5, (index) {
            final isFocused = index == _activeCategoryIndex;
            String text = categories[index];
            bool hasValue = false;
            if (index == 0 && _selectedName != null) { text = _selectedName!; hasValue = true; }
            if (index == 1 && _selectedVerb != null) { text = _selectedVerb!; hasValue = true; }
            if (index == 2 && _selectedNumber != null) { text = _selectedNumber!; hasValue = true; }
            if (index == 3 && _selectedNoun != null) { text = _selectedNoun!; hasValue = true; }
            if (index == 4 && _selectedAdjective != null) { text = _selectedAdjective!; hasValue = true; }

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_evaluated) return;
                  setState(() {
                    _activeCategoryIndex = index;
                  });
                },
                child: Container(
                  height: 60,
                  margin: EdgeInsets.only(right: index < 4 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isFocused ? _primary.withValues(alpha: 0.12) : _card,
                    border: Border.all(
                      color: isFocused ? _primary : (hasValue ? _textSoft.withValues(alpha: 0.35) : Colors.transparent),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    text,
                    style: TextStyle(
                      color: hasValue ? _textMain : _textSoft.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Botão de Replay
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _textSoft.withValues(alpha: 0.35)),
              foregroundColor: _textSoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _playStimulus,
            icon: const Icon(Icons.volume_up),
            label: Text(l10n.outcomeTestListenSentence, style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 28),

        // Seletor de palavras (Opções para a categoria ativa)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.outcomeTestChooseCategory(categories[_activeCategoryIndex]),
                style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: currentVocab.length,
                  itemBuilder: (context, index) {
                    final word = currentVocab[index];
                    bool isSelected = false;
                    if (_activeCategoryIndex == 0 && _selectedName == word) isSelected = true;
                    if (_activeCategoryIndex == 1 && _selectedVerb == word) isSelected = true;
                    if (_activeCategoryIndex == 2 && _selectedNumber == word) isSelected = true;
                    if (_activeCategoryIndex == 3 && _selectedNoun == word) isSelected = true;
                    if (_activeCategoryIndex == 4 && _selectedAdjective == word) isSelected = true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _selectWord(word),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: isSelected ? _primary.withValues(alpha: 0.15) : _card,
                            border: Border.all(
                              color: isSelected ? _primary : _textSoft.withValues(alpha: 0.15),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            word,
                            style: TextStyle(
                              color: isSelected ? Colors.white : _textMain,
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Área de Feedback ou Botão de Ação
        const SizedBox(height: 16),
        if (_evaluated) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _correctWordsInLastTrial >= 3
                  ? _correctColor.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _correctWordsInLastTrial >= 3 ? Icons.check_circle : Icons.info_outline,
                  color: _correctWordsInLastTrial >= 3 ? _correctColor : Colors.amber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.outcomeTestScore(_correctWordsInLastTrial.toString()),
                    style: TextStyle(
                      color: _correctWordsInLastTrial >= 3 ? _correctColor : Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _correctColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _nextTrial,
              child: Text(l10n.outcomeTestNextSentence, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSentenceComplete ? _primary : _textSoft.withValues(alpha: 0.15),
                disabledBackgroundColor: _textSoft.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSentenceComplete ? _confirmSentence : null,
              child: Text(l10n.outcomeTestConfirm, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultView() {
    final l10n = AppLocalizations.of(context);
    final String interpretation;
    if (_finalSrt <= 0) {
      interpretation = l10n.outcomeTestInterpretGood;
    } else if (_finalSrt <= 5) {
      interpretation = l10n.outcomeTestInterpretMild;
    } else {
      interpretation = l10n.outcomeTestInterpretSevere;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, color: _correctColor, size: 72),
        const SizedBox(height: 28),
        Text(
          l10n.outcomeTestDone,
          style: TextStyle(color: _textMain, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _textSoft.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Text(
                l10n.outcomeTestSrtLabel,
                style: TextStyle(color: _textSoft, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                "${_finalSrt.toStringAsFixed(1)} dB",
                style: TextStyle(color: _primary, fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                interpretation,
                style: TextStyle(color: _textMain, fontSize: 16, height: 1.45),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.outcomeTestBackHome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
