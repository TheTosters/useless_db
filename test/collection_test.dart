import 'package:useless_db/src/serialization_engines/bson_engine.dart';
import 'package:useless_db/src/serialization_engines/json_engine.dart';
import 'package:useless_db/src/storage_engine/file_store_engine.dart';
import 'package:useless_db/useless_db.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'package:path/path.dart';

void main() {
  group('Collection tests', () {
    late Database database;
    late String workPath;
    setUp(() async {
      workPath = join(Directory.systemTemp.absolute.path, "useless_db_tests");
      final d = Directory(workPath);
      if (d.existsSync()) {
        Directory(workPath).deleteSync(recursive: true);
      }
      database = Database(workPath);
      database.registerEngine(storageEngine: FileStoreEngine(), serializationEngine: BsonEngine());
      await database.open();
    });

    tearDown(() async {
      await database.close();
    });

    test('Set & get data with collection', () async {
      final col = await database.getCollection("test_col");
      final doc = {
        "str-key": "String val",
        "int-key": 2323,
        "float-key": 23.2,
        "bool-key": true,
        "date-key": DateTime.now().toUtc(),
        "dict-key": {
          "str-key": "String val",
        },
        "array-key": ["a", 1, true, 22.2, DateTime.now()]
      };
      await col.setDocument("doc-1", doc);
      final getResult = await col.getDocument("doc-1");
      expect(getResult, doc);
      expect(identical(getResult, doc), false);
    });
  });
}
