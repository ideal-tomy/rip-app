import 'package:flutter/material.dart';

/// 非 Web 向け。Web では [twitch_embed_web] が使われます。
class TwitchPlayerEmbed extends StatelessWidget {
  const TwitchPlayerEmbed({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0D0D0D),
      child: Center(
        child: Text(
          'Twitch ライブは Web ブラウザをご利用ください',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }
}
