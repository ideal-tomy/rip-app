import 'package:cloud_firestore/cloud_firestore.dart';

const String defaultEventId = 'defaultEvent';
const int unitPrice = 1000;

CollectionReference<Map<String, dynamic>> get _ordersRef =>
    FirebaseFirestore.instance
        .collection('events')
        .doc(defaultEventId)
        .collection('orders');

/// 注文一覧のリアルタイムストリーム（createdAt 降順）
Stream<QuerySnapshot<Map<String, dynamic>>> watchOrders() =>
    _ordersRef.orderBy('createdAt', descending: true).snapshots();

/// 注文を追加
Future<DocumentReference<Map<String, dynamic>>> addOrder({
  required String senderStore,
  required String senderName,
  required List<String> targets,
  required int shotCount,
}) {
  final totalPrice = targets.length * shotCount * unitPrice;

  return _ordersRef.add({
    'senderStore': senderStore,
    'senderName': senderName,
    'targets': targets,
    'shotCount': shotCount,
    'totalPrice': totalPrice,
    'isServed': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// 提供済みに更新
Future<void> markAsServed(String orderId) =>
    _ordersRef.doc(orderId).update({'isServed': true});
