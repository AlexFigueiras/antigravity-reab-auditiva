// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BOSYN - Auditory Rehabilitation';

  @override
  String get homeYourTrainings => 'Your training';

  @override
  String get homeStartWithHearingTest =>
      'Start with the hearing test — it sets everything to your pace.';

  @override
  String get hearingTestTitle => 'Hearing test';

  @override
  String get hearingTestSubtitleNew =>
      'Start here — it personalizes all your training.';

  @override
  String get hearingTestSubtitleDone =>
      'Done. You can retake it whenever you like.';

  @override
  String get speechInNoiseTestTitle => 'Speech-in-noise test';

  @override
  String get speechInNoiseTestSubtitle =>
      'See how well you understand speech in noise — and track your progress.';

  @override
  String get speechInNoiseNeedsHearingTest =>
      'Take the hearing test first — it personalizes the sound of this test.';

  @override
  String get level2Title => 'Tell similar sounds apart';

  @override
  String get level2Subtitle =>
      'Train sounds that get confused, like \"sheep\" and \"cheap\".';

  @override
  String get level3Title => 'Where the sound comes from';

  @override
  String get level3Subtitle =>
      'Sense the direction of sound — left, center, right.';

  @override
  String get level4Title => 'Understand through the noise';

  @override
  String get level4Subtitle => 'Follow speech even with background sound.';

  @override
  String get sentenceTitle => 'Everyday sentences';

  @override
  String get sentenceSubtitle => 'Help understand whole sentences in noise.';

  @override
  String get commonStart => 'Start';

  @override
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonYes => 'YES';

  @override
  String get commonNo => 'NO';

  @override
  String get commonSaveAndBack => 'Save and go back';

  @override
  String get commonRetake => 'Retake test';

  @override
  String get hearingTestWhichEar => 'Which ear do you want to test?';

  @override
  String get hearingTestPutHeadphones =>
      'Put on your headphones. We\'ll test one ear at a time.';

  @override
  String get hearingTestLeftEar => 'Left ear';

  @override
  String get hearingTestRightEar => 'Right ear';

  @override
  String get hearingTestDidYouHear => 'Did you hear the sound?';

  @override
  String get hearingTestAdjustVolume => 'Adjust the volume';

  @override
  String get hearingTestVolumeCardTitle => 'Let\'s set the sound level';

  @override
  String get hearingTestVolumeCardBody =>
      'For the test to be valid, the sound must be at the right level — the same as the training. Put on your headphones and tap below: we\'ll raise the volume slowly, no surprises.';

  @override
  String get languageName => 'English';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authCreateAccount => 'Let\'s create your account';

  @override
  String get authWelcomeSubtitle =>
      'Sign in to continue your hearing training.';

  @override
  String get authCreateSubtitle =>
      'Quick and easy. We\'ll set everything to your pace after.';

  @override
  String get authEmailLabel => 'Your email';

  @override
  String get authPasswordLabel => 'Your password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authSwitchToSignUp => 'Don\'t have an account? Sign up';

  @override
  String get authSwitchToSignIn => 'Already have an account? Sign in';

  @override
  String get authError =>
      'Could not sign in. Please check your email and password.';

  @override
  String get authSignUpSuccess =>
      'Account created! Check your email to confirm.';

  @override
  String get logout => 'Sign out';

  @override
  String get settingsMenuTooltip => 'Settings';

  @override
  String get themeUseLight => 'Light look';

  @override
  String get themeUseDark => 'Dark look';

  @override
  String get homeGreeting => 'Hello!';

  @override
  String get homeGreetingSubtitle =>
      'Great to have you here. Ready to train a little today?';

  @override
  String get homeProgressTitle => 'Your progress';

  @override
  String homeProgressLastAccuracy(String percent) {
    return 'Last score: $percent%. Tap to see more.';
  }

  @override
  String get homeProgressEmpty =>
      'Complete your first session to track progress here.';

  @override
  String get homeProgressTapHint => 'Tap to see more.';

  @override
  String get homeDailyGoalTitle => 'Daily goal (15 min)';

  @override
  String get homeDailyGoalDone => 'Goal reached! Great session today.';

  @override
  String homeDailyGoalProgress(String minutes) {
    return '$minutes min trained out of 15 min.';
  }

  @override
  String get homePermissionTitle => 'Let\'s set up the sound';

  @override
  String get homePermissionBody =>
      'To play training sounds and recognise your headphones, the app needs permission for the microphone and Bluetooth.';

  @override
  String get homePermissionAllow => 'Allow';

  @override
  String get homePermissionOpenSettings => 'Open settings';

  @override
  String get homePermissionDeniedHint =>
      'Permission was denied. Tap above to open settings and enable it manually.';

  @override
  String get homeSavedAudiogram =>
      'Test saved! Your training is now personalised for you.';

  @override
  String get homeSaveAudiogramError =>
      'Could not save the test. Please try again.';

  @override
  String get homeSentenceNeedsAudiogram =>
      'Take the hearing test first to unlock this training.';

  @override
  String get homeSelfPerceptionThanks => 'Thank you for sharing!';

  @override
  String ttsVoiceMissingTitle(String voice) {
    return 'The $voice voice is not installed on this device.';
  }

  @override
  String get ttsVoiceMissingWhy =>
      'Words may sound with a different accent. Installing the right voice makes the training more natural.';

  @override
  String get ttsVoiceInstallButton => 'Install the voice';

  @override
  String get ttsVoiceMissingIosHint =>
      'Go to Settings › Accessibility › Spoken Content › Voices to install it.';

  @override
  String get ttsVoiceRecheck => 'I\'ve installed the voice';

  @override
  String get ttsVoiceStillMissing =>
      'We couldn\'t find the voice yet. It can take a moment after installing — try again in a few seconds.';

  @override
  String get ttsVoicePtBrName => 'Brazilian Portuguese';

  @override
  String get ttsVoiceEnUsName => 'American English';

  @override
  String homeLockUnlockHint(String percent) {
    return 'Score 70% in \"Tell similar sounds apart\" to unlock. You are at $percent%.';
  }

  @override
  String get homeLockUnlockHintNoProgress =>
      'Score 70% in \"Tell similar sounds apart\" to unlock this training.';

  @override
  String get homeLockHowTitle => 'How to unlock';

  @override
  String homeLockHowBody(String name) {
    return 'This training unlocks when you reach 70% in \"$name\" (average of last 3 sessions).';
  }

  @override
  String homeLockNearlyThere(String percent) {
    return 'Almost there! You are at $percent%.';
  }

  @override
  String homeLockKeepGoing(String percent) {
    return 'You are at $percent%. Keep training!';
  }

  @override
  String homeLockNeedSessions(String name) {
    return 'Complete at least 3 sessions of \"$name\" to start measuring your progress.';
  }

  @override
  String homeLockTrainButton(String name) {
    return 'Train \"$name\"';
  }

  @override
  String get levelNameL2 => 'Tell similar sounds apart';

  @override
  String get levelNameL3 => 'Where the sound comes from';

  @override
  String get levelNameL4 => 'Understand through the noise';

  @override
  String get paywallTitle => 'Full training';

  @override
  String get paywallBody =>
      'Everyday sentence training is part of the subscription. Train end-to-end at your own pace.';

  @override
  String get paywallSubscribeButton => 'Subscribe';

  @override
  String progressBarCurrentLabel(String percent) {
    return '$percent% now';
  }

  @override
  String progressBarTargetLabel(String percent) {
    return 'Goal: $percent%';
  }

  @override
  String get thresholdTestTitle => 'Hearing test';

  @override
  String get thresholdTestWhichEar => 'Which ear do you want to test?';

  @override
  String get thresholdTestPutHeadphones =>
      'Put on your headphones. We\'ll test one ear at a time.';

  @override
  String get thresholdTestMonoWarningTitle => 'Mono audio is on';

  @override
  String get thresholdTestMonoWarningBody =>
      'Your phone is playing the same sound in both ears, which affects the test. Turn it off:\nSettings → Accessibility → Audio → Mono audio.';

  @override
  String get thresholdTestVolumeDriftTitle => 'Volume changed';

  @override
  String get thresholdTestVolumeDriftBody =>
      'The sound level moved away from the right point. To keep the test valid, we\'ll go back to the right level and play the sound again.';

  @override
  String get thresholdTestVolumeDriftButton => 'Return to level and continue';

  @override
  String get thresholdTestLeftEarLabel => '◀  LEFT EAR';

  @override
  String get thresholdTestRightEarLabel => 'RIGHT EAR  ▶';

  @override
  String get thresholdTestFamiliarization => 'Familiarisation phase';

  @override
  String get thresholdTestPreparing => 'Getting the next tone ready...';

  @override
  String get thresholdTestListening => 'Listen carefully...';

  @override
  String get thresholdTestDidYouHear => 'Did you hear the sound?';

  @override
  String thresholdTestSoundLevel(String db) {
    return 'Sound level: $db';
  }

  @override
  String get thresholdTestCatchTrialWarning =>
      'Note: No sound was played this time. Please only answer when you actually hear a sound.';

  @override
  String get thresholdTestResults => 'Test results';

  @override
  String get thresholdTestViewResult => 'View result';

  @override
  String get thresholdTestViewResultOneEar => 'View result (only 1 ear tested)';

  @override
  String get thresholdTestLeftEar => 'Left ear';

  @override
  String get thresholdTestRightEar => 'Right ear';

  @override
  String get thresholdTestEarDone => 'Already tested — tap to retake';

  @override
  String get thresholdTestEarTap => 'Tap to test';

  @override
  String get thresholdTestLastResult => 'Your last hearing test';

  @override
  String thresholdTestDoneOn(String date) {
    return 'Done on $date';
  }

  @override
  String get thresholdTestBack => 'Back';

  @override
  String get dashboardTitleL2 => 'Tell similar sounds apart';

  @override
  String get dashboardTitleL3 => 'Where the sound comes from';

  @override
  String get dashboardTitleL4 => 'Understand through the noise';

  @override
  String get dashboardDescL2 =>
      'You\'ll hear a word and choose which of two similar ones was said. Trains sounds that get confused.';

  @override
  String get dashboardDescL3 =>
      'You\'ll hear a sound and say which side it came from: left, centre, or right.';

  @override
  String get dashboardDescL4 =>
      'You\'ll hear a word with background noise and choose which one was said. Trains understanding in noise.';

  @override
  String get dashboardNoAudiogramLoading =>
      'Loading your hearing test… try again in a moment.';

  @override
  String get dashboardNoAudiogramNeeded =>
      'Take the hearing test first. It picks the right sounds for your training — without it, we can\'t personalise.';

  @override
  String get dashboardFeedbackCorrect => 'That\'s it! You heard correctly.';

  @override
  String dashboardFeedbackWrong(String word) {
    return 'Almost. The word was \"$word\". Listen again.';
  }

  @override
  String get dashboardFeedbackCorrectNoise => 'That\'s it! Even in the noise.';

  @override
  String dashboardFeedbackWrongNoise(String word) {
    return 'Almost. The word was \"$word\".';
  }

  @override
  String get dashboardFeedbackSideCorrect => 'That\'s it! Right side.';

  @override
  String get dashboardFeedbackSideWrong => 'Almost. Listen again.';

  @override
  String get dashboardGoalReached =>
      'Goal reached! You can keep going or stop here.';

  @override
  String get dashboardGoodEffort =>
      'Good effort! Keep going or come back tomorrow.';

  @override
  String get dashboardConfirmCondition =>
      'Confirm the condition above to start.';

  @override
  String get dashboardWhichWord => 'Which word did you hear?';

  @override
  String get dashboardWhichSide => 'Which side did the sound come from?';

  @override
  String get dashboardSideLeft => 'Left';

  @override
  String get dashboardSideCenter => 'Centre';

  @override
  String get dashboardSideRight => 'Right';

  @override
  String get dashboardListenAgain => 'Listen again';

  @override
  String get dashboardStartTraining => 'Start training';

  @override
  String get dashboardEndTraining => 'End training';

  @override
  String get selfPerceptionQuestion =>
      'How well did you follow conversations this week?';

  @override
  String get selfPerceptionSubtitle =>
      'Your answer helps us track your progress.';

  @override
  String get selfPerceptionVeryHard => 'Very hard';

  @override
  String get selfPerceptionHard => 'Hard';

  @override
  String get selfPerceptionSoSo => 'So-so';

  @override
  String get selfPerceptionWell => 'Well';

  @override
  String get selfPerceptionVeryWell => 'Very well';

  @override
  String get listeningModeUnaided => 'Without hearing aid';

  @override
  String get listeningModeAided => 'With hearing aid';

  @override
  String get listeningModeUnaided_instruction =>
      'Remove your hearing aid and put on your headphones.';

  @override
  String get listeningModeAided_instruction =>
      'Keep your hearing aid on, at your usual setting.';

  @override
  String get listeningModeUnaided_why =>
      'This way the app adjusts the sound to your ears.';

  @override
  String get listeningModeAided_why =>
      'This way the training matches your everyday life, where you use the aid.';

  @override
  String get listeningModeUnaided_confirm => 'I\'m without the aid';

  @override
  String get listeningModeAided_confirm => 'I\'m wearing the aid';

  @override
  String get progressScreenTitle => 'Your progress';

  @override
  String progressSessionCount(String count) {
    return '$count sessions';
  }

  @override
  String progressDaysStreak(String count) {
    return '$count days in a row';
  }

  @override
  String progressAverage(String percent) {
    return 'Average: $percent%';
  }

  @override
  String get progressModuleDistinguish => 'Tell sounds apart';

  @override
  String get progressModuleDirection => 'Direction';

  @override
  String get progressModuleNoise => 'In noise';

  @override
  String get progressModuleSession1 => 'session';

  @override
  String get progressModuleSessions => 'sessions';

  @override
  String get progressModuleNoTraining => 'No sessions yet';

  @override
  String get progressChartTitle => 'Accuracy over time';

  @override
  String get progressHardestTitle => 'Your hardest sounds';

  @override
  String get progressHardestSubtitle =>
      'These are the words you confused most. More training helps you hear better.';

  @override
  String get progressHardestNoData =>
      'You haven\'t missed enough words yet to show a pattern. Keep training!';

  @override
  String get progressChartNoData => 'No accuracy data yet.';

  @override
  String get progressNoTrainingsYet =>
      'No training sessions yet.\nComplete your first session to track progress here.';

  @override
  String get progressOutcomeCardTitle => 'Speech-in-noise test';

  @override
  String get progressOutcomeNoHistory =>
      'You haven\'t done this test yet. It shows how well you understand speech in noise and is recorded here to track your progress. Start from the home screen, in the \"Speech-in-noise test\" card.';

  @override
  String get progressOutcomeSrtLabel => 'Speech Reception Threshold (SRT)';

  @override
  String get progressOutcomeChartTitle => 'Threshold trend (lower dB = better)';

  @override
  String get progressOutcomeRetakeButton => 'Take the test again';

  @override
  String get progressSrtCardLabel => 'Understand in noise';

  @override
  String get progressSrtCardBody =>
      'This is the noise level at which you can still understand words. Lower is better!';

  @override
  String progressImprovedBy(String db) {
    return 'Improved $db dB';
  }

  @override
  String get progressNoChange => 'No change';

  @override
  String get progressSinceStart => 'since the start';

  @override
  String get progressMoreTests => 'Do more tests to see progress.';

  @override
  String get progressErrorCount1 => 'error';

  @override
  String get progressErrorCountN => 'errors';

  @override
  String get onboardingWelcomeTitle => 'Welcome to BOSYN';

  @override
  String get onboardingWelcomeBody1 =>
      'This app was made to help you understand words better — even in noise, even on the phone.';

  @override
  String get onboardingWelcomeBody2 =>
      'A few minutes of training a day helps your brain tell apart sounds that have become harder over time.';

  @override
  String get onboardingWelcomeButton => 'Let\'s start';

  @override
  String get onboardingAgeTitle => 'What is your age range?';

  @override
  String get onboardingAgeUnder50 => 'Under 50';

  @override
  String get onboardingAge50to65 => '50 to 65';

  @override
  String get onboardingAge65to75 => '65 to 75';

  @override
  String get onboardingAgeOver75 => 'Over 75';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingDifficultyTitle => 'What makes hearing harder for you?';

  @override
  String get onboardingDifficultySubtitle =>
      'Choose the one that fits you best.';

  @override
  String get onboardingDifficultyUnderstand => 'Understanding what people say';

  @override
  String get onboardingDifficultyNoise => 'Hearing in noise (restaurant, TV)';

  @override
  String get onboardingDifficultyPhone => 'Listening on the phone';

  @override
  String get onboardingDifficultyDirection => 'Sensing where sounds come from';

  @override
  String get onboardingHearingAidTitle => 'Do you wear a hearing aid?';

  @override
  String get onboardingHearingAidSubtitle =>
      'This decides how the test and training will work. Always use it the same way.';

  @override
  String get onboardingHearingAidYes => 'Yes, I wear one regularly';

  @override
  String get onboardingHearingAidNo => 'I don\'t wear one';

  @override
  String get onboardingVolumeHint =>
      'Adjust the volume of your headphones until the tone sounds comfortable:';

  @override
  String get onboardingPlayTone => 'Play test tone';

  @override
  String get onboardingEnterApp => 'Enter the app';

  @override
  String get onboardingSaveError =>
      'Could not save the hearing test. Check your connection and redo it from the home screen.';

  @override
  String get progressSaveError => 'Could not save the test. Please try again.';

  @override
  String get outcomeTestTitle => 'Speech-in-noise test';

  @override
  String get outcomeTestMatrixTitle => 'Speech-in-noise test (Matrix)';

  @override
  String get outcomeTestDescription1 =>
      'This test measures how well you understand speech in noisy environments (the cocktail-party effect).';

  @override
  String get outcomeTestDescription2 =>
      'You will hear a sentence in noise and rebuild it by choosing the matching words. There are 20 sentences in total.';

  @override
  String get outcomeTestStart => 'Start test';

  @override
  String outcomeTestSentenceProgress(String current, String total) {
    return 'Sentence $current of $total';
  }

  @override
  String outcomeTestDifficulty(String db) {
    return 'Difficulty: $db dB';
  }

  @override
  String get outcomeTestListenSentence => 'Listen to sentence';

  @override
  String outcomeTestChooseCategory(String category) {
    return 'Choose the $category:';
  }

  @override
  String outcomeTestScore(String count) {
    return 'You got $count out of 5 words right.';
  }

  @override
  String get outcomeTestNextSentence => 'Next sentence';

  @override
  String get outcomeTestConfirm => 'Confirm';

  @override
  String get outcomeTestDone => 'Test complete!';

  @override
  String get outcomeTestSrtLabel => 'Speech Reception Threshold (SRT)';

  @override
  String get outcomeTestInterpretGood =>
      'Excellent ability to follow speech even in background noise.';

  @override
  String get outcomeTestInterpretMild =>
      'Mild difficulty. You can follow speech but it takes more mental effort in noise.';

  @override
  String get outcomeTestInterpretSevere =>
      'Moderate to severe difficulty. Conversations in restaurants and busy places can be very challenging.';

  @override
  String get outcomeTestBackHome => 'Back to home';

  @override
  String get missionReportTitle => 'Training completed!';

  @override
  String get missionReportAccuracy => 'correct';

  @override
  String get missionReportCorrectLabel => 'Correct';

  @override
  String get missionReportAverageTime => 'Average time';

  @override
  String get missionReportRounds => 'Rounds';

  @override
  String get missionReportPracticeMore => 'Sounds to practice more';

  @override
  String get missionReportConfusedMost =>
      'These were the ones that confused you the most this session.';

  @override
  String get missionReportTipTitle => 'Communication Tip';

  @override
  String get missionReportTip1Title => 'Face the speaker';

  @override
  String get missionReportTip1Desc =>
      'Looking directly at the person\'s face helps your brain use lip-reading to fill in sound gaps.';

  @override
  String get missionReportTip2Title => 'Adjust your hearing aids';

  @override
  String get missionReportTip2Desc =>
      'Before starting your training or an important conversation, make sure your hearing aids are on and adjusted to a comfortable volume.';

  @override
  String get missionReportTip3Title => 'Ask them to speak slower';

  @override
  String get missionReportTip3Desc =>
      'Asking someone to \"speak a little slower, please\" is more effective than just asking them to speak louder.';

  @override
  String get missionReportTip4Title => 'Reduce background noise';

  @override
  String get missionReportTip4Desc =>
      'During a conversation, try turning off the TV or moving away from noise sources to make speech easier to understand.';

  @override
  String get missionReportAdaptive90 =>
      'Excellent! Your ears are getting sharper and sharper.';

  @override
  String get missionReportAdaptive70 =>
      'Very well! Keep it up and progress will show.';

  @override
  String get missionReportAdaptive50 =>
      'Good training! Practice makes a difference — come back tomorrow.';

  @override
  String get missionReportAdaptive0 =>
      'Every session counts. The important thing is consistency.';

  @override
  String dashboardCorrectAnswers(String correct, String total) {
    return '$correct/$total correct';
  }

  @override
  String dashboardTrialsRemaining(String count) {
    return '$count remaining';
  }

  @override
  String get sentenceHubTitle => 'Everyday sentences';

  @override
  String get sentenceHubHeadline => 'Help Mr. João';

  @override
  String get sentenceHubSubtitle =>
      'He goes to several noisy places. Choose one and help Mr. João understand what they say to him.';

  @override
  String get envRestaurantTitle => 'At the restaurant';

  @override
  String get envRestaurantSubtitle =>
      'Help Mr. João understand the order in the middle of conversations.';

  @override
  String get envRestaurantOpening =>
      'It\'s very noisy with conversations here. Can you help me hear the waiter?';

  @override
  String get envGymTitle => 'At the gym';

  @override
  String get envGymSubtitle =>
      'Help Mr. João understand the instructor with the loud music.';

  @override
  String get envGymOpening =>
      'The music is loud. What did the instructor say again?';

  @override
  String get envParkTitle => 'At the park';

  @override
  String get envParkSubtitle =>
      'Help Mr. João understand whoever speaks to him outdoors.';

  @override
  String get envParkOpening =>
      'So many kids! Let\'s see if we can understand correctly.';

  @override
  String get envMarketTitle => 'At the market';

  @override
  String get envMarketSubtitle =>
      'Help Mr. João understand the seller in the rush of the market.';

  @override
  String get envMarketOpening =>
      'It\'s crowded today. Can you help me hear what the man said?';

  @override
  String get sentenceFeedbackCorrect => 'That\'s it! Mr. João understood.';

  @override
  String sentenceFeedbackWrong(String target) {
    return 'Almost. It was \"$target\".';
  }

  @override
  String get sentenceResultDialogTitle => 'You helped Mr. João a lot!';

  @override
  String get sentenceResultDialogUnderstood => 'Got it';

  @override
  String get sentenceWhichSentence => 'Which sentence did he hear?';

  @override
  String sentenceNoiseLevel(String db) {
    return 'Noise: $db dB';
  }

  @override
  String sentenceTrainingProgress(String current, String total) {
    return 'Sentence $current of $total';
  }

  @override
  String sentenceResultDialogBody(String envTitle, String srt) {
    return 'At the $envTitle, Mr. João understood the sentences with up to $srt dB of background noise. The lower this number, the better he hears in noise. Keep training!';
  }

  @override
  String get dailyLimitTitle => 'Daily goal completed!';

  @override
  String get dailyLimitBody =>
      'You have completed today\'s 2 free sessions. Practicing daily is essential for your hearing rehabilitation. To continue training today, you can:';

  @override
  String get dailyLimitWatchAdButton => 'Watch a short video (+2 trainings)';

  @override
  String get dailyLimitSubscribeButton => 'Subscribe to Premium Plan';

  @override
  String get dailyLimitCancelButton => 'Back to Home';

  @override
  String get dailyLimitLoadingAd => 'Loading video...';
}
