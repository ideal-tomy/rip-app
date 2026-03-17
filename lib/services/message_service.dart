import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_service.dart';

CollectionReference<Map<String, dynamic>> get _messagesRef =>
    FirebaseFirestore.instance
        .collection('events')
        .doc(defaultEventId)
        .collection('messages');

/// メッセージ一覧のリアルタイムストリーム（createdAt 昇順＝古い順）
Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages() =>
    _messagesRef.orderBy('createdAt').snapshots();

/// 通常コメントを追加
Future<DocumentReference<Map<String, dynamic>>> addComment({
  required String senderName,
  required String text,
}) {
  return _messagesRef.add({
    'senderName': senderName,
    'text': text,
    'isSuperChat': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// スパチャ（テキーラ）メッセージを追加
Future<DocumentReference<Map<String, dynamic>>> addSuperChat({
  required String senderName,
  required String text,
  String? senderStore,
  String? senderNickname,
  List<String>? targets,
  int? shotCount,
}) {
  return _messagesRef.add({
    'senderName': senderName,
    'text': text,
    'isSuperChat': true,
    if (senderStore != null) 'senderStore': senderStore,
    if (senderNickname != null) 'senderNickname': senderNickname,
    if (targets != null) 'targets': targets,
    if (shotCount != null) 'shotCount': shotCount,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
