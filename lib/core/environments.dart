import 'package:flutter/material.dart';

/// Metadados dos ambientes que o "Seu João" frequenta no treino de frases.
///
/// Fonte única de verdade usada pelo hub (lista de ambientes), pela cena
/// animada (tema/cor/ícone) e pelo motor de áudio (qual ambiência tocar e qual
/// string passar em `noiseEnvironment`). As frases de cada ambiente vivem em
/// [SENTENCE_BANK_BY_ENV] (sentence_bank.dart), indexadas pela mesma `key`.
class TrainingEnvironment {
  /// Chave estável, igual à usada em SENTENCE_BANK_BY_ENV e no log de áudio.
  final String key;

  /// Nome humano mostrado ao usuário (ex.: "No restaurante").
  final String title;

  /// Frase curta de propósito ("Ajude o Seu João a entender o garçom").
  final String subtitle;

  /// O que o Seu João "diz" ao abrir a cena (acolhe e contextualiza).
  final String joaoOpening;

  /// Ícone representativo do lugar.
  final IconData icon;

  /// Cor de tema do ambiente (fundo da cena, destaques).
  final Color color;

  /// Caminho do áudio de ambiência (loop) em assets. Carregado no canal de
  /// ruído nativo na Fase 3; antes disso o ruído branco atual é usado.
  final String ambienceAsset;

  const TrainingEnvironment({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.joaoOpening,
    required this.icon,
    required this.color,
    required this.ambienceAsset,
  });
}

/// Os 4 ambientes, na ordem em que aparecem no hub.
const List<TrainingEnvironment> kEnvironments = [
  TrainingEnvironment(
    key: 'restaurante',
    title: 'No restaurante',
    subtitle: 'Ajude o Seu João a entender o pedido no meio das conversas.',
    joaoOpening: 'Tá uma conversa danada aqui. Me ajuda a ouvir o garçom?',
    icon: Icons.restaurant,
    color: Color(0xFFE07A5F),
    ambienceAsset: 'assets/audio/ambiencias/restaurante.wav',
  ),
  TrainingEnvironment(
    key: 'academia',
    title: 'Na academia',
    subtitle: 'Ajude o Seu João a entender o instrutor com a música alta.',
    joaoOpening: 'A música tá alta. O que o instrutor falou mesmo?',
    icon: Icons.fitness_center,
    color: Color(0xFF4F8DF7),
    ambienceAsset: 'assets/audio/ambiencias/academia.wav',
  ),
  TrainingEnvironment(
    key: 'praca',
    title: 'Na praça',
    subtitle: 'Ajude o Seu João a entender quem fala com ele ao ar livre.',
    joaoOpening: 'Quanta criança! Vamos ver se a gente entende direitinho.',
    icon: Icons.park,
    color: Color(0xFF4CAF7D),
    ambienceAsset: 'assets/audio/ambiencias/praca.wav',
  ),
  TrainingEnvironment(
    key: 'mercado',
    title: 'No mercado',
    subtitle: 'Ajude o Seu João a entender o vendedor na correria da feira.',
    joaoOpening: 'Tá cheio hoje. Me ajuda a ouvir o que o moço disse?',
    icon: Icons.shopping_basket,
    color: Color(0xFFE6A532),
    ambienceAsset: 'assets/audio/ambiencias/mercado.wav',
  ),
];

/// Busca um ambiente pela chave (ex.: para recuperar o tema a partir do log).
TrainingEnvironment environmentByKey(String key) =>
    kEnvironments.firstWhere((e) => e.key == key,
        orElse: () => kEnvironments.first);
