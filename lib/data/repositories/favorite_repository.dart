import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/favorite_restaurant.dart';
import '../models/restaurant.dart';

class FavoriteRepository {
  FavoriteRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Stream<bool> watchIsFavorite(String restaurantId) {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(false);
    }
    return _favoriteReference(
      uid,
      restaurantId,
    ).snapshots().map((snapshot) => snapshot.exists);
  }

  Stream<List<FavoriteRestaurant>> watchFavorites() {
    final uid = _requireUid();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final favorites = snapshot.docs
              .map(
                (document) =>
                    FavoriteRestaurant.fromMap(document.id, document.data()),
              )
              .toList(growable: false);
          final activeIds = await _readActiveRestaurantIds(
            favorites.map((favorite) => favorite.restaurantId),
          );
          return favorites
              .where((favorite) => activeIds.contains(favorite.restaurantId))
              .toList(growable: false);
        });
  }

  Future<Set<String>> _readActiveRestaurantIds(Iterable<String> ids) async {
    final uniqueIds = ids.toSet().toList(growable: false);
    if (uniqueIds.isEmpty) return const {};

    final activeIds = <String>{};
    for (var index = 0; index < uniqueIds.length; index += 30) {
      final end = (index + 30).clamp(0, uniqueIds.length);
      final snapshot = await _firestore
          .collection('restaurants')
          .where('status', isEqualTo: 'active')
          .where(FieldPath.documentId, whereIn: uniqueIds.sublist(index, end))
          .get();
      activeIds.addAll(snapshot.docs.map((document) => document.id));
    }
    return activeIds;
  }

  Future<bool> toggleFavorite(Restaurant restaurant) async {
    final uid = _requireUid();
    final favoriteReference = _favoriteReference(uid, restaurant.id);
    final restaurantReference = _firestore
        .collection('restaurants')
        .doc(restaurant.id);

    return _firestore.runTransaction((transaction) async {
      final restaurantSnapshot = await transaction.get(restaurantReference);
      if (!restaurantSnapshot.exists ||
          restaurantSnapshot.data()?['status'] != 'active') {
        throw const FavoriteException('這家店目前無法收藏。');
      }
      final favoriteSnapshot = await transaction.get(favoriteReference);
      if (favoriteSnapshot.exists) {
        transaction.delete(favoriteReference);
        transaction.update(restaurantReference, {
          'favoriteCount': FieldValue.increment(-1),
        });
        return false;
      }

      transaction.set(favoriteReference, {
        'addedAt': FieldValue.serverTimestamp(),
        'restaurantName': restaurant.name,
        'restaurantCoverPhotoUrl': restaurant.coverPhotoUrl,
        'restaurantCategories': restaurant.categories,
      });
      transaction.update(restaurantReference, {
        'favoriteCount': FieldValue.increment(1),
      });
      return true;
    });
  }

  Future<String> resolveFavoriteTarget(String restaurantId) async {
    final uid = _requireUid();
    final sourceReference = _firestore
        .collection('restaurants')
        .doc(restaurantId);
    final sourceFavorite = _favoriteReference(uid, restaurantId);
    return _firestore.runTransaction((transaction) async {
      final source = await transaction.get(sourceReference);
      final targetId = source.data()?['mergedIntoRestaurantId'];
      if (source.data()?['status'] != 'merged' || targetId is! String) {
        return restaurantId;
      }
      final targetReference = _firestore
          .collection('restaurants')
          .doc(targetId);
      final targetFavorite = _favoriteReference(uid, targetId);
      final snapshots = await Future.wait([
        transaction.get(sourceFavorite),
        transaction.get(targetFavorite),
        transaction.get(targetReference),
      ]);
      if (!snapshots[0].exists ||
          !snapshots[2].exists ||
          snapshots[2].data()?['status'] != 'active') {
        return targetId;
      }
      transaction.delete(sourceFavorite);
      transaction.update(sourceReference, {
        'favoriteCount': FieldValue.increment(-1),
      });
      if (!snapshots[1].exists) {
        final targetData = snapshots[2].data()!;
        transaction.set(targetFavorite, {
          'addedAt': FieldValue.serverTimestamp(),
          'restaurantName': targetData['name'],
          'restaurantCoverPhotoUrl': targetData['coverPhotoUrl'],
          'restaurantCategories': targetData['categories'],
        });
        transaction.update(targetReference, {
          'favoriteCount': FieldValue.increment(1),
        });
      }
      return targetId;
    });
  }

  DocumentReference<Map<String, dynamic>> _favoriteReference(
    String uid,
    String restaurantId,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(restaurantId);
  }

  String _requireUid() {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw const FavoriteException('請先登入後再使用收藏功能。');
    }
    return uid;
  }
}

class FavoriteException implements Exception {
  const FavoriteException(this.message);

  final String message;
}
