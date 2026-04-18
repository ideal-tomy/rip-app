/// 本番前に [kPayPayReceiveUrl] と [kTwitchChannel] を差し替えてください。
library;

const String kPayPayReceiveUrl = 'https://paypay.me/REPLACE_WITH_YOUR_LINK';

/// Twitch のログイン名（URL の twitch.tv/ の直後と同じ小文字 ID）
const String kTwitchChannel = 'tmr_tomy';

/// 本番 Firebase Hosting のホスト（embed の parent に必須）
const String kTwitchParent = 'rip-app-79c14.web.app';

/// Twitch 埋め込み URL。`parent` は配信ページのオリジンと一致させる必要があります。
/// ローカル（localhost）でも iframe が通るよう、開発用 parent を併記します。
String get kTwitchPlayerEmbedUrl {
  // muted=true: ブラウザの自動再生制限・Twitch の viewport 判定で失敗しにくい（プレイヤー内で解除可能）
  return 'https://player.twitch.tv/?channel=$kTwitchChannel'
      '&parent=$kTwitchParent'
      '&parent=localhost'
      '&parent=127.0.0.1'
      '&muted=true';
}
