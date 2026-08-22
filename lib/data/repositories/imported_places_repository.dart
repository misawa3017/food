import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/services/firebase_emulator_service.dart';
import '../models/imported_place.dart';

class ImportedPlacesRepository {
  ImportedPlacesRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions firebaseFunctions,
  }) : _firestore = firestore,
       _firebaseFunctions = firebaseFunctions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _firebaseFunctions;

  Stream<List<ImportedPlace>> watchImportedPlaces(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('importedPlaces')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    ImportedPlace.fromMap(document.id, document.data()),
              )
              .toList(growable: false),
        );
  }

  Future<List<ImportedPlaceMatch>> preview(
    List<ImportedPlaceSource> places,
  ) async {
    try {
      final result = await _call('previewImportedPlaces', {
        'places': places.map((place) => place.toMap()).toList(growable: false),
      });
      final rawResults = result['results'];
      if (rawResults is! List) {
        throw const ImportedPlacesException('店家比對結果格式不正確。');
      }
      return rawResults
          .whereType<Map>()
          .map(
            (item) =>
                ImportedPlaceMatch.fromMap(Map<Object?, Object?>.from(item)),
          )
          .toList(growable: false);
    } on FirebaseFunctionsException catch (error) {
      throw ImportedPlacesException(error.message ?? '店家比對失敗，請稍後再試。');
    }
  }

  Future<int> save(
    List<({ImportedPlaceSource source, ImportedPlaceCandidate candidate})>
    places,
  ) async {
    try {
      final result = await _call('saveImportedPlaces', {
        'places': places
            .map(
              (place) => {
                'source': place.source.toMap(),
                'candidate': place.candidate.toMap(),
              },
            )
            .toList(growable: false),
      });
      final savedCount = result['savedCount'];
      if (savedCount is! num) {
        throw const ImportedPlacesException('匯入結果格式不正確。');
      }
      return savedCount.toInt();
    } on FirebaseFunctionsException catch (error) {
      throw ImportedPlacesException(error.message ?? '收藏匯入失敗，請稍後再試。');
    }
  }

  Future<int> clear() async {
    try {
      final result = await _call('clearImportedPlaces', const {});
      final deletedCount = result['deletedCount'];
      if (deletedCount is! num) {
        throw const ImportedPlacesException('清除結果格式不正確。');
      }
      return deletedCount.toInt();
    } on FirebaseFunctionsException catch (error) {
      throw ImportedPlacesException(error.message ?? '清除匯入資料失敗，請稍後再試。');
    }
  }

  Future<int> importOriginalPlaces(List<ImportedPlaceSource> places) async {
    try {
      final result = await _call('importOriginalPlaces', {
        'places': places.map((place) => place.toMap()).toList(growable: false),
      });
      final savedCount = result['savedCount'];
      if (savedCount is! num) {
        throw const ImportedPlacesException('匯入結果格式不正確。');
      }
      return savedCount.toInt();
    } on FirebaseFunctionsException catch (error) {
      throw ImportedPlacesException(error.message ?? '匯入收藏失敗，請稍後再試。');
    }
  }

  Future<Map<Object?, Object?>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final callable = _firebaseFunctions.httpsCallable(
      name,
      options: HttpsCallableOptions(
        limitedUseAppCheckToken: !FirebaseEmulatorService.enabled,
      ),
    );
    final result = await callable.call<Map<Object?, Object?>>(data);
    return result.data;
  }
}

class ImportedPlacesException implements Exception {
  const ImportedPlacesException(this.message);

  final String message;
}
