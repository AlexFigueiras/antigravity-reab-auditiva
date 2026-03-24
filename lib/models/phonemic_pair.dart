class PhonemicPair {
  final String target;
  final String distractor;
  final String targetAudioPath;
  final String distractorAudioPath;

  PhonemicPair({
    required this.target,
    required this.distractor,
    required this.targetAudioPath,
    required this.distractorAudioPath,
  });
}

final phonemicPairs = [
  PhonemicPair(
    target: "Faca",
    distractor: "Saca",
    targetAudioPath: "assets/audio/faca.wav",
    distractorAudioPath: "assets/audio/saca.wav",
  ),
  PhonemicPair(
    target: "Pato",
    distractor: "Tato",
    targetAudioPath: "assets/audio/pato.wav",
    distractorAudioPath: "assets/audio/tato.wav",
  ),
  PhonemicPair(
    target: "Bota",
    distractor: "Gota",
    targetAudioPath: "assets/audio/bota.wav",
    distractorAudioPath: "assets/audio/gota.wav",
  ),
  // Mais pares podem ser adicionados aqui
];
