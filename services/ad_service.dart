import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const bool isTesting = false; // Set to false for production

  // Check if ads are supported on this platform
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // Singleton
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Test Ad Unit IDs (from AdMob documentation)
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testNativeId = 'ca-app-pub-3940256099942544/2247696110';

  // Ad Unit IDs
  static String get bannerAdUnitId =>
      isTesting ? _testBannerId : 'ca-app-pub-8273357965848475/2344996619';
  static String get interstitialAdUnitId => isTesting
      ? _testInterstitialId
      : 'ca-app-pub-8273357965848475/2947276626';
  static String get rewardedAdUnitId =>
      isTesting ? _testRewardedId : 'ca-app-pub-8273357965848475/7165723233';
  static String get nativeAdUnitId =>
      isTesting ? _testNativeId : 'ca-app-pub-8273357965848475/6719000676';

  // Interstitial Ad
  InterstitialAd? _interstitialAd;

  void loadInterstitialAd() {
    if (!isSupported) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          print('Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          print('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (!isSupported || _interstitialAd == null) return;

    _interstitialAd!.show();
    _interstitialAd = null;
    // Load next one
    loadInterstitialAd();
  }

  // Rewarded Ad
  RewardedAd? _rewardedAd;

  void loadRewardedAd() {
    if (!isSupported) return;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          print('Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          print('Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  void showRewardedAd(Function onReward, {Function(String)? onError}) {
    if (!isSupported) {
      onError?.call('Ads are not supported on this platform');
      return;
    }

    if (_rewardedAd == null) {
      onError?.call('Ad not loaded yet. Please try again in a moment.');
      // Attempt to load ad for next time
      loadRewardedAd();
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        onReward();
      },
    );
    _rewardedAd = null;
    // Load next one
    loadRewardedAd();
  }

  // Native Ad
  NativeAd? _nativeAd;
  bool nativeAdLoaded = false;

  void loadNativeAd() {
    if (!isSupported) return;

    _nativeAd = NativeAd(
      adUnitId: nativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          nativeAdLoaded = true;
          print('Native ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          nativeAdLoaded = false;
          print('Native ad failed to load: $error');
        },
      ),
    )..load();
  }

  NativeAd? get nativeAd => _nativeAd;

  // Initialize all ads
  void initializeAds() {
    loadInterstitialAd();
    loadRewardedAd();
    loadNativeAd();
  }
}
