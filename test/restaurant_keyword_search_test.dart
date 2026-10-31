// 測試用假物件需要實作 Firestore 的 sealed 類別。
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_app/data/models/restaurant.dart';
import 'package:food_app/data/repositories/restaurant_repository.dart';

typedef _Doc = Map<String, dynamic>;

class _FakeDocument extends Fake implements QueryDocumentSnapshot<_Doc> {
  _FakeDocument(this.id, this._data);

  @override
  final String id;
  final _Doc _data;

  @override
  _Doc data() => _data;
}

class _FakeSnapshot extends Fake implements QuerySnapshot<_Doc> {
  _FakeSnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<_Doc>> docs;
}

/// 只實作關鍵字搜尋用到的查詢方法，並記錄實際讀取的批次數。
class _FakeQuery extends Fake implements CollectionReference<_Doc> {
  _FakeQuery(
    this._store, {
    DocumentSnapshot<_Doc>? after,
    int? limit,
    String? category,
  }) : _after = after,
       _limit = limit,
       _category = category;

  final _FakeStore _store;
  final DocumentSnapshot<_Doc>? _after;
  final int? _limit;
  final String? _category;

  _FakeQuery _copy({
    DocumentSnapshot<_Doc>? after,
    int? limit,
    String? category,
  }) {
    return _FakeQuery(
      _store,
      after: after ?? _after,
      limit: limit ?? _limit,
      category: category ?? _category,
    );
  }

  @override
  Query<_Doc> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return _copy(category: arrayContains as String?);
  }

  @override
  Query<_Doc> orderBy(Object field, {bool descending = false}) => this;

  @override
  Query<_Doc> startAfterDocument(DocumentSnapshot documentSnapshot) {
    return _copy(after: documentSnapshot as DocumentSnapshot<_Doc>);
  }

  @override
  Query<_Doc> limit(int limit) => _copy(limit: limit);

  @override
  Future<QuerySnapshot<_Doc>> get([GetOptions? options]) async {
    _store.batchCount += 1;
    var documents = _store.documents
        .where(
          (document) =>
              _category == null ||
              (document.data()['categories'] as List).contains(_category),
        )
        .toList();
    final after = _after;
    if (after != null) {
      final index = documents.indexWhere((document) => document.id == after.id);
      documents = documents.sublist(index + 1);
    }
    return _FakeSnapshot(documents.take(_limit!).toList());
  }
}

class _FakeStore extends Fake implements FirebaseFirestore {
  _FakeStore(Iterable<String> names, {List<String> categories = const ['日式']})
    : documents = (names.toList()..sort())
          .map(
            (name) => _FakeDocument(name, {
              'name': name,
              'nameLower': name.toLowerCase(),
              'status': 'active',
              'categories': categories,
            }),
          )
          .toList();

  final List<_FakeDocument> documents;
  int batchCount = 0;

  @override
  CollectionReference<_Doc> collection(String collectionPath) {
    return _FakeQuery(this);
  }
}

List<String> _names(RestaurantSearchPage page) {
  return page.restaurants.map((restaurant) => restaurant.name).toList();
}

Restaurant _restaurant(String name) {
  return Restaurant.fromMap(name, {
    'name': name,
    'nameLower': name.toLowerCase(),
  });
}

void main() {
  group('關鍵字搜尋', () {
    test('可以用店名中段或結尾的文字找到店家', () async {
      final repository = RestaurantRepository(
        firestore: _FakeStore(['阿義肉粥', '小王牛肉麵', '肉粥專賣']),
      );

      final page = await repository.searchRestaurantPage(
        const RestaurantSearchQuery(keyword: '肉粥', limit: 6),
      );

      expect(_names(page), unorderedEquals(['阿義肉粥', '肉粥專賣']));
      expect(page.hasMore, isFalse);
    });

    test('店名開頭與英文大小寫的搜尋維持可用', () async {
      final repository = RestaurantRepository(
        firestore: _FakeStore(['阿義肉粥', 'Pizza House']),
      );

      expect(
        _names(
          await repository.searchRestaurantPage(
            const RestaurantSearchQuery(keyword: '阿義'),
          ),
        ),
        ['阿義肉粥'],
      );
      expect(
        _names(
          await repository.searchRestaurantPage(
            const RestaurantSearchQuery(keyword: ' HOUSE ').normalized(),
          ),
        ),
        ['Pizza House'],
      );
    });

    test('符合的店家在第一批之後也找得到', () async {
      final store = _FakeStore([
        for (var index = 0; index < 250; index++)
          '${index.toString().padLeft(3, '0')}店',
        '阿義肉粥',
      ]);

      final page = await RestaurantRepository(
        firestore: store,
      ).searchRestaurantPage(const RestaurantSearchQuery(keyword: '肉粥'));

      expect(_names(page), ['阿義肉粥']);
      expect(store.batchCount, 3);
    });

    test('分頁不會重複或漏掉店家，湊滿一頁就停止讀取', () async {
      final expected = [
        for (var index = 0; index < 15; index++)
          '${index.toString().padLeft(2, '0')}肉粥',
      ];
      final store = _FakeStore([
        ...expected,
        for (var index = 0; index < 300; index++)
          '店${index.toString().padLeft(3, '0')}',
      ]);
      final repository = RestaurantRepository(firestore: store);
      const query = RestaurantSearchQuery(keyword: '肉粥', limit: 6);

      final first = await repository.searchRestaurantPage(query);
      expect(first.hasMore, isTrue);
      expect(store.batchCount, 1);
      final second = await repository.searchRestaurantPage(
        query,
        previousPage: first,
      );
      expect(second.hasMore, isTrue);
      final third = await repository.searchRestaurantPage(
        query,
        previousPage: second,
      );

      expect(third.hasMore, isFalse);
      expect([..._names(first), ..._names(second), ..._names(third)], expected);
    });

    test('關鍵字恰好湊滿一頁時不顯示載入更多', () async {
      final repository = RestaurantRepository(
        firestore: _FakeStore(['甲肉粥', '乙肉粥']),
      );

      final page = await repository.searchRestaurantPage(
        const RestaurantSearchQuery(keyword: '肉粥', limit: 2),
      );

      expect(page.restaurants, hasLength(2));
      expect(page.hasMore, isFalse);
    });

    test('搜尋結果沒有店家時回傳空頁', () async {
      final repository = RestaurantRepository(firestore: _FakeStore(['阿義肉粥']));

      final page = await repository.searchRestaurantPage(
        const RestaurantSearchQuery(keyword: '壽司'),
      );

      expect(page.restaurants, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('關鍵字可與分類一起篩選', () async {
      final repository = RestaurantRepository(
        firestore: _FakeStore(['阿義肉粥'], categories: ['台式']),
      );

      expect(
        await repository.searchRestaurantPage(
          const RestaurantSearchQuery(keyword: '肉粥', category: '日式'),
        ),
        isA<RestaurantSearchPage>().having(
          (page) => page.restaurants,
          'restaurants',
          isEmpty,
        ),
      );
      expect(
        _names(
          await repository.searchRestaurantPage(
            const RestaurantSearchQuery(keyword: '肉粥', category: '台式'),
          ),
        ),
        ['阿義肉粥'],
      );
    });

    test('我的最愛的本機篩選也比對店名中段', () {
      final matches = const RestaurantSearchQuery(
        keyword: '肉粥',
      ).filterCatalog([_restaurant('阿義肉粥'), _restaurant('小王牛肉麵')]);

      expect(matches.map((restaurant) => restaurant.name), ['阿義肉粥']);
    });
  });
}
