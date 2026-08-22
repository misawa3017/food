// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../ads/adsense_loader.dart';
import '../../../firebase_environment.dart';

/// 正式 Web 首頁店家清單中的 AdSense 回應式廣告。
///
/// 使用平台檢視嵌入廣告 DOM，讓 AdSense 能依當前欄寬自行決定廣告尺寸。
class WebAdSenseHomeFeedAd extends StatefulWidget {
  const WebAdSenseHomeFeedAd({super.key});

  @override
  State<WebAdSenseHomeFeedAd> createState() => _WebAdSenseHomeFeedAdState();
}

class _WebAdSenseHomeFeedAdState extends State<WebAdSenseHomeFeedAd> {
  static const _publisherId = String.fromEnvironment('ADSENSE_PUBLISHER_ID');
  static const _slotId = String.fromEnvironment('ADSENSE_HOME_FEED_SLOT');
  static var _nextViewTypeId = 0;

  late final String _viewType;

  bool get _isEnabled =>
      FirebaseEnvironment.name == 'prod' &&
      _publisherId.isNotEmpty &&
      _slotId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _viewType = 'food-adsense-home-feed-${_nextViewTypeId++}';

    if (_isEnabled) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, _createAdView);
    }
  }

  html.Element _createAdView(int viewId) {
    final container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block';
    final adElement = html.Element.tag('ins')
      ..className = 'adsbygoogle'
      ..style.display = 'block'
      ..setAttribute('data-ad-client', _publisherId)
      ..setAttribute('data-ad-slot', _slotId)
      ..setAttribute('data-ad-format', 'auto')
      ..setAttribute('data-full-width-responsive', 'true');
    container.append(adElement);

    // 廣告腳本尚未完成下載時，先將請求放入 AdSense 的佇列即可。
    unawaited(Future<void>.delayed(Duration.zero, () => _requestAd(container)));
    return container;
  }

  void _requestAd(html.Element container) {
    try {
      AdSenseLoader.load();
      final requestScript = html.ScriptElement()
        ..type = 'text/javascript'
        ..text = '(adsbygoogle = window.adsbygoogle || []).push({});';
      container.append(requestScript);
    } catch (_) {
      // AdSense 尚未核准網站或被瀏覽器阻擋時，保留版面而不影響店家清單。
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEnabled) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: HtmlElementView(viewType: _viewType)),
          Positioned(
            top: 10,
            left: 12,
            child: IgnorePointer(
              child: Text(
                '廣告',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
