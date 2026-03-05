import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsService {
  final FirebaseFirestore _db;

  NotificationsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('usuarios').doc(uid).collection('notificaciones');

  Stream<QuerySnapshot<Map<String, dynamic>>> stream(String uid) {
    return _col(uid).orderBy('created_at', descending: true).limit(100).snapshots();
  }

  Future<void> markAsRead({
    required String uid,
    required String notifId,
  }) async {
    await _col(uid).doc(notifId).update({'read': true});
  }

  Future<void> markAllAsRead({required String uid}) async {
    final q = await _col(uid).where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification({
    required String uid,
    required String notifId,
  }) async {
    await _col(uid).doc(notifId).delete();
  }

  Future<void> clearAll({required String uid}) async {
    final q = await _col(uid).limit(300).get();
    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// 👇 opcional: contador de no leídas (para badge)
  Stream<int> unreadCount(String uid) {
    return _col(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
