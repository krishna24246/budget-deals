import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  late final AdService _adService;

  @override
  void initState() {
    super.initState();
    _adService = AdService();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.isSupported) return const SizedBox.shrink();

    if (_adService.nativeAdLoaded && _adService.nativeAd != null) {
      return Container(height: 100, child: AdWidget(ad: _adService.nativeAd!));
    } else {
      return const SizedBox.shrink();
    }
  }
}
