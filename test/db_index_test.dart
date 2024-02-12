import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:useless_db/src/serialization_engines/bson_engine.dart';
import 'package:useless_db/src/storage_engine/file_store_engine.dart';
import 'package:useless_db/useless_db.dart';

void _generateDocs(int seed, int offset, int count, List<Map<String, dynamic>> into) {
  final random = Random(seed);
  final rndSet = <int>{};
  final tmpSet = Set.from(into.map((e) => e["rnd"]));
  while (rndSet.length < count) {
    final r = random.nextInt(9999);
    if (tmpSet.contains(r)) {
      continue;
    }
    rndSet.add(r);
  }
  int t = 0;
  for (final randValue in rndSet) {
    final item = {Collection.idField: "doc-${offset + t}", "rnd": randValue};
    into.add(item);
    t++;
  }
  into.sort((a, b) => a["rnd"] - b["rnd"]);
}

void main() {
  group('DB Index Test', () {
    late Database database;
    late String workPath;
    setUp(() async {
      workPath = Directory.systemTemp.createTempSync().path;
      database = Database(workPath);
      database.registerEngine(storageEngine: FileStoreEngine(), serializationEngine: BsonEngine());
    });

    tearDown(() async {
      if (database.state == UselessDbState.open) {
        await database.close();
      }
    });

    test('Index should be preserved across open / close db', () async {
      await database.open();
      var collection = await database.getCollection("test");
      await collection.addIndex(sortInfo: [("rnd", true)], name: "rndIndex");
      await collection.setDocument({"rnd": 12});
      await collection.setDocument({"rnd": 23});
      await database.close();
      await database.open();
      collection = await database.getCollection("test");
      final index = await collection.getIndex(name: "rndIndex");
      expect(index, isNotNull);
      final snapshot = await index?.performSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.length, 2);
    });

    test('Add document to Db while index was already created', () async {
      await database.open();
      var collection = await database.getCollection("test");
      await collection.addIndex(sortInfo: [("rnd", true)], name: "rndIndex");
      await collection.setDocument({Collection.idField: "A", "rnd": 112});
      await collection.setDocument({Collection.idField: "B", "rnd": 23});
      await database.close();
      await database.open();
      collection = await database.getCollection("test");
      await collection.setDocument({Collection.idField: "C", "rnd": 213});
      final index = await collection.getIndex(name: "rndIndex");
      expect(index, isNotNull);
      final snapshot = await index?.performSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.length, 3);
      expect(snapshot, ["B", "A", "C"]);
    });

    test('Add document to Db while index was already created', () async {
      await database.open();
      var collection = await database.getCollection("test");
      await collection.addIndex(sortInfo: [("rnd", true)], name: "rndIndex");
      await collection.setDocument({Collection.idField: "A", "rnd": 112});
      await collection.setDocument({Collection.idField: "B", "rnd": 23});
      await database.close();
      await database.open();
      collection = await database.getCollection("test");
      await collection.setDocument({Collection.idField: "C", "rnd": 213});
      final index = await collection.getIndex(name: "rndIndex");
      expect(index, isNotNull);
      final snapshot = await index?.performSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.length, 3);
      expect(snapshot, ["B", "A", "C"]);
    });

    test('Remove document from Db while index was already created', () async {
      await database.open();
      var collection = await database.getCollection("test");
      List<Map<String, dynamic>> documents = [];
      _generateDocs(338, 0, 40, documents);
      for (final d in documents) {
        await collection.setDocument(d);
      }
      await collection.addIndex(sortInfo: [("rnd", true)], name: "rndIndex");
      _generateDocs(1338, 41, 40, documents);
      for (final d in documents) {
        await collection.setDocument(d);
      }
      await database.close();

      //OPEN & REMOVE
      await database.open();
      collection = await database.getCollection("test");
      final random = Random(444);
      final index = await collection.getIndex(name: "rndIndex");
      expect(index, isNotNull);
      for (int t = 0; t < 33; t++) {
        final idx = random.nextInt(documents.length);
        final doc = documents.removeAt(idx);
        await collection.removeDocument(doc[Collection.idField]);
        final snapshot = await index?.performSnapshot();
        expect(snapshot, isNotNull);
        final idsDocs = documents.map((e) => e[Collection.idField]).toList();
        expect(snapshot, idsDocs);
      }
    });

    test('Update document in Db while index was already created', () async {
      await database.open();
      var collection = await database.getCollection("test");
      List<Map<String, dynamic>> documents = [];
      _generateDocs(338, 0, 40, documents);
      for (final d in documents) {
        await collection.setDocument(d);
      }
      await collection.addIndex(sortInfo: [("rnd", true)], name: "rndIndex");
      await database.close();

      //OPEN & UPDATE
      await database.open();
      collection = await database.getCollection("test");
      documents.clear();
      _generateDocs(1338, 0, 40, documents);
      for (final d in documents) {
        await collection.setDocument(d);
      }

      //CHECK
      final index = await collection.getIndex(name: "rndIndex");
      expect(index, isNotNull);
      final snapshot = await index?.performSnapshot();
      expect(snapshot, isNotNull);
      final idsDocs = documents.map((e) => e[Collection.idField]).toList();
      expect(snapshot, idsDocs);
    });
  });
}
