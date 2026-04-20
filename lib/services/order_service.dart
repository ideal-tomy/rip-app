import 'package:cloud_firestore/cloud_firestore.dart';

const String defaultEventId = 'defaultEvent';

const Map<String, int> unitPriceByItemType = {
  'tequila': 500,
  'value_pack': 3000,
  'champagne': 5500,
};

const Map<String, String> itemLabelByType = {
  'tequila': 'テキーラ',
  'value_pack': 'バリュー',
  'champagne': 'シャンパン',
};

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
  required String itemType,
  required int quantity,
  required List<String> targets,
  String? note,
}) {
  final unitPrice = unitPriceByItemType[itemType] ?? 500;
  final requiresTarget = itemType == 'tequila';
  final safeTargets = requiresTarget ? targets : <String>[];
  final totalPrice = requiresTarget
      ? unitPrice * quantity * safeTargets.length
      : unitPrice * quantity;

  return _ordersRef.add({
    'senderStore': senderStore,
    'senderName': senderName,
    'itemType': itemType,
    'itemName': itemLabelByType[itemType] ?? itemType,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'requiresTarget': requiresTarget,
    'targets': safeTargets,
    // 旧管理画面互換のため当面残す（tequila 以外は 0）
    'shotCount': requiresTarget ? quantity : 0,
    if (note != null && note.isNotEmpty) 'note': note,
    'totalPrice': totalPrice,
    'isServed': false,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// 提供済みに更新
Future<void> markAsServed(String orderId) =>
    _ordersRef.doc(orderId).update({'isServed': true});
