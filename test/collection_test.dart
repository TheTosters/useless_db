import 'dart:io';

import 'package:test/test.dart';
import 'package:useless_db/src/serialization_engines/bson_engine.dart';
import 'package:useless_db/src/storage_engine/file_store_engine.dart';
import 'package:useless_db/useless_db.dart';

void main() {
  group('Collection tests', () {
    late Database database;
    late String workPath;
    setUp(() async {
      workPath = Directory.systemTemp.createTempSync().path;
      database = Database(workPath);
      database.registerEngine(storageEngine: FileStoreEngine(), serializationEngine: BsonEngine());
      await database.open();
    });

    tearDown(() async {
      await database.close();
    });

    test('Update data in collection', () async {
      final col = await database.getCollection("test_col");
      final doc = <String, dynamic>{
        Collection.idField: "doc-1",
        "str-key": "Initial value",
      };
      await col.setDocument(doc);
      doc["int-key"] = 11;
      await col.setDocument(doc);
      final getResult = await col.getDocument("doc-1");
      expect(getResult, doc);
      expect(identical(getResult, doc), false);
    });

    test('Delete data in collection', () async {
      final col = await database.getCollection("test_col");
      final doc = {
        Collection.idField: "doc-1",
        "str-key": "String val",
      };
      await col.setDocument(doc);
      await col.removeDocument("doc-1");
      final getResult = await col.getDocument("doc-1");
      expect(getResult, null);
    });

    test('Set & get data with collection', () async {
      final col = await database.getCollection("test_col");
      final doc = {
        Collection.idField: "doc-1",
        "str-key": "String val",
        "int-key": 2323,
        "float-key": 23.2,
        "bool-key": true,
        "date-key": DateTime.utc(2018, 8, 23, 12, 00, 00),
        "dict-key": {
          "str-key": "String val",
        },
        "array-key": ["a", 1, true, 22.2, DateTime.utc(2018, 8, 23, 12, 10, 20)]
      };
      await col.setDocument(doc);
      final getResult = await col.getDocument("doc-1");
      expect(getResult, doc);
      expect(identical(getResult, doc), false);
    });
  });
}
