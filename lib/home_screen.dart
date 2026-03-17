import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/order_service.dart';
import 'services/message_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _adminPassword = '1234';

  bool _isAdminMode = false;
  bool _isLoading = false;
  bool _isProfileSet = false;

  int _tapCount = 0;
  Timer? _tapResetTimer;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  int _adminTabIndex = 0;
  
  String? _selectedStore;
  List<String> _selectedTargets = [];
  int _shotCount = 1;

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
    _nameController.dispose();
    _passwordController.dispose();
    _commentController.dispose();
    _tapResetTimer?.cancel();
    super.dispose();
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

  void _toggleTarget(String target) {
    setState(() {
      if (_selectedTargets.contains(target)) {
        _selectedTargets.remove(target);
      } else {
        _selectedTargets.add(target);
      }
    });
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信に失敗しました: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _onSendTequila() async {
    if (_selectedTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ターゲットを1人以上選択してください！'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('認証エラー。ページを再読み込みしてください。'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final targetsStr = _selectedTargets.join('、');
    final tequilaMessage = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.amberAccent, width: 2),
          ),
          title: const Center(
            child: Text('🥃 煽りメッセージ（任意）', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$targetsStr にテキーラ発射！',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: '空欄の場合は「〇〇にテキーラ発射！！」で表示',
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black54,
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.amberAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('送信'),
            ),
          ],
        );
      },
    );

    if (tequilaMessage == null) return;

    setState(() => _isLoading = true);

    try {
      await addOrder(
        senderStore: _selectedStore!,
        senderName: _nameController.text.trim(),
        targets: List<String>.from(_selectedTargets),
        shotCount: _shotCount,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Firestore への接続がタイムアウトしました。'
          'Firebase コンソールで Firestore を作成し、'
          'firebase deploy --only firestore を実行してください。',
        ),
      );

      final superChatText = tequilaMessage.isNotEmpty
          ? tequilaMessage
          : '$targetsStr にテキーラ発射！！';
      await addSuperChat(
        senderName: '$_selectedStore (${_nameController.text.trim()})',
        text: superChatText,
        senderStore: _selectedStore,
        senderNickname: _nameController.text.trim(),
        targets: List<String>.from(_selectedTargets),
        shotCount: _shotCount,
      );

      if (mounted) {
        setState(() {
          _selectedTargets.clear();
          _shotCount = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.local_bar, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text('テキーラ発射完了！🥃🔥', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      final shotCount = (d['shotCount'] as num?)?.toInt() ?? (d['shotCountPerTarget'] as num?)?.toInt() ?? 1;
      return {
        'id': doc.id,
        'store': storeLabel,
        'targets': List<String>.from(d['targets'] ?? []),
        'count': shotCount,
        'time': timeStr,
        'isServed': d['isServed'] as bool? ?? false,
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
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: watchMessages(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('チャットエラー: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 2));
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text('チャットが始まるとここに表示されます', style: TextStyle(color: Colors.white38, fontSize: 14)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final d = docs[index].data();
                  final senderName = d['senderName'] as String? ?? '';
                  final text = d['text'] as String? ?? '';
                  final isSuperChat = d['isSuperChat'] as bool? ?? false;
                  final senderStore = d['senderStore'] as String?;
                  final senderNickname = d['senderNickname'] as String?;
                  final targets = List<String>.from(d['targets'] ?? []);
                  final shotCount = (d['shotCount'] as num?)?.toInt();
                  return _buildChatMessage(
                    senderName: senderName,
                    text: text,
                    isSuperChat: isSuperChat,
                    senderStore: senderStore,
                    senderNickname: senderNickname,
                    targets: targets,
                    shotCount: shotCount,
                  );
                },
              );
            },
          ),
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
          decoration: BoxDecoration(color: Colors.black87),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 2),
                      SizedBox(height: 8),
                      Text('テキーラを準備中...', style: TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : Column(
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
                          Text('$_selectedStore (${_nameController.text})', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('誰に祝いのショットを飛ばす？', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _targets.map((target) {
                        final isSelected = _selectedTargets.contains(target);
                        return FilterChip(
                          label: Text(target, style: const TextStyle(fontSize: 12)),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: Colors.black54,
                          selectedColor: Colors.amberAccent,
                          side: BorderSide(color: isSelected ? Colors.amberAccent : Colors.white24),
                          selected: isSelected,
                          onSelected: (_) => _toggleTarget(target),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.amberAccent, size: 28),
                          onPressed: () {
                            if (_shotCount > 1) setState(() => _shotCount--);
                          },
                        ),
                        Text('$_shotCount 杯', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.amberAccent, size: 28),
                          onPressed: () => setState(() => _shotCount++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: _onSendTequila,
                        child: const Text('テキーラを送信！！ 🥃', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
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
    List<String>? targets,
    int? shotCount,
  }) {
    if (isSuperChat) {
      final hasAutoInfo = targets != null && targets.isNotEmpty && shotCount != null;
      String autoInfo = senderName;
      if (hasAutoInfo) {
        final storePart = senderStore?.isNotEmpty == true ? senderStore! : '';
        final nickPart = senderNickname?.isNotEmpty == true ? senderNickname! : '';
        final fromPart = storePart.isNotEmpty && nickPart.isNotEmpty
            ? '$storePart ($nickPart) から'
            : (storePart.isNotEmpty ? '$storePart から' : (nickPart.isNotEmpty ? '$nickPart から' : ''));
        autoInfo = fromPart.isNotEmpty
            ? '$fromPart ${targets!.join('、')} に ${shotCount}杯 ずつ発射！！'
            : '${targets!.join('、')} に ${shotCount}杯 ずつ発射！！';
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
        final targets = (order['targets'] as List).join(' , ');
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
                  child: Text('${order['count']}杯', style: TextStyle(color: isServed ? Colors.grey : Colors.amberAccent, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$targets 宛', style: TextStyle(color: isServed ? Colors.grey : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
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
    int grandTotal = 0;

    for (var order in orders) {
      final fullStoreName = order['store'] as String;
      final storeName = fullStoreName.split(' (')[0];

      final targetCount = (order['targets'] as List).length;
      final shotCount = order['count'] as int;
      final price = targetCount * shotCount * 1000;

      salesByStore[storeName] = (salesByStore[storeName] ?? 0) + price;
      grandTotal += price;
    }

    if (salesByStore.isEmpty) {
      return const Center(child: Text('まだ売上がありません', style: TextStyle(color: Colors.white54)));
    }

    var sortedSales = salesByStore.entries.toList()
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
                    final targets = List<String>.from(d['targets'] ?? []);
                    final shotCount = (d['shotCount'] as num?)?.toInt();
                    return _buildChatMessage(
                      senderName: senderName,
                      text: text,
                      isSuperChat: isSuperChat,
                      senderStore: senderStore,
                      senderNickname: senderNickname,
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