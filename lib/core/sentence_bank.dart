/// Banco de frases curtas do dia a dia, agrupadas pelos ambientes que o
/// "Seu João" frequenta (restaurante, academia, praça, mercado/feira).
///
/// Cada item tem a frase-alvo e uma frase distratora que difere em **uma
/// consoante** (de preferência aguda — justo o som que a perda auditiva
/// confunde). As frases são contextuais ao lugar, para o treino ter sentido na
/// vida real do idoso.
///
/// Regra ao adicionar frases: par mínimo de **palavras reais** (sem
/// pseudo-palavra), diferença de uma consoante, frase curta e cotidiana.
/// Mantemos ~10 frases por ambiente para uma sessão de 10 tentativas não repetir.
const Map<String, List<Map<String, String>>> SENTENCE_BANK_BY_ENV = {
  // --- RESTAURANTE: conversa de mesas, pedidos, conta ---
  'restaurante': [
    {'target': 'O peixe está fresco', 'distractor': 'O queixo está fresco'},
    {'target': 'A conta já chegou', 'distractor': 'A fonte já chegou'},
    {'target': 'Quero uma faca', 'distractor': 'Quero uma vaca'},
    {'target': 'A carne está dura', 'distractor': 'A carne está pura'},
    {'target': 'Trouxe o vinho', 'distractor': 'Trouxe o ninho'},
    {'target': 'O caldo está quente', 'distractor': 'O saldo está quente'},
    {'target': 'O prato chegou', 'distractor': 'O trato chegou'},
    {'target': 'A água está gelada', 'distractor': 'A águia está gelada'},
    {'target': 'Está muito salgado', 'distractor': 'Está muito molhado'},
    {'target': 'Quero pagar agora', 'distractor': 'Quero parar agora'},
  ],

  // --- ACADEMIA: música de fundo, aparelhos, instrutor ---
  'academia': [
    {'target': 'Quantas séries faltam?', 'distractor': 'Quantas feiras faltam?'},
    {'target': 'Alonga o braço', 'distractor': 'Alonga o traço'},
    {'target': 'Treina com força', 'distractor': 'Treina com forma'},
    {'target': 'Segura a barra', 'distractor': 'Segura a farra'},
    {'target': 'Aumenta o peso', 'distractor': 'Aumenta o preço'},
    {'target': 'Descansa um pouco', 'distractor': 'Descansa um pouso'},
    {'target': 'Vou correr na esteira', 'distractor': 'Vou comer na esteira'},
    {'target': 'Repete o movimento', 'distractor': 'Repete o momento'},
    {'target': 'Mantém a postura', 'distractor': 'Mantém a pintura'},
    {'target': 'Vai com calma', 'distractor': 'Vai com palma'},
  ],

  // --- PRAÇA: crianças, pássaros, cachorro, gente passando ---
  'praca': [
    {'target': 'O cachorro late muito', 'distractor': 'O cachorro bate muito'},
    {'target': 'As crianças brincam ali', 'distractor': 'As crianças brigam ali'},
    {'target': 'Os pássaros estão cantando', 'distractor': 'Os pássaros estão contando'},
    {'target': 'A flor é bonita', 'distractor': 'A cor é bonita'},
    {'target': 'O sol está forte hoje', 'distractor': 'O sal está forte hoje'},
    {'target': 'Senta no banco comigo', 'distractor': 'Senta no barco comigo'},
    {'target': 'As folhas caem', 'distractor': 'As folhas saem'},
    {'target': 'Tem sombra ali', 'distractor': 'Tem sonda ali'},
    {'target': 'A fonte é bonita', 'distractor': 'A ponte é bonita'},
    {'target': 'Corre atrás da bola', 'distractor': 'Corre atrás da bota'},
  ],

  // --- MERCADO / FEIRA: vendedores, movimento, preços ---
  'mercado': [
    {'target': 'Quanto custa o quilo?', 'distractor': 'Quanto gosta o quilo?'},
    {'target': 'Esse pão está fresquinho', 'distractor': 'Esse cão está fresquinho'},
    {'target': 'Me dá um melão', 'distractor': 'Me dá um leão'},
    {'target': 'Pode pesar de novo', 'distractor': 'Pode passar de novo'},
    {'target': 'O troco está certo', 'distractor': 'O troco está perto'},
    {'target': 'Quero uma dúzia de ovos', 'distractor': 'Quero uma dúzia de olhos'},
    {'target': 'Tá caro demais', 'distractor': 'Tá raro demais'},
    {'target': 'Esse queijo é bom', 'distractor': 'Esse beijo é bom'},
    {'target': 'O preço subiu', 'distractor': 'O berço subiu'},
    {'target': 'O saco está cheio', 'distractor': 'O saco está feio'},
  ],
};

/// Lista achatada de todas as frases (compatibilidade / sorteio geral, caso
/// algum fluxo ainda precise de um banco único sem ambiente).
List<Map<String, String>> get allSentences =>
    SENTENCE_BANK_BY_ENV.values.expand((list) => list).toList();

// ─── ENGLISH SENTENCE BANK ───────────────────────────────────────────────────
// Same four daily environments as the Portuguese bank.
// Each pair is a minimal sentence: one consonant change between target and
// distractor, both using real English words and natural phrasing for adults 55+.
// Environments chosen for ecological validity (where background noise and
// hearing loss cause the most real-world difficulty).

const Map<String, List<Map<String, String>>> SENTENCE_BANK_BY_ENV_EN = {
  // --- RESTAURANT: orders, table talk, bill ---
  'restaurante': [
    {'target': 'The fish is fresh',      'distractor': 'The dish is fresh'},
    {'target': 'Can I have the bill?',   'distractor': 'Can I have the pill?'},
    {'target': 'I need a knife',         'distractor': 'I need a life'},
    {'target': 'The soup is hot',        'distractor': 'The soup is not'},
    {'target': 'Pass the salt please',   'distractor': 'Pass the malt please'},
    {'target': 'The bread is warm',      'distractor': 'The bread is form'},
    {'target': 'We ordered wine',        'distractor': 'We ordered nine'},
    {'target': 'The meat is tender',     'distractor': 'The meat is gender'},
    {'target': 'I want a seat',          'distractor': 'I want a sheet'},
    {'target': 'The check arrived',      'distractor': 'The neck arrived'},
  ],

  // --- GYM / EXERCISE CLASS: background music, instructor, equipment ---
  'academia': [
    {'target': 'How many sets are left?', 'distractor': 'How many nets are left?'},
    {'target': 'Stretch your arm',        'distractor': 'Stretch your farm'},
    {'target': 'Train with force',        'distractor': 'Train with course'},
    {'target': 'Hold the bar',            'distractor': 'Hold the car'},
    {'target': 'Raise the weight',        'distractor': 'Raise the late'},
    {'target': 'Take a short rest',       'distractor': 'Take a short test'},
    {'target': 'I will run on the track', 'distractor': 'I will run on the crack'},
    {'target': 'Repeat the move',         'distractor': 'Repeat the groove'},
    {'target': 'Keep your back straight', 'distractor': 'Keep your back plate'},
    {'target': 'Go nice and slow',        'distractor': 'Go nice and low'},
  ],

  // --- PARK / SQUARE: children, birds, dogs, passers-by ---
  'praca': [
    {'target': 'The dog is barking',      'distractor': 'The dog is parking'},
    {'target': 'The kids are playing',    'distractor': 'The kids are paying'},
    {'target': 'The birds are singing',   'distractor': 'The birds are ringing'},
    {'target': 'The flower is pretty',    'distractor': 'The tower is pretty'},
    {'target': 'The sun is strong today', 'distractor': 'The son is strong today'},
    {'target': 'Sit with me on the bench','distractor': 'Sit with me on the branch'},
    {'target': 'The leaves are falling',  'distractor': 'The leaves are calling'},
    {'target': 'There is shade over here','distractor': 'There is spade over here'},
    {'target': 'The path is long',        'distractor': 'The bath is long'},
    {'target': 'Chase the ball',          'distractor': 'Chase the wall'},
  ],

  // --- SUPERMARKET / MARKET: vendors, noise, prices ---
  'mercado': [
    {'target': 'How much per kilo?',       'distractor': 'How much per silo?'},
    {'target': 'This bread is fresh',      'distractor': 'This bread is flesh'},
    {'target': 'Give me a melon',          'distractor': 'Give me a felon'},
    {'target': 'Can you weigh it again?',  'distractor': 'Can you say it again?'},
    {'target': 'The change is right',      'distractor': 'The change is light'},
    {'target': 'I need a dozen eggs',      'distractor': 'I need a dozen legs'},
    {'target': 'That is too dear',         'distractor': 'That is too near'},
    {'target': 'This cheese is good',      'distractor': 'This fees is good'},
    {'target': 'The price went up',        'distractor': 'The price went sup'},
    {'target': 'The bag is full',          'distractor': 'The bag is bull'},
  ],
};

/// Flat list of all English sentences (compatibility / random draw).
List<Map<String, String>> get allSentencesEn =>
    SENTENCE_BANK_BY_ENV_EN.values.expand((list) => list).toList();
