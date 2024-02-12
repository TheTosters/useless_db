import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:useless_db/src/cursor.dart';
import 'package:useless_db/src/filter.dart';
import 'package:useless_db/src/serialization_engines/bson_engine.dart';
import 'package:useless_db/src/storage_engine/file_store_engine.dart';
import 'package:useless_db/useless_db.dart';

bool isDictionaryInList(Map<String, dynamic> dictionary, List<Map<String, dynamic>> list) {
  for (var item in list) {
    if (areMapsEqual(dictionary, item)) {
      return true;
    }
  }
  return false;
}

bool areMapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
  if (map1.length != map2.length) {
    return false;
  }

  for (var key in map1.keys) {
    if (!map2.containsKey(key) || map1[key] != map2[key]) {
      return false;
    }
  }

  return true;
}

void main() {
  group('Cursor tests', () {
    late Database database;
    late String workPath;
    late List<Map<String, dynamic>> items;
    setUp(() async {
      workPath = Directory.systemTemp.createTempSync().path;
      database = Database(workPath);
      database.registerEngine(storageEngine: FileStoreEngine(), serializationEngine: BsonEngine());
      await database.open();
      final r = Random();
      items = [];
      final rndSet = <int>{};
      while (rndSet.length < 100) {
        rndSet.add(r.nextInt(9999));
      }
      final col = await database.getCollection("test_col");
      int t = 0;
      for (final randValue in rndSet) {
        final item = {Collection.idField: "doc-$t", "iKey": t, "rnd": randValue};
        items.add(item);
        await col.setDocument(item);
        t++;
      }
    });

    tearDown(() async {
      await database.close();
    });

    test('Get all doc from collection', () async {
      final col = await database.getCollection("test_col");
      final primaryIndex = await col.primaryIndex();
      final cursor = Cursor(collection: col, index: primaryIndex);
      await cursor.reset();
      final count = await cursor.length;
      expect(count, items.length);
      while (true) {
        final (docId, d) = await cursor.getNextDocument();
        if (docId == null) {
          break;
        }
        expect(isDictionaryInList(d!, items), true);
      }
    });

    test('Get from collection rnd ascending', () async {
      final col = await database.getCollection("test_col");
      await col.addIndex(sortInfo: [("rnd", true)], name: "ind");
      final index = await col.getIndex(name: "ind");
      final cursor = Cursor(collection: col, index: index!);
      await cursor.reset();
      final count = await cursor.length;
      expect(count, items.length);
      final list = <String>[];
      while (true) {
        final (docId, _) = await cursor.getNextDocument();
        if (docId == null) {
          break;
        }
        list.add(docId);
      }
      final exp =
          items.sorted((a, b) => a["rnd"] - b["rnd"]).map((e) => e[Collection.idField]).toList();
      Function eq = const ListEquality().equals;
      expect(eq(list, exp), true);
    });

    test('Remove all documents using cursor', () async {
      final col = await database.getCollection("test_col");
      await col.addIndex(sortInfo: [("rnd", true)], name: "ind");
      final index = await col.getIndex(name: "ind");
      final cursor = Cursor(collection: col, index: index!);
      await cursor.reset();
      while (await cursor.deleteNextDocument() != null) {
        //nothing
      }
      await cursor.reset();
      final count = await cursor.length;
      expect(count, 0);
    });

    test('Get from collection rnd ascending only randoms less then 500', () async {
      final col = await database.getCollection("test_col");
      await col.addIndex(sortInfo: [("rnd", true)], name: "ind");
      final index = await col.getIndex(name: "ind");
      final filter = Filter(matchers: {"rnd": OpLt(500)});
      final cursor = Cursor(collection: col, index: index!, filter: filter);
      await cursor.reset();
      final count = await cursor.length;
      expect(count, items.length);
      final list = <String>[];
      while (true) {
        final (docId, _) = await cursor.getNextDocument();
        if (docId == null) {
          break;
        }
        list.add(docId);
      }
      final exp = items
          .where((e) => e["rnd"] < 500)
          .sorted((a, b) => a["rnd"] - b["rnd"])
          .map((e) => e[Collection.idField])
          .toList();
      Function eq = const ListEquality().equals;
      expect(eq(list, exp), true);
    });
  });
  //TODO: Test index -> preserve across db close/open
  //TODO: Test index -> add document to Db while index was already created
  //TODO: Test index -> remove document to Db while index was already created
  //TODO: Test index -> update document to Db while index was already created
}
