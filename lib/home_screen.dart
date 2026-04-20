import 'dart:async';
import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/event_config.dart';
import 'services/order_service.dart';
import 'services/message_service.dart';
import 'widgets/twitch_embed.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _adminPassword = '1234';
  static const int _maxValueQuantity = 10;
  static const int _maxChampagneQuantity = 5;

  bool _isAdminMode = false;
  bool _isLoading = false;
  bool _isProfileSet = false;
  /// PayPay 起動後、煽り前の「支払いを完了しました」帯表示用
  bool _awaitingTequilaAfterPayment = false;

  int _tapCount = 0;
  Timer? _tapResetTimer;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  int _adminTabIndex = 0;

  final ScrollController _chatScrollController = ScrollController();
  bool _isAutoScroll = true;
  bool _skipNextScrollCheck = false;
  bool _hasReachedBottomOnce = false; // 一度でも下端までスクロール済み（初期レイアウトの誤検知防止）
  static const double _scrollThreshold = 50.0;

  String? _selectedStore;
  List<String> _selectedTargets = [];
  String _selectedItemType = 'tequila';
  int _selectedQuantity = 1;
  String _orderNote = '';

  final List<String> _stores = [
    'ロードスター', 'レラシオン', 'エースクローバー', 'トノップ',
    '店舗A', '店舗B', '店舗C', '店舗D', '店舗E'
  ];

  final List<String> _targets = [
    'れっか', 'あやねぇ', 'フルヤ', 'コウジ', 'tomy（兄）',
    'tomy（弟）', '参加者A', '参加者B', '参加者C', '参加者E'
  ];

  @override
  void dispose() {
    _chatScrollController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _commentController.dispose();
    _tapResetTimer?.cancel();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_skipNextScrollCheck) return false;
    // 初期スクロール完了前は無視（マウスホイール・トラックパッド・タッチすべてに対応）
    if (!_hasReachedBottomOnce) return false;

    final pos = notification.metrics;
    final atBottom = pos.pixels >= pos.maxScrollExtent - _scrollThreshold;
    if (mounted) setState(() => _isAutoScroll = atBottom);
    return false;
  }

  void _scrollToBottomAndResume() {
    if (!_chatScrollController.hasClients) return;
    setState(() => _isAutoScroll = true);
    _skipNextScrollCheck = true;
    _chatScrollController.animateTo(
      _chatScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (mounted) {
        _skipNextScrollCheck = false;
        _hasReachedBottomOnce = true;
      }
    });
  }

  void _onTitleTap() {
    _tapResetTimer?.cancel();
    _tapCount++;
    if (_tapCount >= 5) {
      _tapCount = 0;
      _showPasswordDialog();
    } else {
      _tapResetTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _tapCount = 0);
      });
    }
  }

  void _showPasswordDialog() {
    _passwordController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amberAccent, width: 2),
        ),
        title: const Center(
          child: Text('管理者パスワード', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
        ),
        content: TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'パスワードを入力',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black54,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.amberAccent),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (_passwordController.text == _adminPassword) {
                Navigator.pop(context);
                setState(() {
                  _isAdminMode = true;
                  _adminTabIndex = 0;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('パスワードが違います'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // 💡【運用カバー】登録直後に、スタッフに画面を見せるよう指示する
  void _startEvent() {
    if (_selectedStore == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('店舗を選択し、ニックネームを入力してください！'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    
    setState(() {
      _isProfileSet = true;
    });

    // 💡スタッフへの提示を促すダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false, // 外側をタップしても消えないようにする
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amberAccent, width: 2),
        ),
        title: const Center(child: Text('🎉 登録完了', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'お会計と紐付けるため、最初の1杯を撃つ前に...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            const Text(
              'お近くのスタッフに\nこの画面を見せてください！',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
              child: Text(
                _nameController.text.trim(),
                style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text('確認OK（テキーラ画面へ）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }

  String _itemLabel(String itemType) => itemLabelByType[itemType] ?? itemType;
  int _unitPrice(String itemType) => unitPriceByItemType[itemType] ?? 500;
  bool _requiresTarget(String itemType) => itemType == 'tequila';
  int _maxQuantity(String itemType) {
    switch (itemType) {
      case 'value_pack':
        return _maxValueQuantity;
      case 'champagne':
        return _maxChampagneQuantity;
      default:
        return 1;
    }
  }

  int _estimatePrice({
    required String itemType,
    required int quantity,
    required List<String> targets,
  }) {
    final unit = _unitPrice(itemType);
    return _requiresTarget(itemType)
        ? unit * quantity * targets.length
        : unit * quantity;
  }

  Widget _buildItemToggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      child: Material(
        color: selected ? Colors.amberAccent : Colors.black54,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _targetSummary(List<String> targets) {
    if (targets.isEmpty) return '未選択';
    if (targets.length <= 3) return targets.join('、');
    return '${targets.take(2).join('、')} ほか${targets.length}人';
  }

  Future<bool> _showLaunchOrderSheet() async {
    var tempItemType = _selectedItemType;
    var tempQuantity = _selectedQuantity;
    var tempTargets = List<String>.from(_selectedTargets);
    var tempNote = _orderNote;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      // 上部のタップ不感回避: シートのドラッグ領域が
      // 商品切替/先頭チップを奪うケースがあるため明示的に無効化
      enableDrag: false,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final requiresTarget = _requiresTarget(tempItemType);
            final maxQty = _maxQuantity(tempItemType);
            if (!requiresTarget) {
              tempTargets = <String>[];
            }
            if (tempQuantity > maxQty) {
              tempQuantity = maxQty;
            }
            final est = _estimatePrice(
              itemType: tempItemType,
              quantity: tempQuantity,
              targets: tempTargets,
            );

            final viewInsetsBottom = MediaQuery.viewInsetsOf(ctx).bottom;
            final screenH = MediaQuery.sizeOf(ctx).height;
            final available = screenH - viewInsetsBottom - 16;
            final sheetH = min(
              max(screenH * 0.82, 360.0),
              max(280.0, available),
            );

            const double targetBlockHeight = 220;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: viewInsetsBottom + 12),
                child: SizedBox(
                  height: sheetH,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 10),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '発射内容を選択',
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildItemToggleButton(
                                label: 'テキーラ',
                                selected: tempItemType == 'tequila',
                                onTap: () => setModalState(() => tempItemType = 'tequila'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildItemToggleButton(
                                label: 'バリュー',
                                selected: tempItemType == 'value_pack',
                                onTap: () => setModalState(() => tempItemType = 'value_pack'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildItemToggleButton(
                                label: 'シャンパン',
                                selected: tempItemType == 'champagne',
                                onTap: () => setModalState(() => tempItemType = 'champagne'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: targetBlockHeight,
                                child: requiresTarget
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('飛ばす相手', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                            const SizedBox(height: 6),
                                            Expanded(
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.white24),
                                                ),
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.people_alt_outlined, color: Colors.amberAccent, size: 18),
                                                          const SizedBox(width: 6),
                                                          Expanded(
                                                            child: Text(
                                                              _targetSummary(tempTargets),
                                                              style: TextStyle(
                                                                color: tempTargets.isEmpty ? Colors.white38 : Colors.white,
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              setModalState(() {
                                                                tempTargets.clear();
                                                              });
                                                            },
                                                            child: const Text('全解除', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Wrap(
                                                        spacing: 6,
                                                        runSpacing: 6,
                                                        children: _targets.map((name) {
                                                          final selected = tempTargets.contains(name);
                                                          return FilterChip(
                                                            label: Text(name, style: const TextStyle(fontSize: 12)),
                                                            selected: selected,
                                                            onSelected: (_) {
                                                              setModalState(() {
                                                                if (selected) {
                                                                  tempTargets.remove(name);
                                                                } else {
                                                                  tempTargets.add(name);
                                                                }
                                                              });
                                                            },
                                                            selectedColor: Colors.amberAccent,
                                                            backgroundColor: Colors.black87,
                                                            labelStyle: TextStyle(
                                                              color: selected ? Colors.black87 : Colors.white,
                                                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                                            ),
                                                            side: BorderSide(color: selected ? Colors.amberAccent : Colors.white24),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: Text(
                                            'この商品は相手指定なしで注文します。指定したい場合はコメントに記入してください。',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.white54.withValues(alpha: 0.9), fontSize: 13, height: 1.45),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 12),
                              if (maxQty > 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.amberAccent, size: 28),
                                        onPressed: tempQuantity > 1
                                            ? () => setModalState(() => tempQuantity--)
                                            : null,
                                      ),
                                      Text(
                                        '$tempQuantity 個',
                                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.amberAccent, size: 28),
                                        onPressed: tempQuantity < maxQty
                                            ? () => setModalState(() => tempQuantity++)
                                            : null,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('数量は 1 固定です', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                                ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  maxLines: 2,
                                  onChanged: (v) => tempNote = v.trim(),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'コメント（任意）',
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor: Colors.black54,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.amberAccent),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '合計金額: ¥${est.toString()}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              if (requiresTarget && tempTargets.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('テキーラは相手を1人以上選択してください'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(ctx, true);
                            },
                            child: const Text('この内容で進む', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('閉じる'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _selectedItemType = tempItemType;
        _selectedQuantity = tempQuantity;
        _selectedTargets = List<String>.from(tempTargets);
        _orderNote = tempNote;
      });
      return true;
    }
    return false;
  }

  void _onSendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final senderName = '$_selectedStore (${_nameController.text.trim()})';
    if (_selectedStore == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に店舗とニックネームを設定してください'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      await addComment(senderName: senderName, text: text);
      _commentController.clear();
      if (mounted) _scrollToBottomAndResume();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信に失敗しました: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _onSendTequila() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('認証エラー。ページを再読み込みしてください。'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_selectedStore == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に店舗とニックネームを設定してください'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final confirmedOrder = await _showLaunchOrderSheet();
    if (!confirmedOrder) return;

    final goPay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.amberAccent, width: 2),
          ),
          title: const Center(
            child: Text('決済確認', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          ),
          content: const Text(
            '決済画面へ進みます。支払いが完了したらアプリに戻ってください',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('支払う', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (goPay != true) return;

    final uri = Uri.parse(kPayPayReceiveUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PayPay リンクを開けませんでした'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PayPay の起動に失敗: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _awaitingTequilaAfterPayment = true);
    }
  }

  Future<String?> _showPostPaymentCommentDialog(String initialValue) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.amberAccent, width: 2),
          ),
          title: const Center(
            child: Text('コメント（任意）', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '任意でメッセージを入力',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black54,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.amberAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black87),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('発射を確定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _onTequilaPaymentCompleteTapped() async {
    if (_isLoading) return;
    final comment = await _showPostPaymentCommentDialog(_orderNote);
    if (comment == null) return;
    setState(() => _isLoading = true);
    final itemType = _selectedItemType;
    final itemLabel = _itemLabel(itemType);
    final targets = _requiresTarget(itemType)
        ? List<String>.from(_selectedTargets)
        : <String>[];
    final autoMessage = _requiresTarget(itemType)
        ? '$itemLabelを ${targets.join('、')} に${_selectedQuantity}回発射！！'
        : '$itemLabel を${_selectedQuantity}個発射！！';
    final message = comment.isNotEmpty ? '$autoMessage\n$comment' : autoMessage;
    try {
      await addOrder(
        senderStore: _selectedStore!,
        senderName: _nameController.text.trim(),
        itemType: itemType,
        quantity: _selectedQuantity,
        targets: targets,
        note: comment,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Firestore への接続がタイムアウトしました。'
          'Firebase コンソールで Firestore を作成し、'
          'firebase deploy --only firestore を実行してください。',
        ),
      );

      await addSuperChat(
        senderName: '$_selectedStore (${_nameController.text.trim()})',
        text: message,
        senderStore: _selectedStore,
        senderNickname: _nameController.text.trim(),
        itemType: itemType,
        itemName: itemLabel,
        quantity: _selectedQuantity,
        targets: targets,
        shotCount: _requiresTarget(itemType) ? _selectedQuantity : 0,
      );

      if (mounted) {
        setState(() {
          _selectedTargets.clear();
          _selectedQuantity = 1;
          _orderNote = '';
          _selectedItemType = 'tequila';
          _awaitingTequilaAfterPayment = false;
        });
        _scrollToBottomAndResume();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.local_bar, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text('発射完了！🥃🔥', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.amber.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信に失敗しました: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPaymentCompleteBar() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PayPay で支払いを終えたら、下のボタンで発射を確定してください',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _onTequilaPaymentCompleteTapped,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('支払いを完了しました', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _markAsServed(String orderId) {
    markAsServed(orderId);
  }

  List<Map<String, dynamic>> _mapSnapshotToOrders(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final d = doc.data();
      final senderStore = d['senderStore'] as String? ?? '';
      final senderName = d['senderName'] as String? ?? '';
      final storeLabel = (d['senderLabel'] as String?) ?? '$senderStore ($senderName)';
      final createdAt = d['createdAt'] as Timestamp?;
      final timeStr = createdAt != null
          ? '${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
          : '--:--';
      final itemType = d['itemType'] as String? ?? 'tequila';
      final quantity = (d['quantity'] as num?)?.toInt()
          ?? (d['shotCount'] as num?)?.toInt()
          ?? (d['shotCountPerTarget'] as num?)?.toInt()
          ?? 1;
      final unitPrice = (d['unitPrice'] as num?)?.toInt()
          ?? unitPriceByItemType[itemType]
          ?? 1000;
      final totalPrice = (d['totalPrice'] as num?)?.toInt()
          ?? (itemType == 'tequila'
              ? unitPrice * quantity * List<String>.from(d['targets'] ?? []).length
              : unitPrice * quantity);
      return {
        'id': doc.id,
        'store': storeLabel,
        'itemType': itemType,
        'itemName': d['itemName'] as String? ?? _itemLabel(itemType),
        'targets': List<String>.from(d['targets'] ?? []),
        'count': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        'time': timeStr,
        'isServed': d['isServed'] as bool? ?? false,
        'status': d['status'] as String?,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: GestureDetector(
          onTap: _isAdminMode ? null : _onTitleTap,
          child: Text(
            _isAdminMode ? '👑 STAFF ADMIN' : '🥂 20th Anniversary',
            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        leading: _isAdminMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.amberAccent),
                onPressed: () => setState(() {
                  _isAdminMode = false;
                  _adminTabIndex = 0;
                }),
              )
            : null,
      ),
      body: _isAdminMode
          ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: watchOrders(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('エラー: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                }
                final orders = _mapSnapshotToOrders(snapshot.data!);
                return Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _adminTabIndex == 0
                          ? _buildAdminOrdersView(orders)
                          : _buildAdminSalesView(orders),
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildAdminChatPanel(),
                    ),
                  ],
                );
              },
            )
          : (_isProfileSet ? _buildOrderView() : _buildProfileSetupView()),
          
      bottomNavigationBar: _isAdminMode 
          ? BottomNavigationBar(
              backgroundColor: Colors.black,
              selectedItemColor: Colors.amberAccent,
              unselectedItemColor: Colors.white54,
              currentIndex: _adminTabIndex,
              onTap: (index) => setState(() => _adminTabIndex = index),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '受注リスト'),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '売上集計'),
              ],
            )
          : null,
    );
  }

  Widget _buildProfileSetupView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_bar, color: Colors.amberAccent, size: 80),
            const SizedBox(height: 20),
            const Text('WELCOME TO EVENT', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 10),
            const Text('最初に、あなたの居る店舗と\nニックネームを教えてください！', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
            const SizedBox(height: 40),

            _buildDropdown(
              hint: '現在いる店舗を選択',
              icon: Icons.storefront,
              value: _selectedStore,
              items: _stores,
              onChanged: (val) => setState(() => _selectedStore = val),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person, color: Colors.amberAccent),
                hintText: 'ニックネームを入力',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black54,
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amberAccent), borderRadius: BorderRadius.circular(15)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 50),

            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.amberAccent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _startEvent,
                child: const Text('イベントに参加する！', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderView() {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: const Color(0xFF0D0D0D),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: TwitchPlayerEmbed(),
              ),
            ),
            if (_awaitingTequilaAfterPayment) _buildPaymentCompleteBar(),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: watchMessages(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];

                    if (_isAutoScroll && snapshot.hasData && docs.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_chatScrollController.hasClients && mounted) {
                          _skipNextScrollCheck = true;
                          _chatScrollController
                              .animateTo(
                            _chatScrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          )
                              .then((_) {
                            if (mounted) {
                              _skipNextScrollCheck = false;
                              _hasReachedBottomOnce = true;
                            }
                          });
                        }
                      });
                    }

                    return SingleChildScrollView(
                      controller: _chatScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (snapshot.hasError)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'チャットエラー: ${snapshot.error}',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            )
                          else if (!snapshot.hasData)
                            const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 2)),
                            )
                          else if (docs.isEmpty)
                            const SizedBox(
                              height: 160,
                              child: Center(
                                child: Text(
                                  'チャットが始まるとここに表示されます',
                                  style: TextStyle(color: Colors.white38, fontSize: 14),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final d = docs[index].data();
                                final senderName = d['senderName'] as String? ?? '';
                                final text = d['text'] as String? ?? '';
                                final isSuperChat = d['isSuperChat'] as bool? ?? false;
                                final senderStore = d['senderStore'] as String?;
                                final senderNickname = d['senderNickname'] as String?;
                                final itemName = d['itemName'] as String?;
                                final quantity = (d['quantity'] as num?)?.toInt();
                                final targets = List<String>.from(d['targets'] ?? []);
                                final shotCount = (d['shotCount'] as num?)?.toInt();
                                return _buildChatMessage(
                                  senderName: senderName,
                                  text: text,
                                  isSuperChat: isSuperChat,
                                  senderStore: senderStore,
                                  senderNickname: senderNickname,
                                  itemName: itemName,
                                  quantity: quantity,
                                  targets: targets,
                                  shotCount: shotCount,
                                );
                              },
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'コメント...',
                                      hintStyle: const TextStyle(color: Colors.white38),
                                      filled: true,
                                      fillColor: Colors.black54,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(color: Colors.amberAccent),
                                      ),
                                    ),
                                    onSubmitted: (_) => _onSendComment(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.send, color: Colors.amberAccent, size: 28),
                                  onPressed: _onSendComment,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(color: Colors.black87),
                            child: _isLoading
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 2),
                                        SizedBox(height: 8),
                                        Text(
                                          'テキーラを準備中...',
                                          style: TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.person, color: Colors.amberAccent, size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$_selectedStore (${_nameController.text})',
                                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 56,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amberAccent,
                                            foregroundColor: Colors.black87,
                                            disabledBackgroundColor: Colors.grey[700],
                                            disabledForegroundColor: Colors.white30,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                          ),
                                          onPressed: (_isLoading || _awaitingTequilaAfterPayment) ? null : _onSendTequila,
                                          child: Text(_awaitingTequilaAfterPayment ? '支払い確認を完了してください' : '発射！！ 🥃',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          SizedBox(height: bottomInset > 0 ? bottomInset : 8),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        if (!_isAutoScroll)
          Positioned(
            bottom: 12 + bottomInset,
            right: 12,
            child: Material(
              color: Colors.amberAccent.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              elevation: 4,
              child: InkWell(
                onTap: _scrollToBottomAndResume,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⬇', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text('最新のコメント', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatMessage({
    required String senderName,
    required String text,
    required bool isSuperChat,
    String? senderStore,
    String? senderNickname,
    String? itemName,
    int? quantity,
    List<String>? targets,
    int? shotCount,
  }) {
    if (isSuperChat) {
      final hasAutoInfo = itemName != null || (targets != null && targets.isNotEmpty && shotCount != null);
      String autoInfo = senderName;
      if (hasAutoInfo) {
        final q = quantity ?? shotCount ?? 1;
        final item = itemName ?? 'テキーラ';
        final storePart = senderStore?.isNotEmpty == true ? senderStore! : '';
        final nickPart = senderNickname?.isNotEmpty == true ? senderNickname! : '';
        final fromPart = storePart.isNotEmpty && nickPart.isNotEmpty
            ? '$storePart ($nickPart) から'
            : (storePart.isNotEmpty ? '$storePart から' : (nickPart.isNotEmpty ? '$nickPart から' : ''));
        final targetStr = (targets != null && targets.isNotEmpty)
            ? '${targets.join('、')} に '
            : '';
        autoInfo = fromPart.isNotEmpty
            ? '$fromPart $targetStr$item を${q}個発射！！'
            : '$targetStr$item を${q}個発射！！';
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD4AF37), Color(0xFFB8860B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🥃', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    autoInfo,
                    style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          children: [
            TextSpan(text: '$senderName: ', style: TextStyle(color: Colors.amberAccent.shade200, fontWeight: FontWeight.w600)),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminOrdersView(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text('まだ注文はありません', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isServed = order['isServed'] as bool;
        final orderStatus = order['status'] as String?;
        final isPending = orderStatus == 'pending';
        final itemName = order['itemName'] as String? ?? 'ドリンク';
        final quantity = order['count'] as int? ?? 1;
        final targets = List<String>.from(order['targets'] ?? []);
        final targetText = targets.isEmpty ? '相手指定なし' : '${targets.join(' , ')} 宛';
        final orderId = order['id'] as String;

        return Card(
          color: isServed ? Colors.grey[900] : Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: isServed ? Colors.transparent : Colors.amberAccent, width: 1.5),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isServed ? Colors.grey[800] : Colors.amberAccent.withOpacity(0.2),
                  radius: 24,
                  child: Text('${quantity}個', style: TextStyle(color: isServed ? Colors.grey : Colors.amberAccent, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$itemName × $quantity',
                              style: TextStyle(
                                color: isServed ? Colors.grey : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amberAccent, width: 1),
                              ),
                              child: const Text(
                                '確認中',
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(targetText, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('送り主: ${order['store']} (${order['time']})', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isServed ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isServed ? Colors.green[800] : Colors.amberAccent,
                    size: 40,
                  ),
                  onPressed: isServed ? null : () => _markAsServed(orderId),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminSalesView(List<Map<String, dynamic>> orders) {
    Map<String, int> salesByStore = {};
    Map<String, int> salesByItem = {};
    Map<String, int> quantityByItem = {};
    int grandTotal = 0;

    for (var order in orders) {
      final fullStoreName = order['store'] as String;
      final storeName = fullStoreName.split(' (')[0];
      final itemName = order['itemName'] as String? ?? 'ドリンク';
      final quantity = order['count'] as int? ?? 1;
      final price = order['totalPrice'] as int? ?? 0;

      salesByStore[storeName] = (salesByStore[storeName] ?? 0) + price;
      salesByItem[itemName] = (salesByItem[itemName] ?? 0) + price;
      quantityByItem[itemName] = (quantityByItem[itemName] ?? 0) + quantity;
      grandTotal += price;
    }

    if (salesByStore.isEmpty) {
      return const Center(child: Text('まだ売上がありません', style: TextStyle(color: Colors.white54)));
    }

    var sortedSales = salesByStore.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var sortedItems = salesByItem.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Colors.amberAccent.withOpacity(0.1),
          child: Column(
            children: [
              const Text('遠隔テキーラ 総売上', style: TextStyle(color: Colors.amberAccent, fontSize: 16)),
              const SizedBox(height: 5),
              Text('¥ ${grandTotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', 
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedItems.map((entry) {
                final item = entry.key;
                final amount = entry.value;
                final qty = quantityByItem[item] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text('$item（$qty個）', style: const TextStyle(color: Colors.white70))),
                      Text(
                        '¥ ${amount.toString().replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (Match m) => '${m[1]},')}',
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('各店舗の回収額（売上）', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sortedSales.length,
            itemBuilder: (context, index) {
              final storeName = sortedSales[index].key;
              final amount = sortedSales[index].value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amberAccent,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                title: Text(storeName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                trailing: Text('¥ ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', 
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdminChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.amberAccent.withOpacity(0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '💬 リアルタイムチャット（閲覧専用）',
              style: TextStyle(color: Colors.amberAccent.shade200, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: watchMessages(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 11)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 2));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('チャットが始まるとここに表示されます', style: TextStyle(color: Colors.white38, fontSize: 12)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final senderName = d['senderName'] as String? ?? '';
                    final text = d['text'] as String? ?? '';
                    final isSuperChat = d['isSuperChat'] as bool? ?? false;
                    final senderStore = d['senderStore'] as String?;
                    final senderNickname = d['senderNickname'] as String?;
                    final itemName = d['itemName'] as String?;
                    final quantity = (d['quantity'] as num?)?.toInt();
                    final targets = List<String>.from(d['targets'] ?? []);
                    final shotCount = (d['shotCount'] as num?)?.toInt();
                    return _buildChatMessage(
                      senderName: senderName,
                      text: text,
                      isSuperChat: isSuperChat,
                      senderStore: senderStore,
                      senderNickname: senderNickname,
                      itemName: itemName,
                      quantity: quantity,
                      targets: targets,
                      shotCount: shotCount,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({required String hint, required IconData icon, required String? value, required List<String> items, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.amberAccent),
        filled: true,
        fillColor: Colors.black54,
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amberAccent), borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(15)),
      ),
      dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.white, fontSize: 16),
      hint: Text(hint, style: const TextStyle(color: Colors.white54)),
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}