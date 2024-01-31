import 'dart:io';

import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';

import 'collection.dart';
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

  UselessDbState get state => _state;

  Database(this.workDir);

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
    //TODO: Implement
    return [];
  }

  Future<bool> deleteCollection(String name) async {
    if (_state != UselessDbState.open) {
      throw Exception("DB is not open");
    }
    //TODO: Implement
    return false;
  }
}
