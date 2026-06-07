// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'BOSYN - Reabilitação Auditiva';

  @override
  String get homeYourTrainings => 'Seus treinos';

  @override
  String get homeStartWithHearingTest =>
      'Comece pelo teste de audição — ele deixa tudo no seu ritmo.';

  @override
  String get hearingTestTitle => 'Teste de audição';

  @override
  String get hearingTestSubtitleNew =>
      'Comece por aqui — ele personaliza todo o seu treino.';

  @override
  String get hearingTestSubtitleDone =>
      'Concluído. Você pode refazer quando quiser.';

  @override
  String get speechInNoiseTestTitle => 'Teste de fala no barulho';

  @override
  String get speechInNoiseTestSubtitle =>
      'Veja o quanto você entende falas no barulho — e acompanhe sua evolução.';

  @override
  String get speechInNoiseNeedsHearingTest =>
      'Faça primeiro o teste de audição — ele personaliza o som deste teste.';

  @override
  String get level2Title => 'Distinguir sons parecidos';

  @override
  String get level2Subtitle =>
      'Treine sons que se confundem, como \"fala\" e \"sala\".';

  @override
  String get level3Title => 'De que lado vem o som';

  @override
  String get level3Subtitle =>
      'Perceba a direção do som — esquerda, centro, direita.';

  @override
  String get level4Title => 'Entender no meio do barulho';

  @override
  String get level4Subtitle => 'Acompanhe a fala mesmo com som de fundo.';

  @override
  String get sentenceTitle => 'Frases do dia a dia';

  @override
  String get sentenceSubtitle =>
      'Ajude o Seu João a entender frases inteiras no barulho.';

  @override
  String get commonStart => 'Começar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonYes => 'SIM';

  @override
  String get commonNo => 'NÃO';

  @override
  String get commonSaveAndBack => 'Salvar e voltar';

  @override
  String get commonRetake => 'Refazer teste';

  @override
  String get hearingTestWhichEar => 'Qual ouvido você quer testar?';

  @override
  String get hearingTestPutHeadphones =>
      'Coloque os fones. Vamos testar um ouvido de cada vez.';

  @override
  String get hearingTestLeftEar => 'Ouvido esquerdo';

  @override
  String get hearingTestRightEar => 'Ouvido direito';

  @override
  String get hearingTestDidYouHear => 'Você ouviu o som?';

  @override
  String get hearingTestAdjustVolume => 'Ajustar o volume';

  @override
  String get hearingTestVolumeCardTitle => 'Vamos acertar o nível de som';

  @override
  String get hearingTestVolumeCardBody =>
      'Para o teste valer, o som precisa ficar num nível certo — o mesmo dos treinos. Coloque os fones e toque abaixo: vamos ajustar o volume devagar, sem susto.';

  @override
  String get languageName => 'Português';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get authWelcomeBack => 'Bem-vindo de volta';

  @override
  String get authCreateAccount => 'Vamos criar sua conta';

  @override
  String get authWelcomeSubtitle => 'Entre para continuar seu treino auditivo.';

  @override
  String get authCreateSubtitle =>
      'É rápido. Depois preparamos tudo no seu ritmo.';

  @override
  String get authEmailLabel => 'Seu e-mail';

  @override
  String get authPasswordLabel => 'Sua senha';

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authSignUp => 'Criar conta';

  @override
  String get authSwitchToSignUp => 'Ainda não tem conta? Criar agora';

  @override
  String get authSwitchToSignIn => 'Já tem conta? Entrar';

  @override
  String get authError =>
      'Não foi possível entrar. Confira seu e-mail e senha.';

  @override
  String get authSignUpSuccess =>
      'Conta criada! Verifique seu e-mail para confirmar.';

  @override
  String get logout => 'Sair da conta';

  @override
  String get settingsMenuTooltip => 'Configurações';

  @override
  String get themeUseLight => 'Visual claro';

  @override
  String get themeUseDark => 'Visual escuro';

  @override
  String get homeGreeting => 'Olá!';

  @override
  String get homeGreetingSubtitle =>
      'Que bom ter você aqui. Vamos treinar um pouco hoje?';

  @override
  String get homeProgressTitle => 'Sua evolução';

  @override
  String homeProgressLastAccuracy(String percent) {
    return 'Últimos acertos: $percent%. Toque para ver mais.';
  }

  @override
  String get homeProgressEmpty =>
      'Faça seu primeiro treino para acompanhar aqui.';

  @override
  String get homeProgressTapHint => 'Toque para ver mais.';

  @override
  String get homeDailyGoalTitle => 'Meta diária (15 min)';

  @override
  String get homeDailyGoalDone => 'Meta batida! Excelente treino hoje.';

  @override
  String homeDailyGoalProgress(String minutes) {
    return '$minutes min treinados de 15 min.';
  }

  @override
  String get homePermissionTitle => 'Vamos preparar o som';

  @override
  String get homePermissionBody =>
      'Para tocar os sons do treino e reconhecer seus fones, o app precisa da sua permissão para o microfone e o Bluetooth.';

  @override
  String get homePermissionAllow => 'Permitir';

  @override
  String get homePermissionOpenSettings => 'Abrir configurações';

  @override
  String get homePermissionDeniedHint =>
      'A permissão foi recusada. Toque acima para abrir as configurações e habilitar manualmente.';

  @override
  String get homeSavedAudiogram =>
      'Teste salvo! O treino agora é personalizado para você.';

  @override
  String get homeSaveAudiogramError =>
      'Erro ao salvar o teste. Tente novamente.';

  @override
  String get homeSentenceNeedsAudiogram =>
      'Faça primeiro o teste de audição para liberar este treino.';

  @override
  String get homeSelfPerceptionThanks => 'Obrigado por compartilhar!';

  @override
  String ttsVoiceMissingTitle(String voice) {
    return 'A voz em $voice não está instalada neste aparelho.';
  }

  @override
  String get ttsVoiceMissingWhy =>
      'As palavras podem soar com outro sotaque. Instalar a voz certa deixa o treino mais natural.';

  @override
  String get ttsVoiceInstallButton => 'Instalar a voz';

  @override
  String get ttsVoiceMissingIosHint =>
      'Vá em Ajustes › Acessibilidade › Conteúdo falado › Vozes para instalar.';

  @override
  String get ttsVoiceRecheck => 'Já instalei a voz';

  @override
  String get ttsVoiceStillMissing =>
      'Ainda não encontramos a voz. Pode levar um instante após instalar — tente de novo em alguns segundos.';

  @override
  String get ttsVoicePtBrName => 'português do Brasil';

  @override
  String get ttsVoiceEnUsName => 'inglês americano';

  @override
  String homeLockUnlockHint(String percent) {
    return 'Acerte 70% no \"Distinguir sons\" para liberar. Você está com $percent%.';
  }

  @override
  String get homeLockUnlockHintNoProgress =>
      'Acerte 70% no \"Distinguir sons\" para liberar este treino.';

  @override
  String get homeLockHowTitle => 'Como desbloquear';

  @override
  String homeLockHowBody(String name) {
    return 'Esse treino é liberado quando você atingir 70% de acertos no \"$name\" (média das últimas 3 sessões).';
  }

  @override
  String homeLockNearlyThere(String percent) {
    return 'Quase lá! Você está com $percent%.';
  }

  @override
  String homeLockKeepGoing(String percent) {
    return 'Você está com $percent%. Continue treinando!';
  }

  @override
  String homeLockNeedSessions(String name) {
    return 'Faça pelo menos 3 sessões de \"$name\" para começar a medir seu progresso.';
  }

  @override
  String homeLockTrainButton(String name) {
    return 'Treinar \"$name\"';
  }

  @override
  String get levelNameL2 => 'Distinguir sons';

  @override
  String get levelNameL3 => 'De que lado vem o som';

  @override
  String get levelNameL4 => 'Entender no barulho';

  @override
  String get paywallTitle => 'Treino completo';

  @override
  String get paywallBody =>
      'O treino de frases do dia a dia faz parte da assinatura. Assim você treina de ponta a ponta, no seu ritmo.';

  @override
  String get paywallSubscribeButton => 'Assinar';

  @override
  String progressBarCurrentLabel(String percent) {
    return '$percent% atual';
  }

  @override
  String progressBarTargetLabel(String percent) {
    return 'Meta: $percent%';
  }

  @override
  String get thresholdTestTitle => 'Teste de audição';

  @override
  String get thresholdTestWhichEar => 'Qual ouvido você quer testar?';

  @override
  String get thresholdTestPutHeadphones =>
      'Coloque os fones. Vamos testar um ouvido de cada vez.';

  @override
  String get thresholdTestMonoWarningTitle => 'Áudio mono está ligado';

  @override
  String get thresholdTestMonoWarningBody =>
      'Seu celular está tocando o mesmo som nos dois ouvidos, o que atrapalha o teste. Desligue em:\nConfigurações → Acessibilidade → Áudio → Áudio mono.';

  @override
  String get thresholdTestVolumeDriftTitle => 'O volume mudou';

  @override
  String get thresholdTestVolumeDriftBody =>
      'O nível de som saiu do ponto certo. Para o teste continuar valendo, vamos voltar ao nível e ouvir o som de novo.';

  @override
  String get thresholdTestVolumeDriftButton => 'Voltar ao nível e continuar';

  @override
  String get thresholdTestLeftEarLabel => '◀  OUVIDO ESQUERDO';

  @override
  String get thresholdTestRightEarLabel => 'OUVIDO DIREITO  ▶';

  @override
  String get thresholdTestFamiliarization => 'Fase de Familiarização';

  @override
  String get thresholdTestPreparing => 'Preparando próximo tom...';

  @override
  String get thresholdTestListening => 'Ouça com atenção...';

  @override
  String get thresholdTestDidYouHear => 'Você ouviu o som?';

  @override
  String thresholdTestSoundLevel(String db) {
    return 'Nível de som: $db';
  }

  @override
  String get thresholdTestCatchTrialWarning =>
      'Atenção: Nenhum som foi tocado agora. Por favor, responda apenas quando realmente ouvir o som.';

  @override
  String get thresholdTestResults => 'Resultado do teste';

  @override
  String get thresholdTestViewResult => 'Ver resultado';

  @override
  String get thresholdTestViewResultOneEar =>
      'Ver resultado (só 1 ouvido testado)';

  @override
  String get thresholdTestLeftEar => 'Ouvido esquerdo';

  @override
  String get thresholdTestRightEar => 'Ouvido direito';

  @override
  String get thresholdTestEarDone => 'Já testado — toque para refazer';

  @override
  String get thresholdTestEarTap => 'Tocar para testar';

  @override
  String get thresholdTestLastResult => 'Seu último teste de audição';

  @override
  String thresholdTestDoneOn(String date) {
    return 'Feito em $date';
  }

  @override
  String get thresholdTestBack => 'Voltar';

  @override
  String get dashboardTitleL2 => 'Distinguir sons';

  @override
  String get dashboardTitleL3 => 'De que lado vem o som';

  @override
  String get dashboardTitleL4 => 'Entender no barulho';

  @override
  String get dashboardDescL2 =>
      'Você vai ouvir uma palavra e escolher, entre duas parecidas, qual foi dita. Treina sons que se confundem.';

  @override
  String get dashboardDescL3 =>
      'Você vai ouvir um som e dizer de que lado ele veio: esquerda, centro ou direita.';

  @override
  String get dashboardDescL4 =>
      'Você vai ouvir uma palavra com barulho de fundo e escolher qual foi dita. Treina entender no meio do ruído.';

  @override
  String get dashboardNoAudiogramLoading =>
      'Carregando seu teste de audição… tente de novo em instantes.';

  @override
  String get dashboardNoAudiogramNeeded =>
      'Faça primeiro o teste de audição. É ele que escolhe os sons certos para o seu treino — sem ele, não dá para personalizar.';

  @override
  String get dashboardFeedbackCorrect => 'Isso! Você ouviu certo.';

  @override
  String dashboardFeedbackWrong(String word) {
    return 'Quase. A palavra era \"$word\". Ouça de novo.';
  }

  @override
  String get dashboardFeedbackCorrectNoise => 'Isso! Mesmo no barulho.';

  @override
  String dashboardFeedbackWrongNoise(String word) {
    return 'Quase. A palavra era \"$word\".';
  }

  @override
  String get dashboardFeedbackSideCorrect => 'Isso! Lado certo.';

  @override
  String get dashboardFeedbackSideWrong => 'Quase. Ouça de novo.';

  @override
  String get dashboardGoalReached => 'Meta batida! Pode continuar ou encerrar.';

  @override
  String get dashboardGoodEffort =>
      'Bom esforço! Pode continuar ou voltar amanhã.';

  @override
  String get dashboardConfirmCondition =>
      'Confirme a condição acima para começar.';

  @override
  String get dashboardWhichWord => 'Qual palavra você ouviu?';

  @override
  String get dashboardWhichSide => 'De que lado veio o som?';

  @override
  String get dashboardSideLeft => 'Esquerda';

  @override
  String get dashboardSideCenter => 'Centro';

  @override
  String get dashboardSideRight => 'Direita';

  @override
  String get dashboardListenAgain => 'Ouvir de novo';

  @override
  String get dashboardStartTraining => 'Começar o treino';

  @override
  String get dashboardEndTraining => 'Encerrar treino';

  @override
  String get selfPerceptionQuestion =>
      'Quão bem você acompanhou as conversas esta semana?';

  @override
  String get selfPerceptionSubtitle =>
      'Sua resposta nos ajuda a acompanhar seu progresso.';

  @override
  String get selfPerceptionVeryHard => 'Muito difícil';

  @override
  String get selfPerceptionHard => 'Difícil';

  @override
  String get selfPerceptionSoSo => 'Mais ou menos';

  @override
  String get selfPerceptionWell => 'Bem';

  @override
  String get selfPerceptionVeryWell => 'Muito bem';

  @override
  String get listeningModeUnaided => 'Sem aparelho';

  @override
  String get listeningModeAided => 'Com aparelho';

  @override
  String get listeningModeUnaided_instruction =>
      'Tire o aparelho auditivo e coloque os fones.';

  @override
  String get listeningModeAided_instruction =>
      'Mantenha seu aparelho auditivo ligado, na regulagem de sempre.';

  @override
  String get listeningModeUnaided_why =>
      'Assim o app ajusta o som no jeito certo para os seus ouvidos.';

  @override
  String get listeningModeAided_why =>
      'Assim o treino combina com o seu dia a dia, em que você usa o aparelho.';

  @override
  String get listeningModeUnaided_confirm => 'Estou sem o aparelho';

  @override
  String get listeningModeAided_confirm => 'Estou com o aparelho';

  @override
  String get progressScreenTitle => 'Sua evolução';

  @override
  String progressSessionCount(String count) {
    return '$count sessões';
  }

  @override
  String progressDaysStreak(String count) {
    return '$count dias seguidos';
  }

  @override
  String progressAverage(String percent) {
    return 'Média: $percent%';
  }

  @override
  String get progressModuleDistinguish => 'Distinguir sons';

  @override
  String get progressModuleDirection => 'De que lado';

  @override
  String get progressModuleNoise => 'No barulho';

  @override
  String get progressModuleSession1 => 'sessão';

  @override
  String get progressModuleSessions => 'sessões';

  @override
  String get progressModuleNoTraining => 'Sem treinos';

  @override
  String get progressChartTitle => 'Acertos ao longo do tempo';

  @override
  String get progressHardestTitle => 'Sons mais difíceis para você';

  @override
  String get progressHardestSubtitle =>
      'Estas foram as palavras que você mais confundiu. Treinar mais ajuda a ouvir melhor.';

  @override
  String get progressHardestNoData =>
      'Você ainda não errou palavras suficientes para mostrarmos um padrão. Continue treinando!';

  @override
  String get progressChartNoData => 'Sem dados de acertos ainda.';

  @override
  String get progressNoTrainingsYet =>
      'Ainda não há treinos por aqui.\nFaça seu primeiro treino para acompanhar sua evolução.';

  @override
  String get progressOutcomeCardTitle => 'Teste de fala no barulho';

  @override
  String get progressOutcomeNoHistory =>
      'Você ainda não fez este teste. Ele mostra o quanto você entende falas no barulho e fica registrado aqui para acompanhar sua evolução. Comece pela tela inicial, no card \"Teste de fala no barulho\".';

  @override
  String get progressOutcomeSrtLabel => 'Limiar de Fala (SRT)';

  @override
  String get progressOutcomeChartTitle =>
      'Evolução do Limiar (Menos dB = Melhor)';

  @override
  String get progressOutcomeRetakeButton => 'Fazer o teste de novo';

  @override
  String get progressSrtCardLabel => 'Entender no barulho';

  @override
  String get progressSrtCardBody =>
      'Esse é o nível de barulho em que você ainda entende as palavras. Quanto menor, melhor!';

  @override
  String progressImprovedBy(String db) {
    return 'Melhorou $db dB';
  }

  @override
  String get progressNoChange => 'Sem alteração';

  @override
  String get progressSinceStart => 'desde o início';

  @override
  String get progressMoreTests => 'Realize mais testes para ver a evolução.';

  @override
  String get progressErrorCount1 => 'erro';

  @override
  String get progressErrorCountN => 'erros';

  @override
  String get onboardingWelcomeTitle => 'Bem-vindo ao BOSYN';

  @override
  String get onboardingWelcomeBody1 =>
      'Este app foi feito para ajudar você a entender melhor as palavras — mesmo no barulho, mesmo ao telefone.';

  @override
  String get onboardingWelcomeBody2 =>
      'Com alguns minutos de treino por dia, seu cérebro aprende a distinguir sons que ficaram difíceis com o tempo.';

  @override
  String get onboardingWelcomeButton => 'Vamos começar';

  @override
  String get onboardingAgeTitle => 'Qual é a sua faixa de idade?';

  @override
  String get onboardingAgeUnder50 => 'Menos de 50 anos';

  @override
  String get onboardingAge50to65 => '50 a 65 anos';

  @override
  String get onboardingAge65to75 => '65 a 75 anos';

  @override
  String get onboardingAgeOver75 => 'Mais de 75 anos';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingDifficultyTitle => 'O que mais dificulta sua audição?';

  @override
  String get onboardingDifficultySubtitle =>
      'Escolha a que mais combina com você.';

  @override
  String get onboardingDifficultyUnderstand =>
      'Entender o que as pessoas falam';

  @override
  String get onboardingDifficultyNoise => 'Ouvir no barulho (restaurante, TV)';

  @override
  String get onboardingDifficultyPhone => 'Escutar ao telefone';

  @override
  String get onboardingDifficultyDirection => 'Perceber de onde vem o som';

  @override
  String get onboardingHearingAidTitle => 'Você usa aparelho auditivo?';

  @override
  String get onboardingHearingAidSubtitle =>
      'Isso decide como você vai fazer o teste e os treinos. Use sempre do mesmo jeito.';

  @override
  String get onboardingHearingAidYes => 'Sim, uso regularmente';

  @override
  String get onboardingHearingAidNo => 'Não uso aparelho';

  @override
  String get onboardingVolumeHint =>
      'Ajuste o volume do seu fone até o tom soar confortável:';

  @override
  String get onboardingPlayTone => 'Tocar tom de teste';

  @override
  String get onboardingEnterApp => 'Entrar no app';

  @override
  String get onboardingSaveError =>
      'Não consegui salvar o teste de audição. Verifique a conexão e refaça em Início.';

  @override
  String get progressSaveError => 'Erro ao salvar o teste. Tente novamente.';

  @override
  String get outcomeTestTitle => 'Teste de fala no barulho';

  @override
  String get outcomeTestMatrixTitle => 'Teste de Fala no Ruído (Matrix)';

  @override
  String get outcomeTestDescription1 =>
      'Este teste avalia sua capacidade real de compreender conversas em ambientes barulhentos (efeito coquetel).';

  @override
  String get outcomeTestDescription2 =>
      'Você ouvirá uma frase no ruído e deverá montá-la selecionando as palavras correspondentes. São 20 frases no total.';

  @override
  String get outcomeTestStart => 'Começar Teste';

  @override
  String outcomeTestSentenceProgress(String current, String total) {
    return 'Frase $current de $total';
  }

  @override
  String outcomeTestDifficulty(String db) {
    return 'Dificuldade: $db dB';
  }

  @override
  String get outcomeTestListenSentence => 'Ouvir Frase';

  @override
  String outcomeTestChooseCategory(String category) {
    return 'Escolha o $category:';
  }

  @override
  String outcomeTestScore(String count) {
    return 'Você acertou $count de 5 palavras.';
  }

  @override
  String get outcomeTestNextSentence => 'Próxima Frase';

  @override
  String get outcomeTestConfirm => 'Confirmar';

  @override
  String get outcomeTestDone => 'Teste Concluído!';

  @override
  String get outcomeTestSrtLabel => 'Limiar de Fala no Ruído (SRT)';

  @override
  String get outcomeTestInterpretGood =>
      'Excelente capacidade de entender falas mesmo no ruído de fundo.';

  @override
  String get outcomeTestInterpretMild =>
      'Dificuldade leve. Você consegue entender, mas exige mais esforço mental no ruído.';

  @override
  String get outcomeTestInterpretSevere =>
      'Dificuldade moderada a severa. Conversar em restaurantes e festas pode ser muito desafiador.';

  @override
  String get outcomeTestBackHome => 'Voltar ao Início';

  @override
  String get missionReportTitle => 'Treino concluído!';

  @override
  String get missionReportAccuracy => 'acertos';

  @override
  String get missionReportCorrectLabel => 'Acertos';

  @override
  String get missionReportAverageTime => 'Tempo médio';

  @override
  String get missionReportRounds => 'Rodadas';

  @override
  String get missionReportPracticeMore => 'Sons para praticar mais';

  @override
  String get missionReportConfusedMost =>
      'Estes foram os que mais confundiram nesta sessão.';

  @override
  String get missionReportTipTitle => 'Dica de Comunicação';

  @override
  String get missionReportTip1Title => 'Fique de frente para quem fala';

  @override
  String get missionReportTip1Desc =>
      'Olhar diretamente para o rosto da pessoa ajuda seu cérebro a usar a leitura labial para preencher as falhas do som.';

  @override
  String get missionReportTip2Title => 'Ajuste seus aparelhos auditivos';

  @override
  String get missionReportTip2Desc =>
      'Antes de começar o treino ou uma conversa importante, certifique-se de que seus aparelhos estão ligados e regulados no volume confortável.';

  @override
  String get missionReportTip3Title => 'Peça para falar mais devagar';

  @override
  String get missionReportTip3Desc =>
      'Dizer \"fale um pouco mais devagar, por favor\" é mais eficiente do que apenas pedir para falar mais alto.';

  @override
  String get missionReportTip4Title => 'Reduza os barulhos ao redor';

  @override
  String get missionReportTip4Desc =>
      'Em uma conversa, tente desligar a TV ou se afastar de fontes de ruído para facilitar a compreensão da fala.';

  @override
  String get missionReportAdaptive90 =>
      'Excelente! Seus ouvidos estão cada vez mais afiados.';

  @override
  String get missionReportAdaptive70 =>
      'Muito bem! Continue assim e o progresso vai aparecer.';

  @override
  String get missionReportAdaptive50 =>
      'Bom treino! A prática faz a diferença — volte amanhã.';

  @override
  String get missionReportAdaptive0 =>
      'Todo treino conta. O importante é a constância.';

  @override
  String dashboardCorrectAnswers(String correct, String total) {
    return '$correct/$total acertos';
  }

  @override
  String dashboardTrialsRemaining(String count) {
    return '$count restam';
  }

  @override
  String get sentenceHubTitle => 'Frases do dia a dia';

  @override
  String get sentenceHubHeadline => 'Ajude o Seu João';

  @override
  String get sentenceHubSubtitle =>
      'Ele vai a vários lugares cheios de barulho. Escolha um e ajude o Seu João a entender o que falam com ele.';

  @override
  String get envRestaurantTitle => 'No restaurante';

  @override
  String get envRestaurantSubtitle =>
      'Ajude o Seu João a entender o pedido no meio das conversas.';

  @override
  String get envRestaurantOpening =>
      'Tá uma conversa danada aqui. Me ajuda a ouvir o garçom?';

  @override
  String get envGymTitle => 'Na academia';

  @override
  String get envGymSubtitle =>
      'Ajude o Seu João a entender o instrutor com a música alta.';

  @override
  String get envGymOpening =>
      'A música tá alta. O que o instrutor falou mesmo?';

  @override
  String get envParkTitle => 'Na praça';

  @override
  String get envParkSubtitle =>
      'Ajude o Seu João a entender quem fala com ele ao ar livre.';

  @override
  String get envParkOpening =>
      'Quanta criança! Vamos ver se a gente entende direitinho.';

  @override
  String get envMarketTitle => 'No mercado';

  @override
  String get envMarketSubtitle =>
      'Ajude o Seu João a entender o vendedor na correria da feira.';

  @override
  String get envMarketOpening =>
      'Tá cheio hoje. Me ajuda a ouvir o que o moço disse?';

  @override
  String get sentenceFeedbackCorrect => 'Isso! O Seu João entendeu.';

  @override
  String sentenceFeedbackWrong(String target) {
    return 'Quase. Era \"$target\".';
  }

  @override
  String get sentenceResultDialogTitle => 'Você ajudou bastante o Seu João!';

  @override
  String get sentenceResultDialogUnderstood => 'Entendi';

  @override
  String get sentenceWhichSentence => 'Qual frase ele ouviu?';

  @override
  String sentenceNoiseLevel(String db) {
    return 'Barulho: $db dB';
  }

  @override
  String sentenceTrainingProgress(String current, String total) {
    return 'Frase $current de $total';
  }

  @override
  String sentenceResultDialogBody(String envTitle, String srt) {
    return 'No $envTitle, o Seu João entendeu as frases com até $srt dB de barulho de fundo. Quanto menor esse número, melhor ele ouve no meio do barulho. Continue treinando!';
  }

  @override
  String get dailyLimitTitle => 'Meta diária concluída!';

  @override
  String get dailyLimitBody =>
      'Você concluiu as 2 sessões gratuitas de hoje. Praticar diariamente é fundamental para sua reabilitação auditiva. Para continuar treinando hoje, você pode:';

  @override
  String get dailyLimitWatchAdButton =>
      'Assistir a um vídeo curto (+2 treinos)';

  @override
  String get dailyLimitSubscribeButton => 'Assinar Plano Premium';

  @override
  String get dailyLimitCancelButton => 'Voltar para o início';

  @override
  String get dailyLimitLoadingAd => 'Carregando o vídeo...';
}
