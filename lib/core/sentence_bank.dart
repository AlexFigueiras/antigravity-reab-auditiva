/// Banco de frases curtas do dia a dia para o módulo de compreensão de fala.
///
/// Cada item tem a frase-alvo e uma frase distratora que difere em uma
/// consoante de alta frequência (difícil de ouvir na perda auditiva).
/// Contextos: família, telefone, restaurante e situações cotidianas.
const List<Map<String, dynamic>> SENTENCE_BANK = [
  {'target': 'A casa é bonita', 'distractor': 'A taça é bonita'},
  {'target': 'Quero um café', 'distractor': 'Quero um chafé'},
  {'target': 'O telefone tocou', 'distractor': 'O telefone secou'},
  {'target': 'Vou ligar mais tarde', 'distractor': 'Vou jogar mais tarde'},
  {'target': 'A sopa está quente', 'distractor': 'A fofa está quente'},
  {'target': 'Ela chegou cedo', 'distractor': 'Ela secou cedo'},
  {'target': 'Passa o sal, por favor', 'distractor': 'Passa o chá, por favor'},
  {'target': 'O cachorro late muito', 'distractor': 'O cachorro bate muito'},
  {'target': 'Vamos sair hoje', 'distractor': 'Vamos cair hoje'},
  {'target': 'A conta já chegou', 'distractor': 'A fonte já chegou'},
  {'target': 'Meu neto está feliz', 'distractor': 'Meu neto está fedido'},
  {'target': 'Feche a janela', 'distractor': 'Peche a janela'},
  {'target': 'O peixe está fresco', 'distractor': 'O queixo está fresco'},
  {'target': 'A festa foi ótima', 'distractor': 'A sexta foi ótima'},
  {'target': 'Pode falar mais alto', 'distractor': 'Pode salvar mais alto'},
];
