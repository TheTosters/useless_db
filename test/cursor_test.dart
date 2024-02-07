import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:useless_db/src/cursor.dart';
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
      final col = await database.getCollection("test_col");
      for (int t = 0; t < 100; t++) {
        final item = {Collection.idField: "doc-$t", "iKey": t, "rnd": r.nextInt(9999)};
        items.add(item);
        await col.setDocument(item);
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
      final exp = items
          .sorted((a, b) => a["rnd"] - b["rnd"])
          .map((e) => e[Collection.idField])
          .toList();
      Function eq = const ListEquality().equals;
      expect(eq(list, exp), true);
    });
  });
}
