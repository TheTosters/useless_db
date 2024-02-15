import 'dart:io';

import 'package:test/test.dart';
import 'package:useless_db/src/serialization_engines/json_engine.dart';
import 'package:useless_db/src/storage_engine/file_store_engine.dart';
import 'package:useless_db/useless_db.dart';

void main() {
  group('General DB tests', () {
    late Database database;
    late String workPath;
    setUp(() {
      workPath = Directory.systemTemp.createTempSync().path;
      database = Database(workPath);
      database.registerEngine(storageEngine: FileStoreEngine(), serializationEngine: JsonEngine());
    });

    test('Should not be possible to open DB more than once', () async {
      await database.open();
      await expectLater(database.open(), throwsA(isException));
      await database.close();
    });

    test('Should not be possible to close not open DB', () async {
      await expectLater(database.close(), throwsA(isException));
    });

    test('Should not be possible to close DB more than once', () async {
      await database.open();
      await database.close();
      await expectLater(database.close(), throwsA(isException));
    });

    test('Collection not accessible on close DB', () async {
      await expectLater(database.getCollection("test_collection"), throwsA(isException));
    });

    test('Get or create collection', () async {
      await database.open();
      final col = await database.getCollection("test_collection");
      final col2 = await database.getCollection("test_collection");
      expect(col, col2);
      await database.close();
    });

    test('Delete collection', () async {
      await database.open();
      await database.getCollection("test_collection");
      var list = await database.getCollectionsList();
      expect(list, ["test_collection"]);
      await database.deleteCollection("test_collection");
      list = await database.getCollectionsList();
      expect(list, []);
      await database.close();
    });

    test('Get collections list', () async {
      await database.open();
      await database.getCollection("test_collection");
      await database.getCollection("test_collection_2");
      final list = await database.getCollectionsList();
      expect(list, ["test_collection", "test_collection_2"]);
      await database.close();
    });
  });
}
