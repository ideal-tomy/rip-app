import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../config/event_config.dart';

const String _viewTypeTwitch = 'twitch-embed-rip-app';

void _registerTwitchViewFactory() {
  ui_web.platformViewRegistry.registerViewFactory(
    _viewTypeTwitch,
    (int id) {
      final iframe = web.HTMLIFrameElement();
      iframe.setAttribute('src', kTwitchPlayerEmbedUrl);
      iframe.setAttribute('title', 'Twitch ライブ');
      // allow に fullscreen を含める（allowfullscreen 単体は非推奨の警告が出るため）
      iframe.setAttribute('allow', 'autoplay; fullscreen; picture-in-picture; encrypted-media');
      iframe.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%';
      return iframe;
    },
  );
}

bool _factoryBound = false;

void _ensureFactory() {
  if (_factoryBound) return;
  _registerTwitchViewFactory();
  _factoryBound = true;
}

/// Web 専用: iframe で Twitch プレイヤーを表示します。
class TwitchPlayerEmbed extends StatelessWidget {
  const TwitchPlayerEmbed({super.key});

  @override
  Widget build(BuildContext context) {
    _ensureFactory();
    return const HtmlElementView(viewType: _viewTypeTwitch);
  }
}
