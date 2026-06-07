import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt')
  ];

  /// Título do app (MaterialApp.title).
  ///
  /// In pt, this message translates to:
  /// **'BOSYN - Reabilitação Auditiva'**
  String get appTitle;

  /// Cabeçalho da seção de treinos na Home.
  ///
  /// In pt, this message translates to:
  /// **'Seus treinos'**
  String get homeYourTrainings;

  /// Subtítulo da seção de treinos: convida a começar pelo teste de audição.
  ///
  /// In pt, this message translates to:
  /// **'Comece pelo teste de audição — ele deixa tudo no seu ritmo.'**
  String get homeStartWithHearingTest;

  /// Título do card do teste de audição (módulo âncora).
  ///
  /// In pt, this message translates to:
  /// **'Teste de audição'**
  String get hearingTestTitle;

  /// No description provided for @hearingTestSubtitleNew.
  ///
  /// In pt, this message translates to:
  /// **'Comece por aqui — ele personaliza todo o seu treino.'**
  String get hearingTestSubtitleNew;

  /// No description provided for @hearingTestSubtitleDone.
  ///
  /// In pt, this message translates to:
  /// **'Concluído. Você pode refazer quando quiser.'**
  String get hearingTestSubtitleDone;

  /// No description provided for @speechInNoiseTestTitle.
  ///
  /// In pt, this message translates to:
  /// **'Teste de fala no barulho'**
  String get speechInNoiseTestTitle;

  /// No description provided for @speechInNoiseTestSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Veja o quanto você entende falas no barulho — e acompanhe sua evolução.'**
  String get speechInNoiseTestSubtitle;

  /// No description provided for @speechInNoiseNeedsHearingTest.
  ///
  /// In pt, this message translates to:
  /// **'Faça primeiro o teste de audição — ele personaliza o som deste teste.'**
  String get speechInNoiseNeedsHearingTest;

  /// No description provided for @level2Title.
  ///
  /// In pt, this message translates to:
  /// **'Distinguir sons parecidos'**
  String get level2Title;

  /// No description provided for @level2Subtitle.
  ///
  /// In pt, this message translates to:
  /// **'Treine sons que se confundem, como \"fala\" e \"sala\".'**
  String get level2Subtitle;

  /// No description provided for @level3Title.
  ///
  /// In pt, this message translates to:
  /// **'De que lado vem o som'**
  String get level3Title;

  /// No description provided for @level3Subtitle.
  ///
  /// In pt, this message translates to:
  /// **'Perceba a direção do som — esquerda, centro, direita.'**
  String get level3Subtitle;

  /// No description provided for @level4Title.
  ///
  /// In pt, this message translates to:
  /// **'Entender no meio do barulho'**
  String get level4Title;

  /// No description provided for @level4Subtitle.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe a fala mesmo com som de fundo.'**
  String get level4Subtitle;

  /// No description provided for @sentenceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Frases do dia a dia'**
  String get sentenceTitle;

  /// No description provided for @sentenceSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ajude o Seu João a entender frases inteiras no barulho.'**
  String get sentenceSubtitle;

  /// No description provided for @commonStart.
  ///
  /// In pt, this message translates to:
  /// **'Começar'**
  String get commonStart;

  /// No description provided for @commonBack.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// No description provided for @commonYes.
  ///
  /// In pt, this message translates to:
  /// **'SIM'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In pt, this message translates to:
  /// **'NÃO'**
  String get commonNo;

  /// No description provided for @commonSaveAndBack.
  ///
  /// In pt, this message translates to:
  /// **'Salvar e voltar'**
  String get commonSaveAndBack;

  /// No description provided for @commonRetake.
  ///
  /// In pt, this message translates to:
  /// **'Refazer teste'**
  String get commonRetake;

  /// No description provided for @hearingTestWhichEar.
  ///
  /// In pt, this message translates to:
  /// **'Qual ouvido você quer testar?'**
  String get hearingTestWhichEar;

  /// No description provided for @hearingTestPutHeadphones.
  ///
  /// In pt, this message translates to:
  /// **'Coloque os fones. Vamos testar um ouvido de cada vez.'**
  String get hearingTestPutHeadphones;

  /// No description provided for @hearingTestLeftEar.
  ///
  /// In pt, this message translates to:
  /// **'Ouvido esquerdo'**
  String get hearingTestLeftEar;

  /// No description provided for @hearingTestRightEar.
  ///
  /// In pt, this message translates to:
  /// **'Ouvido direito'**
  String get hearingTestRightEar;

  /// No description provided for @hearingTestDidYouHear.
  ///
  /// In pt, this message translates to:
  /// **'Você ouviu o som?'**
  String get hearingTestDidYouHear;

  /// No description provided for @hearingTestAdjustVolume.
  ///
  /// In pt, this message translates to:
  /// **'Ajustar o volume'**
  String get hearingTestAdjustVolume;

  /// No description provided for @hearingTestVolumeCardTitle.
  ///
  /// In pt, this message translates to:
  /// **'Vamos acertar o nível de som'**
  String get hearingTestVolumeCardTitle;

  /// No description provided for @hearingTestVolumeCardBody.
  ///
  /// In pt, this message translates to:
  /// **'Para o teste valer, o som precisa ficar num nível certo — o mesmo dos treinos. Coloque os fones e toque abaixo: vamos ajustar o volume devagar, sem susto.'**
  String get hearingTestVolumeCardBody;

  /// Nome do idioma no seletor de idioma, na própria língua.
  ///
  /// In pt, this message translates to:
  /// **'Português'**
  String get languageName;

  /// Rótulo do seletor de idioma.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get settingsLanguage;

  /// No description provided for @authWelcomeBack.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo de volta'**
  String get authWelcomeBack;

  /// No description provided for @authCreateAccount.
  ///
  /// In pt, this message translates to:
  /// **'Vamos criar sua conta'**
  String get authCreateAccount;

  /// No description provided for @authWelcomeSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Entre para continuar seu treino auditivo.'**
  String get authWelcomeSubtitle;

  /// No description provided for @authCreateSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'É rápido. Depois preparamos tudo no seu ritmo.'**
  String get authCreateSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In pt, this message translates to:
  /// **'Seu e-mail'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In pt, this message translates to:
  /// **'Sua senha'**
  String get authPasswordLabel;

  /// No description provided for @authSignIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In pt, this message translates to:
  /// **'Criar conta'**
  String get authSignUp;

  /// No description provided for @authSwitchToSignUp.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não tem conta? Criar agora'**
  String get authSwitchToSignUp;

  /// No description provided for @authSwitchToSignIn.
  ///
  /// In pt, this message translates to:
  /// **'Já tem conta? Entrar'**
  String get authSwitchToSignIn;

  /// No description provided for @authError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível entrar. Confira seu e-mail e senha.'**
  String get authError;

  /// No description provided for @authSignUpSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Conta criada! Verifique seu e-mail para confirmar.'**
  String get authSignUpSuccess;

  /// Rótulo do botão de logout no menu da Home.
  ///
  /// In pt, this message translates to:
  /// **'Sair da conta'**
  String get logout;

  /// Tooltip do botão de menu (⋮) no topo da Home.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get settingsMenuTooltip;

  /// Opção do menu para ativar o tema claro.
  ///
  /// In pt, this message translates to:
  /// **'Visual claro'**
  String get themeUseLight;

  /// Opção do menu para ativar o tema escuro.
  ///
  /// In pt, this message translates to:
  /// **'Visual escuro'**
  String get themeUseDark;

  /// No description provided for @homeGreeting.
  ///
  /// In pt, this message translates to:
  /// **'Olá!'**
  String get homeGreeting;

  /// No description provided for @homeGreetingSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Que bom ter você aqui. Vamos treinar um pouco hoje?'**
  String get homeGreetingSubtitle;

  /// No description provided for @homeProgressTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sua evolução'**
  String get homeProgressTitle;

  /// No description provided for @homeProgressLastAccuracy.
  ///
  /// In pt, this message translates to:
  /// **'Últimos acertos: {percent}%. Toque para ver mais.'**
  String homeProgressLastAccuracy(String percent);

  /// No description provided for @homeProgressEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Faça seu primeiro treino para acompanhar aqui.'**
  String get homeProgressEmpty;

  /// No description provided for @homeProgressTapHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque para ver mais.'**
  String get homeProgressTapHint;

  /// No description provided for @homeDailyGoalTitle.
  ///
  /// In pt, this message translates to:
  /// **'Meta diária (15 min)'**
  String get homeDailyGoalTitle;

  /// No description provided for @homeDailyGoalDone.
  ///
  /// In pt, this message translates to:
  /// **'Meta batida! Excelente treino hoje.'**
  String get homeDailyGoalDone;

  /// No description provided for @homeDailyGoalProgress.
  ///
  /// In pt, this message translates to:
  /// **'{minutes} min treinados de 15 min.'**
  String homeDailyGoalProgress(String minutes);

  /// No description provided for @homePermissionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Vamos preparar o som'**
  String get homePermissionTitle;

  /// No description provided for @homePermissionBody.
  ///
  /// In pt, this message translates to:
  /// **'Para tocar os sons do treino e reconhecer seus fones, o app precisa da sua permissão para o microfone e o Bluetooth.'**
  String get homePermissionBody;

  /// No description provided for @homePermissionAllow.
  ///
  /// In pt, this message translates to:
  /// **'Permitir'**
  String get homePermissionAllow;

  /// No description provided for @homePermissionOpenSettings.
  ///
  /// In pt, this message translates to:
  /// **'Abrir configurações'**
  String get homePermissionOpenSettings;

  /// No description provided for @homePermissionDeniedHint.
  ///
  /// In pt, this message translates to:
  /// **'A permissão foi recusada. Toque acima para abrir as configurações e habilitar manualmente.'**
  String get homePermissionDeniedHint;

  /// No description provided for @homeSavedAudiogram.
  ///
  /// In pt, this message translates to:
  /// **'Teste salvo! O treino agora é personalizado para você.'**
  String get homeSavedAudiogram;

  /// No description provided for @homeSaveAudiogramError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao salvar o teste. Tente novamente.'**
  String get homeSaveAudiogramError;

  /// No description provided for @homeSentenceNeedsAudiogram.
  ///
  /// In pt, this message translates to:
  /// **'Faça primeiro o teste de audição para liberar este treino.'**
  String get homeSentenceNeedsAudiogram;

  /// No description provided for @homeSelfPerceptionThanks.
  ///
  /// In pt, this message translates to:
  /// **'Obrigado por compartilhar!'**
  String get homeSelfPerceptionThanks;

  /// Aviso na Home quando a variante de voz do idioma atual não está instalada no device.
  ///
  /// In pt, this message translates to:
  /// **'A voz em {voice} não está instalada neste aparelho.'**
  String ttsVoiceMissingTitle(String voice);

  /// No description provided for @ttsVoiceMissingWhy.
  ///
  /// In pt, this message translates to:
  /// **'As palavras podem soar com outro sotaque. Instalar a voz certa deixa o treino mais natural.'**
  String get ttsVoiceMissingWhy;

  /// No description provided for @ttsVoiceInstallButton.
  ///
  /// In pt, this message translates to:
  /// **'Instalar a voz'**
  String get ttsVoiceInstallButton;

  /// No description provided for @ttsVoiceMissingIosHint.
  ///
  /// In pt, this message translates to:
  /// **'Vá em Ajustes › Acessibilidade › Conteúdo falado › Vozes para instalar.'**
  String get ttsVoiceMissingIosHint;

  /// No description provided for @ttsVoiceRecheck.
  ///
  /// In pt, this message translates to:
  /// **'Já instalei a voz'**
  String get ttsVoiceRecheck;

  /// No description provided for @ttsVoiceStillMissing.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não encontramos a voz. Pode levar um instante após instalar — tente de novo em alguns segundos.'**
  String get ttsVoiceStillMissing;

  /// No description provided for @ttsVoicePtBrName.
  ///
  /// In pt, this message translates to:
  /// **'português do Brasil'**
  String get ttsVoicePtBrName;

  /// No description provided for @ttsVoiceEnUsName.
  ///
  /// In pt, this message translates to:
  /// **'inglês americano'**
  String get ttsVoiceEnUsName;

  /// No description provided for @homeLockUnlockHint.
  ///
  /// In pt, this message translates to:
  /// **'Acerte 70% no \"Distinguir sons\" para liberar. Você está com {percent}%.'**
  String homeLockUnlockHint(String percent);

  /// No description provided for @homeLockUnlockHintNoProgress.
  ///
  /// In pt, this message translates to:
  /// **'Acerte 70% no \"Distinguir sons\" para liberar este treino.'**
  String get homeLockUnlockHintNoProgress;

  /// No description provided for @homeLockHowTitle.
  ///
  /// In pt, this message translates to:
  /// **'Como desbloquear'**
  String get homeLockHowTitle;

  /// No description provided for @homeLockHowBody.
  ///
  /// In pt, this message translates to:
  /// **'Esse treino é liberado quando você atingir 70% de acertos no \"{name}\" (média das últimas 3 sessões).'**
  String homeLockHowBody(String name);

  /// No description provided for @homeLockNearlyThere.
  ///
  /// In pt, this message translates to:
  /// **'Quase lá! Você está com {percent}%.'**
  String homeLockNearlyThere(String percent);

  /// No description provided for @homeLockKeepGoing.
  ///
  /// In pt, this message translates to:
  /// **'Você está com {percent}%. Continue treinando!'**
  String homeLockKeepGoing(String percent);

  /// No description provided for @homeLockNeedSessions.
  ///
  /// In pt, this message translates to:
  /// **'Faça pelo menos 3 sessões de \"{name}\" para começar a medir seu progresso.'**
  String homeLockNeedSessions(String name);

  /// No description provided for @homeLockTrainButton.
  ///
  /// In pt, this message translates to:
  /// **'Treinar \"{name}\"'**
  String homeLockTrainButton(String name);

  /// No description provided for @levelNameL2.
  ///
  /// In pt, this message translates to:
  /// **'Distinguir sons'**
  String get levelNameL2;

  /// No description provided for @levelNameL3.
  ///
  /// In pt, this message translates to:
  /// **'De que lado vem o som'**
  String get levelNameL3;

  /// No description provided for @levelNameL4.
  ///
  /// In pt, this message translates to:
  /// **'Entender no barulho'**
  String get levelNameL4;

  /// No description provided for @paywallTitle.
  ///
  /// In pt, this message translates to:
  /// **'Treino completo'**
  String get paywallTitle;

  /// No description provided for @paywallBody.
  ///
  /// In pt, this message translates to:
  /// **'O treino de frases do dia a dia faz parte da assinatura. Assim você treina de ponta a ponta, no seu ritmo.'**
  String get paywallBody;

  /// No description provided for @paywallSubscribeButton.
  ///
  /// In pt, this message translates to:
  /// **'Assinar'**
  String get paywallSubscribeButton;

  /// No description provided for @progressBarCurrentLabel.
  ///
  /// In pt, this message translates to:
  /// **'{percent}% atual'**
  String progressBarCurrentLabel(String percent);

  /// No description provided for @progressBarTargetLabel.
  ///
  /// In pt, this message translates to:
  /// **'Meta: {percent}%'**
  String progressBarTargetLabel(String percent);

  /// No description provided for @thresholdTestTitle.
  ///
  /// In pt, this message translates to:
  /// **'Teste de audição'**
  String get thresholdTestTitle;

  /// No description provided for @thresholdTestWhichEar.
  ///
  /// In pt, this message translates to:
  /// **'Qual ouvido você quer testar?'**
  String get thresholdTestWhichEar;

  /// No description provided for @thresholdTestPutHeadphones.
  ///
  /// In pt, this message translates to:
  /// **'Coloque os fones. Vamos testar um ouvido de cada vez.'**
  String get thresholdTestPutHeadphones;

  /// No description provided for @thresholdTestMonoWarningTitle.
  ///
  /// In pt, this message translates to:
  /// **'Áudio mono está ligado'**
  String get thresholdTestMonoWarningTitle;

  /// No description provided for @thresholdTestMonoWarningBody.
  ///
  /// In pt, this message translates to:
  /// **'Seu celular está tocando o mesmo som nos dois ouvidos, o que atrapalha o teste. Desligue em:\nConfigurações → Acessibilidade → Áudio → Áudio mono.'**
  String get thresholdTestMonoWarningBody;

  /// No description provided for @thresholdTestVolumeDriftTitle.
  ///
  /// In pt, this message translates to:
  /// **'O volume mudou'**
  String get thresholdTestVolumeDriftTitle;

  /// No description provided for @thresholdTestVolumeDriftBody.
  ///
  /// In pt, this message translates to:
  /// **'O nível de som saiu do ponto certo. Para o teste continuar valendo, vamos voltar ao nível e ouvir o som de novo.'**
  String get thresholdTestVolumeDriftBody;

  /// No description provided for @thresholdTestVolumeDriftButton.
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao nível e continuar'**
  String get thresholdTestVolumeDriftButton;

  /// No description provided for @thresholdTestLeftEarLabel.
  ///
  /// In pt, this message translates to:
  /// **'◀  OUVIDO ESQUERDO'**
  String get thresholdTestLeftEarLabel;

  /// No description provided for @thresholdTestRightEarLabel.
  ///
  /// In pt, this message translates to:
  /// **'OUVIDO DIREITO  ▶'**
  String get thresholdTestRightEarLabel;

  /// No description provided for @thresholdTestFamiliarization.
  ///
  /// In pt, this message translates to:
  /// **'Fase de Familiarização'**
  String get thresholdTestFamiliarization;

  /// No description provided for @thresholdTestPreparing.
  ///
  /// In pt, this message translates to:
  /// **'Preparando próximo tom...'**
  String get thresholdTestPreparing;

  /// No description provided for @thresholdTestListening.
  ///
  /// In pt, this message translates to:
  /// **'Ouça com atenção...'**
  String get thresholdTestListening;

  /// No description provided for @thresholdTestDidYouHear.
  ///
  /// In pt, this message translates to:
  /// **'Você ouviu o som?'**
  String get thresholdTestDidYouHear;

  /// No description provided for @thresholdTestSoundLevel.
  ///
  /// In pt, this message translates to:
  /// **'Nível de som: {db}'**
  String thresholdTestSoundLevel(String db);

  /// No description provided for @thresholdTestCatchTrialWarning.
  ///
  /// In pt, this message translates to:
  /// **'Atenção: Nenhum som foi tocado agora. Por favor, responda apenas quando realmente ouvir o som.'**
  String get thresholdTestCatchTrialWarning;

  /// No description provided for @thresholdTestResults.
  ///
  /// In pt, this message translates to:
  /// **'Resultado do teste'**
  String get thresholdTestResults;

  /// No description provided for @thresholdTestViewResult.
  ///
  /// In pt, this message translates to:
  /// **'Ver resultado'**
  String get thresholdTestViewResult;

  /// No description provided for @thresholdTestViewResultOneEar.
  ///
  /// In pt, this message translates to:
  /// **'Ver resultado (só 1 ouvido testado)'**
  String get thresholdTestViewResultOneEar;

  /// No description provided for @thresholdTestLeftEar.
  ///
  /// In pt, this message translates to:
  /// **'Ouvido esquerdo'**
  String get thresholdTestLeftEar;

  /// No description provided for @thresholdTestRightEar.
  ///
  /// In pt, this message translates to:
  /// **'Ouvido direito'**
  String get thresholdTestRightEar;

  /// No description provided for @thresholdTestEarDone.
  ///
  /// In pt, this message translates to:
  /// **'Já testado — toque para refazer'**
  String get thresholdTestEarDone;

  /// No description provided for @thresholdTestEarTap.
  ///
  /// In pt, this message translates to:
  /// **'Tocar para testar'**
  String get thresholdTestEarTap;

  /// No description provided for @thresholdTestLastResult.
  ///
  /// In pt, this message translates to:
  /// **'Seu último teste de audição'**
  String get thresholdTestLastResult;

  /// No description provided for @thresholdTestDoneOn.
  ///
  /// In pt, this message translates to:
  /// **'Feito em {date}'**
  String thresholdTestDoneOn(String date);

  /// No description provided for @thresholdTestBack.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get thresholdTestBack;

  /// No description provided for @dashboardTitleL2.
  ///
  /// In pt, this message translates to:
  /// **'Distinguir sons'**
  String get dashboardTitleL2;

  /// No description provided for @dashboardTitleL3.
  ///
  /// In pt, this message translates to:
  /// **'De que lado vem o som'**
  String get dashboardTitleL3;

  /// No description provided for @dashboardTitleL4.
  ///
  /// In pt, this message translates to:
  /// **'Entender no barulho'**
  String get dashboardTitleL4;

  /// No description provided for @dashboardDescL2.
  ///
  /// In pt, this message translates to:
  /// **'Você vai ouvir uma palavra e escolher, entre duas parecidas, qual foi dita. Treina sons que se confundem.'**
  String get dashboardDescL2;

  /// No description provided for @dashboardDescL3.
  ///
  /// In pt, this message translates to:
  /// **'Você vai ouvir um som e dizer de que lado ele veio: esquerda, centro ou direita.'**
  String get dashboardDescL3;

  /// No description provided for @dashboardDescL4.
  ///
  /// In pt, this message translates to:
  /// **'Você vai ouvir uma palavra com barulho de fundo e escolher qual foi dita. Treina entender no meio do ruído.'**
  String get dashboardDescL4;

  /// No description provided for @dashboardNoAudiogramLoading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando seu teste de audição… tente de novo em instantes.'**
  String get dashboardNoAudiogramLoading;

  /// No description provided for @dashboardNoAudiogramNeeded.
  ///
  /// In pt, this message translates to:
  /// **'Faça primeiro o teste de audição. É ele que escolhe os sons certos para o seu treino — sem ele, não dá para personalizar.'**
  String get dashboardNoAudiogramNeeded;

  /// No description provided for @dashboardFeedbackCorrect.
  ///
  /// In pt, this message translates to:
  /// **'Isso! Você ouviu certo.'**
  String get dashboardFeedbackCorrect;

  /// No description provided for @dashboardFeedbackWrong.
  ///
  /// In pt, this message translates to:
  /// **'Quase. A palavra era \"{word}\". Ouça de novo.'**
  String dashboardFeedbackWrong(String word);

  /// No description provided for @dashboardFeedbackCorrectNoise.
  ///
  /// In pt, this message translates to:
  /// **'Isso! Mesmo no barulho.'**
  String get dashboardFeedbackCorrectNoise;

  /// No description provided for @dashboardFeedbackWrongNoise.
  ///
  /// In pt, this message translates to:
  /// **'Quase. A palavra era \"{word}\".'**
  String dashboardFeedbackWrongNoise(String word);

  /// No description provided for @dashboardFeedbackSideCorrect.
  ///
  /// In pt, this message translates to:
  /// **'Isso! Lado certo.'**
  String get dashboardFeedbackSideCorrect;

  /// No description provided for @dashboardFeedbackSideWrong.
  ///
  /// In pt, this message translates to:
  /// **'Quase. Ouça de novo.'**
  String get dashboardFeedbackSideWrong;

  /// No description provided for @dashboardGoalReached.
  ///
  /// In pt, this message translates to:
  /// **'Meta batida! Pode continuar ou encerrar.'**
  String get dashboardGoalReached;

  /// No description provided for @dashboardGoodEffort.
  ///
  /// In pt, this message translates to:
  /// **'Bom esforço! Pode continuar ou voltar amanhã.'**
  String get dashboardGoodEffort;

  /// No description provided for @dashboardConfirmCondition.
  ///
  /// In pt, this message translates to:
  /// **'Confirme a condição acima para começar.'**
  String get dashboardConfirmCondition;

  /// No description provided for @dashboardWhichWord.
  ///
  /// In pt, this message translates to:
  /// **'Qual palavra você ouviu?'**
  String get dashboardWhichWord;

  /// No description provided for @dashboardWhichSide.
  ///
  /// In pt, this message translates to:
  /// **'De que lado veio o som?'**
  String get dashboardWhichSide;

  /// No description provided for @dashboardSideLeft.
  ///
  /// In pt, this message translates to:
  /// **'Esquerda'**
  String get dashboardSideLeft;

  /// No description provided for @dashboardSideCenter.
  ///
  /// In pt, this message translates to:
  /// **'Centro'**
  String get dashboardSideCenter;

  /// No description provided for @dashboardSideRight.
  ///
  /// In pt, this message translates to:
  /// **'Direita'**
  String get dashboardSideRight;

  /// No description provided for @dashboardListenAgain.
  ///
  /// In pt, this message translates to:
  /// **'Ouvir de novo'**
  String get dashboardListenAgain;

  /// No description provided for @dashboardStartTraining.
  ///
  /// In pt, this message translates to:
  /// **'Começar o treino'**
  String get dashboardStartTraining;

  /// No description provided for @dashboardEndTraining.
  ///
  /// In pt, this message translates to:
  /// **'Encerrar treino'**
  String get dashboardEndTraining;

  /// No description provided for @selfPerceptionQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Quão bem você acompanhou as conversas esta semana?'**
  String get selfPerceptionQuestion;

  /// No description provided for @selfPerceptionSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Sua resposta nos ajuda a acompanhar seu progresso.'**
  String get selfPerceptionSubtitle;

  /// No description provided for @selfPerceptionVeryHard.
  ///
  /// In pt, this message translates to:
  /// **'Muito difícil'**
  String get selfPerceptionVeryHard;

  /// No description provided for @selfPerceptionHard.
  ///
  /// In pt, this message translates to:
  /// **'Difícil'**
  String get selfPerceptionHard;

  /// No description provided for @selfPerceptionSoSo.
  ///
  /// In pt, this message translates to:
  /// **'Mais ou menos'**
  String get selfPerceptionSoSo;

  /// No description provided for @selfPerceptionWell.
  ///
  /// In pt, this message translates to:
  /// **'Bem'**
  String get selfPerceptionWell;

  /// No description provided for @selfPerceptionVeryWell.
  ///
  /// In pt, this message translates to:
  /// **'Muito bem'**
  String get selfPerceptionVeryWell;

  /// No description provided for @listeningModeUnaided.
  ///
  /// In pt, this message translates to:
  /// **'Sem aparelho'**
  String get listeningModeUnaided;

  /// No description provided for @listeningModeAided.
  ///
  /// In pt, this message translates to:
  /// **'Com aparelho'**
  String get listeningModeAided;

  /// No description provided for @listeningModeUnaided_instruction.
  ///
  /// In pt, this message translates to:
  /// **'Tire o aparelho auditivo e coloque os fones.'**
  String get listeningModeUnaided_instruction;

  /// No description provided for @listeningModeAided_instruction.
  ///
  /// In pt, this message translates to:
  /// **'Mantenha seu aparelho auditivo ligado, na regulagem de sempre.'**
  String get listeningModeAided_instruction;

  /// No description provided for @listeningModeUnaided_why.
  ///
  /// In pt, this message translates to:
  /// **'Assim o app ajusta o som no jeito certo para os seus ouvidos.'**
  String get listeningModeUnaided_why;

  /// No description provided for @listeningModeAided_why.
  ///
  /// In pt, this message translates to:
  /// **'Assim o treino combina com o seu dia a dia, em que você usa o aparelho.'**
  String get listeningModeAided_why;

  /// No description provided for @listeningModeUnaided_confirm.
  ///
  /// In pt, this message translates to:
  /// **'Estou sem o aparelho'**
  String get listeningModeUnaided_confirm;

  /// No description provided for @listeningModeAided_confirm.
  ///
  /// In pt, this message translates to:
  /// **'Estou com o aparelho'**
  String get listeningModeAided_confirm;

  /// No description provided for @progressScreenTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sua evolução'**
  String get progressScreenTitle;

  /// No description provided for @progressSessionCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} sessões'**
  String progressSessionCount(String count);

  /// No description provided for @progressDaysStreak.
  ///
  /// In pt, this message translates to:
  /// **'{count} dias seguidos'**
  String progressDaysStreak(String count);

  /// No description provided for @progressAverage.
  ///
  /// In pt, this message translates to:
  /// **'Média: {percent}%'**
  String progressAverage(String percent);

  /// No description provided for @progressModuleDistinguish.
  ///
  /// In pt, this message translates to:
  /// **'Distinguir sons'**
  String get progressModuleDistinguish;

  /// No description provided for @progressModuleDirection.
  ///
  /// In pt, this message translates to:
  /// **'De que lado'**
  String get progressModuleDirection;

  /// No description provided for @progressModuleNoise.
  ///
  /// In pt, this message translates to:
  /// **'No barulho'**
  String get progressModuleNoise;

  /// No description provided for @progressModuleSession1.
  ///
  /// In pt, this message translates to:
  /// **'sessão'**
  String get progressModuleSession1;

  /// No description provided for @progressModuleSessions.
  ///
  /// In pt, this message translates to:
  /// **'sessões'**
  String get progressModuleSessions;

  /// No description provided for @progressModuleNoTraining.
  ///
  /// In pt, this message translates to:
  /// **'Sem treinos'**
  String get progressModuleNoTraining;

  /// No description provided for @progressChartTitle.
  ///
  /// In pt, this message translates to:
  /// **'Acertos ao longo do tempo'**
  String get progressChartTitle;

  /// No description provided for @progressHardestTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sons mais difíceis para você'**
  String get progressHardestTitle;

  /// No description provided for @progressHardestSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Estas foram as palavras que você mais confundiu. Treinar mais ajuda a ouvir melhor.'**
  String get progressHardestSubtitle;

  /// No description provided for @progressHardestNoData.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não errou palavras suficientes para mostrarmos um padrão. Continue treinando!'**
  String get progressHardestNoData;

  /// No description provided for @progressChartNoData.
  ///
  /// In pt, this message translates to:
  /// **'Sem dados de acertos ainda.'**
  String get progressChartNoData;

  /// No description provided for @progressNoTrainingsYet.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há treinos por aqui.\nFaça seu primeiro treino para acompanhar sua evolução.'**
  String get progressNoTrainingsYet;

  /// No description provided for @progressOutcomeCardTitle.
  ///
  /// In pt, this message translates to:
  /// **'Teste de fala no barulho'**
  String get progressOutcomeCardTitle;

  /// No description provided for @progressOutcomeNoHistory.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não fez este teste. Ele mostra o quanto você entende falas no barulho e fica registrado aqui para acompanhar sua evolução. Comece pela tela inicial, no card \"Teste de fala no barulho\".'**
  String get progressOutcomeNoHistory;

  /// No description provided for @progressOutcomeSrtLabel.
  ///
  /// In pt, this message translates to:
  /// **'Limiar de Fala (SRT)'**
  String get progressOutcomeSrtLabel;

  /// No description provided for @progressOutcomeChartTitle.
  ///
  /// In pt, this message translates to:
  /// **'Evolução do Limiar (Menos dB = Melhor)'**
  String get progressOutcomeChartTitle;

  /// No description provided for @progressOutcomeRetakeButton.
  ///
  /// In pt, this message translates to:
  /// **'Fazer o teste de novo'**
  String get progressOutcomeRetakeButton;

  /// No description provided for @progressSrtCardLabel.
  ///
  /// In pt, this message translates to:
  /// **'Entender no barulho'**
  String get progressSrtCardLabel;

  /// No description provided for @progressSrtCardBody.
  ///
  /// In pt, this message translates to:
  /// **'Esse é o nível de barulho em que você ainda entende as palavras. Quanto menor, melhor!'**
  String get progressSrtCardBody;

  /// No description provided for @progressImprovedBy.
  ///
  /// In pt, this message translates to:
  /// **'Melhorou {db} dB'**
  String progressImprovedBy(String db);

  /// No description provided for @progressNoChange.
  ///
  /// In pt, this message translates to:
  /// **'Sem alteração'**
  String get progressNoChange;

  /// No description provided for @progressSinceStart.
  ///
  /// In pt, this message translates to:
  /// **'desde o início'**
  String get progressSinceStart;

  /// No description provided for @progressMoreTests.
  ///
  /// In pt, this message translates to:
  /// **'Realize mais testes para ver a evolução.'**
  String get progressMoreTests;

  /// No description provided for @progressErrorCount1.
  ///
  /// In pt, this message translates to:
  /// **'erro'**
  String get progressErrorCount1;

  /// No description provided for @progressErrorCountN.
  ///
  /// In pt, this message translates to:
  /// **'erros'**
  String get progressErrorCountN;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo ao BOSYN'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody1.
  ///
  /// In pt, this message translates to:
  /// **'Este app foi feito para ajudar você a entender melhor as palavras — mesmo no barulho, mesmo ao telefone.'**
  String get onboardingWelcomeBody1;

  /// No description provided for @onboardingWelcomeBody2.
  ///
  /// In pt, this message translates to:
  /// **'Com alguns minutos de treino por dia, seu cérebro aprende a distinguir sons que ficaram difíceis com o tempo.'**
  String get onboardingWelcomeBody2;

  /// No description provided for @onboardingWelcomeButton.
  ///
  /// In pt, this message translates to:
  /// **'Vamos começar'**
  String get onboardingWelcomeButton;

  /// No description provided for @onboardingAgeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual é a sua faixa de idade?'**
  String get onboardingAgeTitle;

  /// No description provided for @onboardingAgeUnder50.
  ///
  /// In pt, this message translates to:
  /// **'Menos de 50 anos'**
  String get onboardingAgeUnder50;

  /// No description provided for @onboardingAge50to65.
  ///
  /// In pt, this message translates to:
  /// **'50 a 65 anos'**
  String get onboardingAge50to65;

  /// No description provided for @onboardingAge65to75.
  ///
  /// In pt, this message translates to:
  /// **'65 a 75 anos'**
  String get onboardingAge65to75;

  /// No description provided for @onboardingAgeOver75.
  ///
  /// In pt, this message translates to:
  /// **'Mais de 75 anos'**
  String get onboardingAgeOver75;

  /// No description provided for @onboardingContinue.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get onboardingContinue;

  /// No description provided for @onboardingDifficultyTitle.
  ///
  /// In pt, this message translates to:
  /// **'O que mais dificulta sua audição?'**
  String get onboardingDifficultyTitle;

  /// No description provided for @onboardingDifficultySubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Escolha a que mais combina com você.'**
  String get onboardingDifficultySubtitle;

  /// No description provided for @onboardingDifficultyUnderstand.
  ///
  /// In pt, this message translates to:
  /// **'Entender o que as pessoas falam'**
  String get onboardingDifficultyUnderstand;

  /// No description provided for @onboardingDifficultyNoise.
  ///
  /// In pt, this message translates to:
  /// **'Ouvir no barulho (restaurante, TV)'**
  String get onboardingDifficultyNoise;

  /// No description provided for @onboardingDifficultyPhone.
  ///
  /// In pt, this message translates to:
  /// **'Escutar ao telefone'**
  String get onboardingDifficultyPhone;

  /// No description provided for @onboardingDifficultyDirection.
  ///
  /// In pt, this message translates to:
  /// **'Perceber de onde vem o som'**
  String get onboardingDifficultyDirection;

  /// No description provided for @onboardingHearingAidTitle.
  ///
  /// In pt, this message translates to:
  /// **'Você usa aparelho auditivo?'**
  String get onboardingHearingAidTitle;

  /// No description provided for @onboardingHearingAidSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Isso decide como você vai fazer o teste e os treinos. Use sempre do mesmo jeito.'**
  String get onboardingHearingAidSubtitle;

  /// No description provided for @onboardingHearingAidYes.
  ///
  /// In pt, this message translates to:
  /// **'Sim, uso regularmente'**
  String get onboardingHearingAidYes;

  /// No description provided for @onboardingHearingAidNo.
  ///
  /// In pt, this message translates to:
  /// **'Não uso aparelho'**
  String get onboardingHearingAidNo;

  /// No description provided for @onboardingVolumeHint.
  ///
  /// In pt, this message translates to:
  /// **'Ajuste o volume do seu fone até o tom soar confortável:'**
  String get onboardingVolumeHint;

  /// No description provided for @onboardingPlayTone.
  ///
  /// In pt, this message translates to:
  /// **'Tocar tom de teste'**
  String get onboardingPlayTone;

  /// No description provided for @onboardingEnterApp.
  ///
  /// In pt, this message translates to:
  /// **'Entrar no app'**
  String get onboardingEnterApp;

  /// No description provided for @onboardingSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui salvar o teste de audição. Verifique a conexão e refaça em Início.'**
  String get onboardingSaveError;

  /// No description provided for @progressSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao salvar o teste. Tente novamente.'**
  String get progressSaveError;

  /// No description provided for @outcomeTestTitle.
  ///
  /// In pt, this message translates to:
  /// **'Teste de fala no barulho'**
  String get outcomeTestTitle;

  /// No description provided for @outcomeTestMatrixTitle.
  ///
  /// In pt, this message translates to:
  /// **'Teste de Fala no Ruído (Matrix)'**
  String get outcomeTestMatrixTitle;

  /// No description provided for @outcomeTestDescription1.
  ///
  /// In pt, this message translates to:
  /// **'Este teste avalia sua capacidade real de compreender conversas em ambientes barulhentos (efeito coquetel).'**
  String get outcomeTestDescription1;

  /// No description provided for @outcomeTestDescription2.
  ///
  /// In pt, this message translates to:
  /// **'Você ouvirá uma frase no ruído e deverá montá-la selecionando as palavras correspondentes. São 20 frases no total.'**
  String get outcomeTestDescription2;

  /// No description provided for @outcomeTestStart.
  ///
  /// In pt, this message translates to:
  /// **'Começar Teste'**
  String get outcomeTestStart;

  /// No description provided for @outcomeTestSentenceProgress.
  ///
  /// In pt, this message translates to:
  /// **'Frase {current} de {total}'**
  String outcomeTestSentenceProgress(String current, String total);

  /// No description provided for @outcomeTestDifficulty.
  ///
  /// In pt, this message translates to:
  /// **'Dificuldade: {db} dB'**
  String outcomeTestDifficulty(String db);

  /// No description provided for @outcomeTestListenSentence.
  ///
  /// In pt, this message translates to:
  /// **'Ouvir Frase'**
  String get outcomeTestListenSentence;

  /// No description provided for @outcomeTestChooseCategory.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o {category}:'**
  String outcomeTestChooseCategory(String category);

  /// No description provided for @outcomeTestScore.
  ///
  /// In pt, this message translates to:
  /// **'Você acertou {count} de 5 palavras.'**
  String outcomeTestScore(String count);

  /// No description provided for @outcomeTestNextSentence.
  ///
  /// In pt, this message translates to:
  /// **'Próxima Frase'**
  String get outcomeTestNextSentence;

  /// No description provided for @outcomeTestConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get outcomeTestConfirm;

  /// No description provided for @outcomeTestDone.
  ///
  /// In pt, this message translates to:
  /// **'Teste Concluído!'**
  String get outcomeTestDone;

  /// No description provided for @outcomeTestSrtLabel.
  ///
  /// In pt, this message translates to:
  /// **'Limiar de Fala no Ruído (SRT)'**
  String get outcomeTestSrtLabel;

  /// No description provided for @outcomeTestInterpretGood.
  ///
  /// In pt, this message translates to:
  /// **'Excelente capacidade de entender falas mesmo no ruído de fundo.'**
  String get outcomeTestInterpretGood;

  /// No description provided for @outcomeTestInterpretMild.
  ///
  /// In pt, this message translates to:
  /// **'Dificuldade leve. Você consegue entender, mas exige mais esforço mental no ruído.'**
  String get outcomeTestInterpretMild;

  /// No description provided for @outcomeTestInterpretSevere.
  ///
  /// In pt, this message translates to:
  /// **'Dificuldade moderada a severa. Conversar em restaurantes e festas pode ser muito desafiador.'**
  String get outcomeTestInterpretSevere;

  /// No description provided for @outcomeTestBackHome.
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao Início'**
  String get outcomeTestBackHome;

  /// No description provided for @missionReportTitle.
  ///
  /// In pt, this message translates to:
  /// **'Treino concluído!'**
  String get missionReportTitle;

  /// No description provided for @missionReportAccuracy.
  ///
  /// In pt, this message translates to:
  /// **'acertos'**
  String get missionReportAccuracy;

  /// No description provided for @missionReportCorrectLabel.
  ///
  /// In pt, this message translates to:
  /// **'Acertos'**
  String get missionReportCorrectLabel;

  /// No description provided for @missionReportAverageTime.
  ///
  /// In pt, this message translates to:
  /// **'Tempo médio'**
  String get missionReportAverageTime;

  /// No description provided for @missionReportRounds.
  ///
  /// In pt, this message translates to:
  /// **'Rodadas'**
  String get missionReportRounds;

  /// No description provided for @missionReportPracticeMore.
  ///
  /// In pt, this message translates to:
  /// **'Sons para praticar mais'**
  String get missionReportPracticeMore;

  /// No description provided for @missionReportConfusedMost.
  ///
  /// In pt, this message translates to:
  /// **'Estes foram os que mais confundiram nesta sessão.'**
  String get missionReportConfusedMost;

  /// No description provided for @missionReportTipTitle.
  ///
  /// In pt, this message translates to:
  /// **'Dica de Comunicação'**
  String get missionReportTipTitle;

  /// No description provided for @missionReportTip1Title.
  ///
  /// In pt, this message translates to:
  /// **'Fique de frente para quem fala'**
  String get missionReportTip1Title;

  /// No description provided for @missionReportTip1Desc.
  ///
  /// In pt, this message translates to:
  /// **'Olhar diretamente para o rosto da pessoa ajuda seu cérebro a usar a leitura labial para preencher as falhas do som.'**
  String get missionReportTip1Desc;

  /// No description provided for @missionReportTip2Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuste seus aparelhos auditivos'**
  String get missionReportTip2Title;

  /// No description provided for @missionReportTip2Desc.
  ///
  /// In pt, this message translates to:
  /// **'Antes de começar o treino ou uma conversa importante, certifique-se de que seus aparelhos estão ligados e regulados no volume confortável.'**
  String get missionReportTip2Desc;

  /// No description provided for @missionReportTip3Title.
  ///
  /// In pt, this message translates to:
  /// **'Peça para falar mais devagar'**
  String get missionReportTip3Title;

  /// No description provided for @missionReportTip3Desc.
  ///
  /// In pt, this message translates to:
  /// **'Dizer \"fale um pouco mais devagar, por favor\" é mais eficiente do que apenas pedir para falar mais alto.'**
  String get missionReportTip3Desc;

  /// No description provided for @missionReportTip4Title.
  ///
  /// In pt, this message translates to:
  /// **'Reduza os barulhos ao redor'**
  String get missionReportTip4Title;

  /// No description provided for @missionReportTip4Desc.
  ///
  /// In pt, this message translates to:
  /// **'Em uma conversa, tente desligar a TV ou se afastar de fontes de ruído para facilitar a compreensão da fala.'**
  String get missionReportTip4Desc;

  /// No description provided for @missionReportAdaptive90.
  ///
  /// In pt, this message translates to:
  /// **'Excelente! Seus ouvidos estão cada vez mais afiados.'**
  String get missionReportAdaptive90;

  /// No description provided for @missionReportAdaptive70.
  ///
  /// In pt, this message translates to:
  /// **'Muito bem! Continue assim e o progresso vai aparecer.'**
  String get missionReportAdaptive70;

  /// No description provided for @missionReportAdaptive50.
  ///
  /// In pt, this message translates to:
  /// **'Bom treino! A prática faz a diferença — volte amanhã.'**
  String get missionReportAdaptive50;

  /// No description provided for @missionReportAdaptive0.
  ///
  /// In pt, this message translates to:
  /// **'Todo treino conta. O importante é a constância.'**
  String get missionReportAdaptive0;

  /// No description provided for @dashboardCorrectAnswers.
  ///
  /// In pt, this message translates to:
  /// **'{correct}/{total} acertos'**
  String dashboardCorrectAnswers(String correct, String total);

  /// No description provided for @dashboardTrialsRemaining.
  ///
  /// In pt, this message translates to:
  /// **'{count} restam'**
  String dashboardTrialsRemaining(String count);

  /// No description provided for @sentenceHubTitle.
  ///
  /// In pt, this message translates to:
  /// **'Frases do dia a dia'**
  String get sentenceHubTitle;

  /// No description provided for @sentenceHubHeadline.
  ///
  /// In pt, this message translates to:
  /// **'Ajude o Seu João'**
  String get sentenceHubHeadline;

  /// No description provided for @sentenceHubSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ele vai a vários lugares cheios de barulho. Escolha um e ajude o Seu João a entender o que falam com ele.'**
  String get sentenceHubSubtitle;

  /// No description provided for @envRestaurantTitle.
  ///
  /// In pt, this message translates to:
  /// **'No restaurante'**
  String get envRestaurantTitle;

  /// No description provided for @envRestaurantSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ajude o Seu João a entender o pedido no meio das conversas.'**
  String get envRestaurantSubtitle;

  /// No description provided for @envRestaurantOpening.
  ///
  /// In pt, this message translates to:
  /// **'Tá uma conversa danada aqui. Me ajuda a ouvir o garçom?'**
  String get envRestaurantOpening;

  /// No description provided for @envGymTitle.
  ///
  /// In pt, this message translates to:
  /// **'Na academia'**
  String get envGymTitle;

  /// No description provided for @envGymSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ajude o Seu João a entender o instrutor com a música alta.'**
  String get envGymSubtitle;

  /// No description provided for @envGymOpening.
  ///
  /// In pt, this message translates to:
  /// **'A música tá alta. O que o instrutor falou mesmo?'**
  String get envGymOpening;

  /// No description provided for @envParkTitle.
  ///
  /// In pt, this message translates to:
  /// **'Na praça'**
  String get envParkTitle;

  /// No description provided for @envParkSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ajude o Seu João a entender quem fala com ele ao ar livre.'**
  String get envParkSubtitle;

  /// No description provided for @envParkOpening.
  ///
  /// In pt, this message translates to:
  /// **'Quanta criança! Vamos ver se a gente entende direitinho.'**
  String get envParkOpening;

  /// No description provided for @envMarketTitle.
  ///
  /// In pt, this message translates to:
  /// **'No mercado'**
  String get envMarketTitle;

  /// No description provided for @envMarketSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ajude o Seu João a entender o vendedor na correria da feira.'**
  String get envMarketSubtitle;

  /// No description provided for @envMarketOpening.
  ///
  /// In pt, this message translates to:
  /// **'Tá cheio hoje. Me ajuda a ouvir o que o moço disse?'**
  String get envMarketOpening;

  /// No description provided for @sentenceFeedbackCorrect.
  ///
  /// In pt, this message translates to:
  /// **'Isso! O Seu João entendeu.'**
  String get sentenceFeedbackCorrect;

  /// No description provided for @sentenceFeedbackWrong.
  ///
  /// In pt, this message translates to:
  /// **'Quase. Era \"{target}\".'**
  String sentenceFeedbackWrong(String target);

  /// No description provided for @sentenceResultDialogTitle.
  ///
  /// In pt, this message translates to:
  /// **'Você ajudou bastante o Seu João!'**
  String get sentenceResultDialogTitle;

  /// No description provided for @sentenceResultDialogUnderstood.
  ///
  /// In pt, this message translates to:
  /// **'Entendi'**
  String get sentenceResultDialogUnderstood;

  /// No description provided for @sentenceWhichSentence.
  ///
  /// In pt, this message translates to:
  /// **'Qual frase ele ouviu?'**
  String get sentenceWhichSentence;

  /// No description provided for @sentenceNoiseLevel.
  ///
  /// In pt, this message translates to:
  /// **'Barulho: {db} dB'**
  String sentenceNoiseLevel(String db);

  /// No description provided for @sentenceTrainingProgress.
  ///
  /// In pt, this message translates to:
  /// **'Frase {current} de {total}'**
  String sentenceTrainingProgress(String current, String total);

  /// No description provided for @sentenceResultDialogBody.
  ///
  /// In pt, this message translates to:
  /// **'No {envTitle}, o Seu João entendeu as frases com até {srt} dB de barulho de fundo. Quanto menor esse número, melhor ele ouve no meio do barulho. Continue treinando!'**
  String sentenceResultDialogBody(String envTitle, String srt);

  /// No description provided for @dailyLimitTitle.
  ///
  /// In pt, this message translates to:
  /// **'Meta diária concluída!'**
  String get dailyLimitTitle;

  /// No description provided for @dailyLimitBody.
  ///
  /// In pt, this message translates to:
  /// **'Você concluiu as 2 sessões gratuitas de hoje. Praticar diariamente é fundamental para sua reabilitação auditiva. Para continuar treinando hoje, você pode:'**
  String get dailyLimitBody;

  /// No description provided for @dailyLimitWatchAdButton.
  ///
  /// In pt, this message translates to:
  /// **'Assistir a um vídeo curto (+2 treinos)'**
  String get dailyLimitWatchAdButton;

  /// No description provided for @dailyLimitSubscribeButton.
  ///
  /// In pt, this message translates to:
  /// **'Assinar Plano Premium'**
  String get dailyLimitSubscribeButton;

  /// No description provided for @dailyLimitCancelButton.
  ///
  /// In pt, this message translates to:
  /// **'Voltar para o início'**
  String get dailyLimitCancelButton;

  /// No description provided for @dailyLimitLoadingAd.
  ///
  /// In pt, this message translates to:
  /// **'Carregando o vídeo...'**
  String get dailyLimitLoadingAd;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
