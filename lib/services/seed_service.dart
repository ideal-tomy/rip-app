import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_service.dart';

/// デフォルトイベントとダミー注文を投入する（開発・検証用）
Future<void> seedDummyData() async {
  final firestore = FirebaseFirestore.instance;
  final eventsRef = firestore.collection('events');
  final defaultEventRef = eventsRef.doc(defaultEventId);

  await defaultEventRef.set({
    'name': '20th Anniversary',
    'status': 'active',
    'pricePerShot': 1000,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  final ordersRef = defaultEventRef.collection('orders');
  final existing = await ordersRef.limit(1).get();
  if (existing.docs.isNotEmpty) return;

  await ordersRef.add({
    'senderStore': 'エースクローバー',
    'senderName': 'タカシ',
    'targets': ['あやねぇ', 'フルヤ'],
    'shotCount': 2,
    'totalPrice': 4000,
    'isServed': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
