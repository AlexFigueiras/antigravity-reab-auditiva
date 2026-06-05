import 'package:flutter/material.dart';
import '../../audio_engine/audio_engine.dart';
import '../../models/audiogram.dart';
import '../../core/outcome_test_bank.dart';
import '../../core/adaptive_staircase.dart';
import '../../services/supabase_service.dart';

class OutcomeTestScreen extends StatefulWidget {
  const OutcomeTestScreen({super.key});

  @override
  State<OutcomeTestScreen> createState() => _OutcomeTestScreenState();
}

class _OutcomeTestScreenState extends State<OutcomeTestScreen> {
  static const _bg = Color(0xFF101418);
  static const _card = Color(0xFF1B2128);
  static const _primary = Color(0xFF4F8DF7);
  static const _textMain = Color(0xFFF2F4F7);
  static const _textSoft = Color(0xFFB4BCC8);
  static const _correctColor = Color(0xFF3FB37F);

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

    setState(() {
      _currentTrial++;
      _currentSentence = generateRandomMatrixSentence();
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          "Teste de Fala no Ruído",
          style: TextStyle(color: _textMain, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: _textMain),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.hearing, color: _primary, size: 72),
        const SizedBox(height: 28),
        const Text(
          "Teste de Fala no Ruído (Matrix)",
          style: TextStyle(color: _textMain, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          "Este teste avalia sua capacidade real de compreender conversas em ambientes barulhentos (efeito coquetel).",
          style: TextStyle(color: _textSoft, fontSize: 16, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          "Você ouvirá uma frase no ruído e deverá montá-la selecionando as palavras correspondentes. São 20 frases no total.",
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
            child: const Text(
              "Começar Teste",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestView() {
    final categories = ["Nome", "Verbo", "Número", "Objeto", "Cor"];
    final List<List<String>> vocabularies = [
      MATRIX_NAMES,
      MATRIX_VERBS,
      MATRIX_NUMBERS,
      MATRIX_NOUNS,
      MATRIX_ADJECTIVES
    ];

    final currentVocab = vocabularies[_activeCategoryIndex];

    return Column(
      children: [
        // Indicador de progresso
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Frase $_currentTrial de $_totalTrials",
              style: const TextStyle(color: _textSoft, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              "Dificuldade: ${-_srtStaircase.current.toInt()} dB",
              style: TextStyle(color: _primary.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _currentTrial / _totalTrials,
          backgroundColor: Colors.white10,
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
                      color: isFocused ? _primary : (hasValue ? Colors.white24 : Colors.transparent),
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
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _playStimulus,
            icon: const Icon(Icons.volume_up, color: Colors.white70),
            label: const Text("Ouvir Frase", style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 28),

        // Seletor de palavras (Opções para a categoria ativa)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Escolha o ${categories[_activeCategoryIndex]}:",
                style: const TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.bold),
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
                              color: isSelected ? _primary : Colors.white10,
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
                    "Você acertou $_correctWordsInLastTrial de 5 palavras.",
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
              child: const Text("Próxima Frase", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSentenceComplete ? _primary : Colors.white12,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSentenceComplete ? _confirmSentence : null,
              child: const Text("Confirmar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultView() {
    // Classificação audiológica simples do SRT
    String interpretation = "";
    if (_finalSrt <= 0) {
      interpretation = "Excelente capacidade de entender falas mesmo no ruído de fundo.";
    } else if (_finalSrt <= 5) {
      interpretation = "Dificuldade leve. Você consegue entender, mas exige mais esforço mental no ruído.";
    } else {
      interpretation = "Dificuldade moderada a severa. Conversar em restaurantes e festas pode ser muito desafiador.";
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, color: _correctColor, size: 72),
        const SizedBox(height: 28),
        const Text(
          "Teste Concluído!",
          style: TextStyle(color: _textMain, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const Text(
                "Limiar de Fala no Ruído (SRT)",
                style: TextStyle(color: _textSoft, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                "${_finalSrt.toStringAsFixed(1)} dB",
                style: const TextStyle(color: _primary, fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                interpretation,
                style: const TextStyle(color: _textMain, fontSize: 16, height: 1.45),
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
            child: const Text("Voltar ao Início", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
