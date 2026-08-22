import 'package:cloud_firestore/cloud_firestore.dart';

class ImportedPlace {
  const ImportedPlace({
    required this.id,
    required this.sourceTitle,
    required this.sourceNote,
    required this.googleMapsUrl,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.attribution,
  });

  factory ImportedPlace.fromMap(String id, Map<String, dynamic> data) {
    final geo = data['geo'];
    return ImportedPlace(
      id: id,
      sourceTitle: data['sourceTitle'] as String? ?? '',
      sourceNote: data['sourceNote'] as String?,
      googleMapsUrl: data['sourceGoogleMapsUrl'] as String?,
      name:
          data['name'] as String? ?? data['sourceTitle'] as String? ?? '未命名店家',
      address: data['address'] as String? ?? '',
      latitude: geo is GeoPoint ? geo.latitude : 0,
      longitude: geo is GeoPoint ? geo.longitude : 0,
      attribution:
          data['attribution'] as String? ??
          'Powered by Geoapify © OpenStreetMap contributors',
    );
  }

  final String id;
  final String sourceTitle;
  final String? sourceNote;
  final String? googleMapsUrl;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String attribution;
}

class ImportedPlaceSource {
  const ImportedPlaceSource({
    required this.title,
    this.note,
    this.googleMapsUrl,
  });

  final String title;
  final String? note;
  final String? googleMapsUrl;

  Map<String, Object?> toMap() => {
    'title': title,
    'note': note,
    'googleMapsUrl': googleMapsUrl,
  };
}

class ImportedPlaceCandidate {
  const ImportedPlaceCandidate({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isRecommended,
    this.confidence,
  });

  factory ImportedPlaceCandidate.fromMap(Map<Object?, Object?> data) {
    return ImportedPlaceCandidate(
      placeId: data['placeId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      isRecommended: data['isRecommended'] as bool? ?? false,
      confidence: (data['confidence'] as num?)?.toDouble(),
    );
  }

  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool isRecommended;
  final double? confidence;

  Map<String, Object?> toMap() => {
    'placeId': placeId,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'isRecommended': isRecommended,
    'confidence': confidence,
  };
}

class ImportedPlaceMatch {
  const ImportedPlaceMatch({required this.source, required this.candidates});

  factory ImportedPlaceMatch.fromMap(Map<Object?, Object?> data) {
    final rawSource = data['source'];
    final source = rawSource is Map
        ? Map<Object?, Object?>.from(rawSource)
        : const <Object?, Object?>{};
    final rawCandidates = data['candidates'];
    return ImportedPlaceMatch(
      source: ImportedPlaceSource(
        title: source['title'] as String? ?? '',
        note: source['note'] as String?,
        googleMapsUrl: source['googleMapsUrl'] as String?,
      ),
      candidates: rawCandidates is List
          ? rawCandidates
                .whereType<Map>()
                .map(
                  (item) => ImportedPlaceCandidate.fromMap(
                    Map<Object?, Object?>.from(item),
                  ),
                )
                .where((candidate) => candidate.placeId.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  final ImportedPlaceSource source;
  final List<ImportedPlaceCandidate> candidates;
}
