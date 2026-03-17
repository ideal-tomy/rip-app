import 'package:flutter/material.dart';
import 'dart:async';

class ResultScreen extends StatefulWidget {
  final String storeName;
  final List<String> targetNames; // 💡複数人受け取る
  final int shotCount;            // 💡杯数を受け取る

  const ResultScreen({Key? key, required this.storeName, required this.targetNames, required this.shotCount}) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 💡計算：ターゲットの人数 × 杯数 = 合計ショット数
    final totalShots = widget.targetNames.length * widget.shotCount;
    // 1ショット1000円として計算
    final totalPrice = totalShots * 1000;
    // 名前をカンマ区切りの文字列にする
    final targetsString = widget.targetNames.join(' と ');

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 20),
              const Text('BOOM!!', style: TextStyle(color: Colors.amberAccent, fontSize: 40, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
              const SizedBox(height: 20),
              
              Text(
                '${widget.storeName} から\n$targetsString に\nテキーラが ${widget.shotCount}杯 ずつ発射されました！',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.5),
              ),
              
              const SizedBox(height: 40),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  border: Border.all(color: Colors.amberAccent, width: 1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'お支払いは、現在ご飲食中の\n店舗スタッフに直接お渡しください。\n\n合計 $totalShotsショット\n（ご請求額：¥$totalPrice）',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              TextButton(
                onPressed: () {
                  _timer?.cancel();
                  Navigator.pop(context);
                },
                child: const Text('さらにテキーラを送り込む（手動で戻る）', style: TextStyle(color: Colors.amberAccent, fontSize: 16, decoration: TextDecoration.underline)),
              )
            ],
          ),
        ),
      ),
    );
  }
}