import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AD MANAGER SERVICE: Gestor do Ciclo de Vida de Anúncios no BOSYN
///
/// Gerencia anúncios em vídeo premiados (Rewarded Ads) para liberar
/// sessões adicionais de treino para usuários gratuitos.
class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  /// ID de produção do Google para anúncios em vídeo premiados (Rewarded Ads) no Android.
  static const String _rewardedAdUnitId = 'ca-app-pub-2201002106451470/5333990835';

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  int _loadAttempts = 0;

  /// Retorna se há um anúncio pronto para exibição imediata.
  bool get isAdReady => _rewardedAd != null;

  /// Retorna se o anúncio está carregando no momento.
  bool get isAdLoading => _isAdLoading;

  /// Pré-carrega o anúncio premiado de forma assíncrona.
  Future<void> loadRewardedAd() async {
    if (_rewardedAd != null || _isAdLoading) return;

    _isAdLoading = true;
    debugPrint("[AD_MANAGER] Iniciando carregamento do Rewarded Ad...");

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint("[AD_MANAGER] Rewarded Ad carregado com sucesso.");
          _rewardedAd = ad;
          _isAdLoading = false;
          _loadAttempts = 0;
          
          // Configura callbacks de tela inteira
          _setAdCallbacks(ad);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint("[AD_MANAGER] Falha ao carregar Rewarded Ad: ${error.message} (Código: ${error.code})");
          _rewardedAd = null;
          _isAdLoading = false;
          _loadAttempts++;
          
          // Retry com exponential backoff (máximo de 3 tentativas)
          if (_loadAttempts < 3) {
            final delaySeconds = _loadAttempts * 5;
            debugPrint("[AD_MANAGER] Tentando recarregar em $delaySeconds segundos...");
            Future.delayed(Duration(seconds: delaySeconds), () => loadRewardedAd());
          }
        },
      ),
    );
  }

  /// Configura os callbacks de exibição em tela cheia para o anúncio.
  void _setAdCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        debugPrint("[AD_MANAGER] Anúncio exibido em tela cheia.");
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        debugPrint("[AD_MANAGER] Anúncio fechado pelo usuário.");
        ad.dispose();
        _rewardedAd = null;
        // Pré-carrega o próximo anúncio
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint("[AD_MANAGER] Falha ao exibir anúncio: ${error.message}");
        ad.dispose();
        _rewardedAd = null;
        // Pré-carrega o próximo
        loadRewardedAd();
      },
    );
  }

  /// Exibe o anúncio premiado se estiver pronto.
  /// 
  /// [onRewardEarned] é disparado se o usuário assistir até o final e ganhar a recompensa.
  /// [onAdClosed] é disparado quando o anúncio é fechado (mesmo se não foi totalmente assistido).
  /// [onAdFailed] é disparado caso ocorra falha ao carregar ou exibir o anúncio.
  void showRewardedAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdClosed,
    required VoidCallback onAdFailed,
  }) {
    if (_rewardedAd == null) {
      debugPrint("[AD_MANAGER] Tentou exibir ad, mas não está pronto.");
      onAdFailed();
      loadRewardedAd(); // tenta carregar para a próxima
      return;
    }

    bool rewarded = false;

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint("[AD_MANAGER] Usuário ganhou recompensa: ${reward.amount} ${reward.type}");
        rewarded = true;
      },
    );

    // Adicionamos listeners customizados para a finalização
    final oldDismissed = _rewardedAd!.fullScreenContentCallback?.onAdDismissedFullScreenContent;
    final oldFailed = _rewardedAd!.fullScreenContentCallback?.onAdFailedToShowFullScreenContent;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: _rewardedAd!.fullScreenContentCallback?.onAdShowedFullScreenContent,
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        if (oldDismissed != null) oldDismissed(ad);
        if (rewarded) {
          onRewardEarned();
        }
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        if (oldFailed != null) oldFailed(ad, error);
        onAdFailed();
      },
    );
  }
}
