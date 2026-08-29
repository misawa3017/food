import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as image_library;
import 'package:image_picker/image_picker.dart';

import '../../core/services/firebase_emulator_service.dart';
import '../models/contribution_models.dart';

class ContributionRepository {
  ContributionRepository({
    required FirebaseFunctions firebaseFunctions,
    required FirebaseStorage firebaseStorage,
  }) : _firebaseFunctions = firebaseFunctions,
       _firebaseStorage = firebaseStorage;

  final FirebaseFunctions _firebaseFunctions;
  final FirebaseStorage _firebaseStorage;
  final Random _random = Random.secure();

  Future<RestaurantSubmissionResult> submitRestaurant(
    RestaurantContributionDraft draft, {
    required bool duplicateAcknowledged,
    required void Function(double progress) onProgress,
    String? idempotencyKey,
  }) async {
    final requestKey = idempotencyKey ?? _newIdempotencyKey();
    try {
      final requestData = <String, dynamic>{
        'name': draft.name,
        'address': draft.address,
        'categories': draft.categories,
        'recommendedDishes': draft.recommendedDishes,
        'amenities': draft.amenities,
        'duplicateAcknowledged': duplicateAcknowledged,
        'idempotencyKey': requestKey,
      };
      if (draft.googleMapsUrl != null) {
        requestData['googleMapsUrl'] = draft.googleMapsUrl;
      }
      final location = draft.location;
      if (location != null) {
        requestData['latitude'] = location.latitude;
        requestData['longitude'] = location.longitude;
      }
      final createResult = await _call('createRestaurant', requestData);
      final restaurantId = createResult['restaurantId'] as String?;
      if (restaurantId == null || restaurantId.isEmpty) {
        throw const ContributionException('新增店家失敗，請稍後再試。');
      }
      onProgress(draft.photos.isEmpty ? 1 : 0.1);
      var photoUploadFailed = false;
      if (draft.photos.isNotEmpty) {
        try {
          await _uploadPhotos(
            restaurantId,
            draft.photos,
            requestKey: _newIdempotencyKey(),
            onProgress: onProgress,
          );
        } on FirebaseFunctionsException {
          photoUploadFailed = true;
        } on FirebaseException {
          photoUploadFailed = true;
        } on ContributionException {
          photoUploadFailed = true;
        }
      }
      return RestaurantSubmissionResult(
        restaurantId: restaurantId,
        photoUploadFailed: photoUploadFailed,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, requestKey);
    } on FirebaseException catch (error) {
      throw ContributionException(error.message ?? '照片上傳失敗，請稍後再試。');
    }
  }

  Future<void> addPhotos(
    String restaurantId,
    List<XFile> photos, {
    required void Function(double progress) onProgress,
  }) async {
    try {
      await _uploadPhotos(
        restaurantId,
        photos,
        requestKey: _newIdempotencyKey(),
        onProgress: onProgress,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    } on FirebaseException catch (error) {
      throw ContributionException(error.message ?? '照片上傳失敗，請稍後再試。');
    }
  }

  Future<void> updateRestaurantLocation({
    required String restaurantId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _call('updateRestaurantLocation', {
        'restaurantId': restaurantId,
        'latitude': latitude,
        'longitude': longitude,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> setRestaurantCoverPhoto({
    required String restaurantId,
    required String photoId,
  }) async {
    try {
      await _call('setRestaurantCoverPhoto', {
        'restaurantId': restaurantId,
        'photoId': photoId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> removeRestaurantPhoto({
    required String restaurantId,
    required String photoId,
  }) async {
    try {
      await _call('removeRestaurantPhoto', {
        'restaurantId': restaurantId,
        'photoId': photoId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> submitDuplicateRestaurant({
    required String sourceRestaurantId,
    required String targetRestaurantId,
    required String reason,
  }) async {
    try {
      await _call('submitDuplicateRestaurant', {
        'sourceRestaurantId': sourceRestaurantId,
        'targetRestaurantId': targetRestaurantId,
        'reason': reason,
        'idempotencyKey': _newIdempotencyKey(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> submitReview({
    required String restaurantId,
    required int rating,
    required String text,
  }) async {
    await _callContribution('submitReview', {
      'restaurantId': restaurantId,
      'rating': rating,
      'text': text,
      'idempotencyKey': _newIdempotencyKey(),
    });
  }

  Future<void> deleteReview(String restaurantId) async {
    await _callContribution('deleteReview', {
      'restaurantId': restaurantId,
      'idempotencyKey': _newIdempotencyKey(),
    });
  }

  Future<void> submitRestaurantEdit({
    required String restaurantId,
    required Map<String, Object?> changes,
    required String reason,
  }) async {
    await _callContribution('submitRestaurantEdit', {
      'restaurantId': restaurantId,
      'changes': changes,
      'reason': reason,
      'idempotencyKey': _newIdempotencyKey(),
    });
  }

  Future<void> submitReport({
    required String targetType,
    required String restaurantId,
    String? contentId,
    required String reason,
  }) async {
    await _callContribution('submitReport', {
      'targetType': targetType,
      'restaurantId': restaurantId,
      'contentId': contentId,
      'reason': reason,
      'idempotencyKey': _newIdempotencyKey(),
    });
  }

  Future<void> reviewRequest(
    String functionName,
    String requestId,
    String decision,
  ) async {
    await _callContribution(functionName, {
      'requestId': requestId,
      'decision': decision,
    });
  }

  Future<void> mergeRestaurants(String requestId) async {
    await _callContribution('mergeRestaurants', {'requestId': requestId});
  }

  Future<Map<String, int>> getContributionLimits() async {
    try {
      final result = await _call('getRestaurantContributionLimit', const {});
      final restaurantValue = result['restaurantDailyLimit'];
      final photoValue = result['photoDailyLimit'];
      if (!_isPositiveInteger(restaurantValue) ||
          !_isPositiveInteger(photoValue)) {
        throw const ContributionException('投稿上限資料格式錯誤。');
      }
      return {
        'restaurantDailyLimit': (restaurantValue as num).toInt(),
        'photoDailyLimit': (photoValue as num).toInt(),
      };
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> updateContributionLimits({
    required int restaurantDailyLimit,
    required int photoDailyLimit,
  }) async {
    try {
      await _call('updateRestaurantContributionLimit', {
        'restaurantDailyLimit': restaurantDailyLimit,
        'photoDailyLimit': photoDailyLimit,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<int> getRestaurantDailyLimit() async {
    try {
      final result = await _call('getRestaurantContributionLimit', const {});
      final value = result['restaurantDailyLimit'];
      if (value is! num || value < 1 || value != value.roundToDouble()) {
        throw const ContributionException('管理設定的每日新增店家上限無效。');
      }
      return value.toInt();
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  bool _isPositiveInteger(Object? value) {
    return value is num && value >= 1 && value == value.roundToDouble();
  }

  Future<void> updateRestaurantDailyLimit(int restaurantDailyLimit) async {
    try {
      await _call('updateRestaurantContributionLimit', {
        'restaurantDailyLimit': restaurantDailyLimit,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> adminUpdateRestaurant({
    required String restaurantId,
    required Map<String, Object?> changes,
  }) async {
    try {
      await _call('adminUpdateRestaurant', {
        'restaurantId': restaurantId,
        'changes': changes,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> adminRemoveRestaurant(String restaurantId) async {
    try {
      await _call('adminRemoveRestaurant', {'restaurantId': restaurantId});
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> claimRestaurantRecommender(String restaurantId) async {
    try {
      await _call('claimRestaurantRecommender', {'restaurantId': restaurantId});
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<int> claimImportedRestaurantRecommenders() async {
    try {
      final result = await _call(
        'claimImportedRestaurantRecommenders',
        const {},
      );
      final claimedCount = result['claimedCount'];
      if (claimedCount is! num || claimedCount < 0) {
        throw const ContributionException('認領結果格式不正確。');
      }
      return claimedCount.toInt();
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> _callContribution(
    String functionName,
    Map<String, Object?> data,
  ) async {
    try {
      await _call(functionName, data);
    } on FirebaseFunctionsException catch (error) {
      throw _contributionException(error, _newIdempotencyKey());
    }
  }

  Future<void> _uploadPhotos(
    String restaurantId,
    List<XFile> photos, {
    required String requestKey,
    required void Function(double progress) onProgress,
  }) async {
    final reservationResult = await _callWithRetry('requestPhotoUpload', {
      'restaurantId': restaurantId,
      'count': photos.length,
      'idempotencyKey': requestKey,
    });
    final rawReservations = reservationResult['reservations'];
    if (rawReservations is! List || rawReservations.length != photos.length) {
      throw const ContributionException('無法建立照片上傳預約。');
    }

    for (var index = 0; index < photos.length; index += 1) {
      final reservation = Map<Object?, Object?>.from(
        rawReservations[index] as Map,
      );
      final reservationId = reservation['reservationId'] as String?;
      final storagePath = reservation['storagePath'] as String?;
      if (reservationId == null || storagePath == null) {
        throw const ContributionException('照片上傳預約內容不完整。');
      }
      final bytes = await _compressJpeg(await photos[index].readAsBytes());
      final uploadTask = _firebaseStorage
          .ref(storagePath)
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes <= 0) {
          return;
        }
        final itemProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(0.1 + 0.8 * ((index + itemProgress) / photos.length));
      });
      await uploadTask;
      await _callWithRetry('finalizePhotoUpload', {
        'reservationId': reservationId,
      });
      onProgress(0.1 + 0.9 * ((index + 1) / photos.length));
    }
  }

  Future<Uint8List> _compressJpeg(Uint8List source) async {
    final decoded = image_library.decodeImage(source);
    if (decoded == null) {
      throw const ContributionException('選取的圖片無法讀取。');
    }
    final longestSide = max(decoded.width, decoded.height);
    if (longestSide <= 1600) {
      return Uint8List.fromList(image_library.encodeJpg(decoded, quality: 80));
    }
    final resizeWidth = decoded.width >= decoded.height ? 1600 : null;
    final resizeHeight = decoded.height > decoded.width ? 1600 : null;
    final resized = image_library.copyResize(
      decoded,
      width: resizeWidth,
      height: resizeHeight,
    );
    return Uint8List.fromList(image_library.encodeJpg(resized, quality: 80));
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

  Future<Map<Object?, Object?>> _callWithRetry(
    String name,
    Map<String, Object?> data,
  ) async {
    const retryableCodes = {'internal', 'unavailable', 'deadline-exceeded'};
    FirebaseFunctionsException? lastError;

    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await _call(name, data);
      } on FirebaseFunctionsException catch (error) {
        lastError = error;
        if (!retryableCodes.contains(error.code) || attempt == 2) {
          rethrow;
        }

        // Cloud Functions 冷啟動或短暫網路錯誤時稍候再試，避免讓使用者重新選照片。
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    throw lastError!;
  }

  ContributionException _contributionException(
    FirebaseFunctionsException error,
    String idempotencyKey,
  ) {
    final details = error.details;
    final detailMap = details is Map
        ? Map<Object?, Object?>.from(details)
        : null;
    final rawCandidates = detailMap?['candidates'];
    final candidates = rawCandidates is List
        ? rawCandidates
              .whereType<Map>()
              .map(
                (item) => DuplicateRestaurantCandidate.fromMap(
                  Map<Object?, Object?>.from(item),
                ),
              )
              .toList(growable: false)
        : const <DuplicateRestaurantCandidate>[];
    final retryAfter = (detailMap?['retryAfter'] as num?)?.toInt();
    return ContributionException(
      error.message ?? '投稿失敗，請稍後再試。',
      candidates: candidates,
      retryAfterSeconds: retryAfter,
      idempotencyKey: idempotencyKey,
    );
  }

  String _newIdempotencyKey() {
    final randomPart = List.generate(
      4,
      (_) => _random.nextInt(0xffffffff).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }
}

class ContributionException implements Exception {
  const ContributionException(
    this.message, {
    this.candidates = const [],
    this.retryAfterSeconds,
    this.idempotencyKey,
  });

  final String message;
  final List<DuplicateRestaurantCandidate> candidates;
  final int? retryAfterSeconds;
  final String? idempotencyKey;
}
