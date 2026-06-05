import 'dart:math' as math;

/// Frase de desfecho Matrix [Fase 0.2]
/// Estrutura sintática fixa: [Nome] [Verbo] [Número] [Substantivo] [Adjetivo]
class MatrixSentence {
  final String name;
  final String verb;
  final String number;
  final String noun;
  final String adjective;

  MatrixSentence({
    required this.name,
    required this.verb,
    required this.number,
    required this.noun,
    required this.adjective,
  });

  String get text => "$name $verb $number $noun $adjective";

  @override
  String toString() => text;
}

const List<String> MATRIX_NAMES = ["O João", "A Maria", "O Pedro", "A Ana", "O Carlos"];
const List<String> MATRIX_VERBS = ["comprou", "guardou", "achou", "perdeu", "ganhou"];
const List<String> MATRIX_NUMBERS = ["dois", "três", "quatro", "cinco", "seis"];
const List<String> MATRIX_NOUNS = ["livros", "chaves", "sacos", "copos", "pratos"];
const List<String> MATRIX_ADJECTIVES = ["azuis", "verdes", "brancos", "pretos", "novos"];

/// Gera uma frase Matrix aleatória.
MatrixSentence generateRandomMatrixSentence() {
  final rand = math.Random();
  return MatrixSentence(
    name: MATRIX_NAMES[rand.nextInt(MATRIX_NAMES.length)],
    verb: MATRIX_VERBS[rand.nextInt(MATRIX_VERBS.length)],
    number: MATRIX_NUMBERS[rand.nextInt(MATRIX_NUMBERS.length)],
    noun: MATRIX_NOUNS[rand.nextInt(MATRIX_NOUNS.length)],
    adjective: MATRIX_ADJECTIVES[rand.nextInt(MATRIX_ADJECTIVES.length)],
  );
}
