import 'dart:io';

import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';
import 'package:useless_db/src/serialization_engines/json_engine.dart';

import 'collection.dart';
import 'database_engine.dart';
import 'database_structure.dart';
import 'serialization_engines/serialization_engine.dart';
import 'storage_engine/storage_engine.dart';

enum UselessDbState { closed, open, opening, closing }

class Database {
  final String workDir;
  UselessDbState _state = UselessDbState.closed;
  final _collections = <Collection>{};
  final _lock = Lock();
  final _serializationEngines = <SerializationEngine>[];
  final _storageEngines = <StorageEngine>[];
  late DatabaseStructure _structure;

  UselessDbState get state => _state;

  Database(this.workDir);

  void registerEngines(List<DatabaseEngine> engines) {
    for (final e in engines) {
      if (e is SerializationEngine) {
        if (!_serializationEngines.contains(e)) {
          _serializationEngines.add(e);
        }
      } else if (e is StorageEngine) {
        if (!_storageEngines.contains(e)) {
          _storageEngines.add(e);
        }
      } else {
        throw Exception("Unsupported engine $e, not one of [SerializationEngine, StorageEngine]");
      }
    }
  }

  void registerEngine({SerializationEngine? serializationEngine, StorageEngine? storageEngine}) {
    if (serializationEngine != null && !_serializationEngines.contains(serializationEngine)) {
      _serializationEngines.add(serializationEngine);
    }
    if (storageEngine != null && !_storageEngines.contains(storageEngine)) {
      _storageEngines.add(storageEngine);
    }
  }

  Future<void> open() async {
    return await _lock.synchronized(() {
      if (_state != UselessDbState.closed) {
        throw Exception("DB in wrong state, must be `closed` to call this method!");
      }
      _state = UselessDbState.opening;
      final directory = Directory(workDir);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      _structure = DatabaseStructure(workDir: workDir, serializationEngine: JsonEngine());
      _state = UselessDbState.open;
    });
  }

  Future<void> close() async {
    return await _lock.synchronized(() async {
      if (_state != UselessDbState.open) {
        throw Exception("DB in wrong state, must be `open` to call this method!");
      }
      _state = UselessDbState.closing;
      for (final c in _collections) {
        await CollectionProxy.close(c);
      }
      _collections.clear();
      _structure.dispose();
      _state = UselessDbState.closed;
    });
  }

  Future<Collection> getCollection(String name) async {
    if (_state != UselessDbState.open) {
      throw Exception("DB is not open");
    }
    return await _lock.synchronized(() async {
      Collection? result = _collections.firstWhereOrNull((element) => element.name == name);
      if (result == null) {
        result = await CollectionBuilder.createCollection(
          name: name,
          parentDir: workDir,
          serializationEngines: _serializationEngines,
          storageEngines: _storageEngines,
          structure: _structure,
        );
        _collections.add(result);
      }
      return result;
    });
  }

  Future<List<String>> getCollectionsList() async {
    if (_state != UselessDbState.open) {
      throw Exception("DB is not open");
    }
    return _structure.getCollectionNames();
  }

  Future<bool> deleteCollection(String name) async {
    if (_state != UselessDbState.open) {
      throw Exception("DB is not open");
    }
    return await _lock.synchronized(() async {
      Collection? collection = _collections.firstWhereOrNull((element) => element.name == name);
      if (collection != null) {
        await CollectionBuilder.deleteCollection(
          collection: collection,
          structure: _structure,
        );
        _collections.remove(collection);
      }
      return collection != null;
    });
  }
}
