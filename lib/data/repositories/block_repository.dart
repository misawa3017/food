import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 被封鎖的使用者，只有封鎖者自己看得到。
class BlockedUser {
  const BlockedUser({required this.uid, required this.displayName});

  final String uid;
  final String displayName;
}

/// 使用者封鎖名單，存在 `users/{uid}/blockedUsers/{blockedUid}`。
///
/// 封鎖只影響自己看到的內容：被封鎖者的店家、照片與評論會在 App 中隱藏。
class BlockRepository {
  BlockRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Stream<List<BlockedUser>> watchBlockedUsers() {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _collection(uid)
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => BlockedUser(
                  uid: document.id,
                  displayName:
                      document.data()['displayName'] as String? ?? '共享美食使用者',
                ),
              )
              .toList(growable: false),
        );
  }

  Future<void> blockUser({
    required String blockedUid,
    required String displayName,
  }) async {
    final uid = _requireUid();
    if (blockedUid == uid) {
      throw const BlockException('不能封鎖自己。');
    }
    final name = displayName.trim();
    await _collection(uid).doc(blockedUid).set({
      'displayName': name.isEmpty
          ? '共享美食使用者'
          : name.substring(0, name.length.clamp(0, 50)),
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String blockedUid) async {
    final uid = _requireUid();
    await _collection(uid).doc(blockedUid).delete();
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('blockedUsers');
  }

  String _requireUid() {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw const BlockException('請先登入後再封鎖使用者。');
    }
    return uid;
  }
}

class BlockException implements Exception {
  const BlockException(this.message);

  final String message;
}
