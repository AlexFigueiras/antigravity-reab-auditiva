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

// ─── AMERICAN ENGLISH MATRIX TEST (AEMT) ─────────────────────────────────────
// Word matrix from the validated American English Matrix Test.
// Reference: Kollmeier et al. (2015), Int J Audiol 54(sup2):3-16.
//            Kiolbasa et al. (2024), Int J Audiol 63(5). DOI:10.1080/14992027.2023.2185757
//            Live test: CI Brain Lab, Washington University in St. Louis.
// Sentence structure: [Name] [Verb] [Number] [Adjective] [Noun]
// All names are monosyllabic; nouns are plurals — chosen for homogeneous
// acoustic loading and semantic unpredictability (prevents top-down guessing).
const List<String> MATRIX_NAMES_EN = ["Bob", "Gene", "Jane", "Jill", "Lynn"];
const List<String> MATRIX_VERBS_EN = ["bought", "found", "gave", "held", "lost"];
const List<String> MATRIX_NUMBERS_EN = ["two", "three", "four", "five", "six"];
const List<String> MATRIX_ADJECTIVES_EN = ["big", "blue", "cold", "hot", "new"];
const List<String> MATRIX_NOUNS_EN = ["bags", "cards", "gloves", "hats", "pens"];

/// Generates a random English Matrix sentence.
MatrixSentence generateRandomMatrixSentenceEn() {
  final rand = math.Random();
  // AEMT word order: Name Verb Number Adjective Noun
  // We reuse MatrixSentence but map: number→number, noun→adjective slot, adjective→noun slot
  // to keep the data class unchanged. The text getter concatenates in declaration order.
  return MatrixSentence(
    name: MATRIX_NAMES_EN[rand.nextInt(MATRIX_NAMES_EN.length)],
    verb: MATRIX_VERBS_EN[rand.nextInt(MATRIX_VERBS_EN.length)],
    number: MATRIX_NUMBERS_EN[rand.nextInt(MATRIX_NUMBERS_EN.length)],
    noun: MATRIX_ADJECTIVES_EN[rand.nextInt(MATRIX_ADJECTIVES_EN.length)],
    adjective: MATRIX_NOUNS_EN[rand.nextInt(MATRIX_NOUNS_EN.length)],
  );
}
