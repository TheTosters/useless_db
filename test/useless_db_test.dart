import 'package:useless_db/src/serialization_engines/json_engine.dart';
import 'package:useless_db/src/storage_engine/file_store_engine.dart';
import 'package:useless_db/useless_db.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'package:path/path.dart';

void main() {
  group('General DB tests', () {
    late Database database;
    late String workPath;
    setUp(() {
      workPath = join(Directory.systemTemp.absolute.path,"useless_db_tests");
      database = Database(workPath);
      database.registerEngine(storageEngine: FileStoreEngine(), serializationEngine: JsonEngine());
    });

    test('Create collection', () {

    });
  });
}
