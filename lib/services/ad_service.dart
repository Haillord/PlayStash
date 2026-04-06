// lib/services/ad_service.dart

import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

const _kInterstitialAdUnitId = 'R-M-18710519-3';
const _kRewardedAdUnitId = 'R-M-18710519-2';
class AdService {
  AdService._();
  static final instance = AdService._();

  InterstitialAdLoader? _interstitialLoader;
  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;

  RewardedAdLoader? _rewardedLoader;
  RewardedAd? _rewardedAd;
  bool _rewardedReady = false;

  // Cooldown-based: реклама не чаще раза в 4 минуты.
  static const _interstitialCooldown = Duration(minutes: 4);
  DateTime? _lastInterstitialShown;

  Future<void> init() async {
    MobileAds.initialize();
    await _setupInterstitial();
    await _setupRewarded();
  }

  // ── МЕЖСТРАНИЧНАЯ ──────────────────────────────────────────────────────────

  Future<void> _setupInterstitial() async {
    _interstitialLoader = await InterstitialAdLoader.create(
      onAdLoaded: (InterstitialAd ad) {
        _interstitialAd = ad;
        _interstitialReady = true;
      },
      onAdFailedToLoad: (error) {
        debugPrint('Interstitial load error: ${error.description}');
        _interstitialReady = false;
      },
    );
    await _loadInterstitial();
  }

  Future<void> _loadInterstitial() async {
    await _interstitialLoader?.loadAd(
      adRequestConfiguration: const AdRequestConfiguration(
        adUnitId: _kInterstitialAdUnitId,
      ),
    );
  }

  Future<void> onGameOpened(BuildContext context) async {
    final now = DateTime.now();
    if (_lastInterstitialShown == null) {
      _lastInterstitialShown = now;
      return;
    }
    if (now.difference(_lastInterstitialShown!) < _interstitialCooldown) return;
    _lastInterstitialShown = now;
    showInterstitial(context);
  }

  Future<void> showInterstitial(BuildContext context) async {
    if (!_interstitialReady || _interstitialAd == null) {
      await _loadInterstitial();
      return;
    }
    _interstitialAd!.setAdEventListener(
      eventListener: InterstitialAdEventListener(
        onAdShown: () => debugPrint('Interstitial shown'),
        onAdDismissed: () {
          _interstitialAd?.destroy();
          _interstitialAd = null;
          _interstitialReady = false;
          _loadInterstitial();
        },
        onAdClicked: () {},
        onAdFailedToShow: (error) {
          _interstitialAd?.destroy();
          _interstitialAd = null;
          _interstitialReady = false;
          _loadInterstitial();
        },
        onAdImpression: (_) {},
      ),
    );
    await _interstitialAd!.show();
  }

  // ── REWARDED ───────────────────────────────────────────────────────────────

  Future<void> _setupRewarded() async {
    _rewardedLoader = await RewardedAdLoader.create(
      onAdLoaded: (RewardedAd ad) {
        _rewardedAd = ad;
        _rewardedReady = true;
      },
      onAdFailedToLoad: (error) {
        debugPrint('Rewarded load error: ${error.description}');
        _rewardedReady = false;
      },
    );
    await _loadRewarded();
  }

  Future<void> _loadRewarded() async {
    await _rewardedLoader?.loadAd(
      adRequestConfiguration: const AdRequestConfiguration(
        adUnitId: _kRewardedAdUnitId,
      ),
    );
  }

  /// Показать rewarded рекламу.
  /// [onRewarded] вызывается когда пользователь досмотрел до конца.
  Future<void> showRewarded({
    required BuildContext context,
    required Future<void> Function() onRewarded,
    VoidCallback? onNotReady,
  }) async {
    if (!_rewardedReady || _rewardedAd == null) {
      onNotReady?.call();
      await _loadRewarded();
      return;
    }
    _rewardedAd!.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown: () => debugPrint('Rewarded shown'),
        onAdDismissed: () {
          _rewardedAd?.destroy();
          _rewardedAd = null;
          _rewardedReady = false;
          _loadRewarded();
        },
        onAdClicked: () {},
        onAdFailedToShow: (error) {
          _rewardedAd?.destroy();
          _rewardedAd = null;
          _rewardedReady = false;
          _loadRewarded();
          onNotReady?.call();
        },
        onAdImpression: (_) {},
        onRewarded: (reward) async {
          debugPrint('Rewarded: ${reward.type} x${reward.amount}');
          await onRewarded();
        },
      ),
    );
    await _rewardedAd!.show();
  }

  bool get isRewardedReady => _rewardedReady;

  void dispose() {
    _interstitialAd?.destroy();
    _rewardedAd?.destroy();
  }
}