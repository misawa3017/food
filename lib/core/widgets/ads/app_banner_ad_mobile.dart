import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../data/providers/ad_providers.dart';
import '../../ads/ad_units.dart';

class AppBannerAd extends ConsumerWidget {
  const AppBannerAd({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adServiceProvider).isSupported) {
      return const SizedBox.shrink();
    }
    final initialization = ref.watch(adInitializationProvider);
    return initialization.maybeWhen(
      data: (canRequestAds) =>
          canRequestAds ? const _LoadedBannerAd() : const SizedBox.shrink(),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _LoadedBannerAd extends StatefulWidget {
  const _LoadedBannerAd();

  @override
  State<_LoadedBannerAd> createState() => _LoadedBannerAdState();
}

class _LoadedBannerAdState extends State<_LoadedBannerAd> {
  BannerAd? _bannerAd;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // 使用標準精簡橫幅（320x50），避免大型自適應橫幅佔用過多畫面高度
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdUnits.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() => _bannerAd = loadedAd as BannerAd);
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
