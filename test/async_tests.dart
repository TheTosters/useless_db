import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
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
  group('DB Async Test', () {
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

    test('Add non conflicting data.', () async {
      await database.open();

      var collection = await database.getCollection("test");
      List<Map<String, dynamic>> documents = [];
      _generateDocs(9988, 0, 300, documents);
      collection = await database.getCollection("test");
      final random = Random(87345);
      for (final d in documents) {
        if (random.nextBool()) {
          await Future.delayed(Duration.zero);
        }
        collection.setDocument(d);
      }
      await database.close(); //This should syncup writes
      await database.open();
      collection = await database.getCollection("test");
      final index = await collection.primaryIndex();
      expect(index, isNotNull);
      final snapshot = await index.performSnapshot();
      expect(snapshot, isNotNull);

      snapshot.sort((a, b) => a.compareTo(b));
      final docIds =
          documents.map((e) => e[Collection.idField]).sorted((a, b) => a.compareTo(b)).toList();
      expect(snapshot, docIds);
    });

    test('Read and writes non conflicting data.', () async {
      await database.open();

      var collection = await database.getCollection("test");
      List<Map<String, dynamic>> documents = [];
      List<Map<String, dynamic>> readDoc = [];
      _generateDocs(9988, 0, 300, documents);
      collection = await database.getCollection("test");
      final docToAdd = List.of(documents);
      List<String> docIdToRead = [];
      final random = Random(8383);
      int inWait = 0;
      while (docToAdd.isNotEmpty || docIdToRead.isNotEmpty || inWait > 0) {
        await Future.delayed(Duration.zero);
        if (docToAdd.isNotEmpty) {
          final d = docToAdd.removeLast();
          inWait++;
          collection.setDocument(d).then((value) {
            final id = d[Collection.idField];
            docIdToRead.add(id);
            inWait--;
            //print(">> $id, inWait: $inWait");
          });

          if (docIdToRead.length > 5) {
            //randomize and read
            docIdToRead.shuffle(random);
            final rId = docIdToRead.removeLast();
            //print("<< $rId");
            collection.getDocument(rId).then((value) {
              if (value != null) {
                readDoc.add(value);
              }
            });
          }
        } else {
          if (docIdToRead.isNotEmpty) {
            //Just read
            final rId = docIdToRead.removeLast();
            //print("<< $rId");
            collection.getDocument(rId).then((value) {
              if (value != null) {
                readDoc.add(value);
              }
            });
          }
        }
      }

      await database.close(); //This should syncup reads & writes
      final docIds =
          documents.map((e) => e[Collection.idField]).sorted((a, b) => a.compareTo(b)).toList();
      final collectedDocIds =
          readDoc.map((e) => e[Collection.idField]).sorted((a, b) => a.compareTo(b)).toList();
      expect(docIds, collectedDocIds);
    });
  });
}
