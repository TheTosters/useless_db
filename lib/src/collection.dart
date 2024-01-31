import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart';

import 'index.dart';
import 'lock_list.dart';
import 'serialization_engines/serialization_engine.dart';
import 'storage_engine/storage_engine.dart';

class Collection {
  static const String _indicesLockDocName = "\x00\x02\x00";
  final String name;
  final String _path;
  SerializationEngine _serializationEngine;
  StorageEngine _storageEngine;
  bool _operational;
  final LockList<String> _docLockList = LockList<String>();
  final List<Index> _indices = [];

  Collection._({
    required this.name,
    required String path,
    required SerializationEngine serializationEngine,
    required StorageEngine storageEngine,
  })  : _path = path,
        _serializationEngine = serializationEngine,
        _storageEngine = storageEngine,
        _operational = false;

  Future<void> _close() async {
    _operational = false;
    await _docLockList.waitForAllReleased();
    await _storageEngine.close();
  }

  Future<void> _open() async {
    _storageEngine = await _storageEngine.open(_path);
    await _recreateIndices();
    _operational = true;
  }

  Future<void> _recreateIndices() async {
    final indexNames = await _loadIndicesNames();
    for (final name in indexNames) {
      final data = await _storageEngine.readMetadata("index-$name");
      final index = data != null ? Index.fromDefinition(_serializationEngine.decode(data)) : null;
      if (index != null) {
        _indices.add(index);
        await index.onCreated();
      }
    }
    //feed data into indices
    _storageEngine.performSnapshot(
      (docId, {data}) {
        final decoded = _serializationEngine.decode(data!);
        for(final index in _indices) {
          index.addOrUpdateDocument(docId, decoded);
        }
      },
      loadDoc: true,
    );
  }

  Future<List<String>> _loadIndicesNames() async {
    final data = await _storageEngine.readMetadata("indices");
    return data != null ? _serializationEngine.decode(data) : [];
  }

  Future<void> _storeIndicesNames() async {
    final names = _indices.map((e) => e.name).toList(growable: false);
    await _storageEngine.writeMetadata("indices", _serializationEngine.encode(names));
  }

  Future<Map<String, dynamic>?> getDocument(String docId) async {
    if (!_operational) {
      throw Exception("Collection $name is closed.");
    }
    await _docLockList.lockRead(docId);
    final data = await _storageEngine.read(docId);
    _docLockList.releaseRead(docId);
    return data != null ? _serializationEngine.decode(data) : null;
  }

  Future<void> setDocument(String docId, Map<String, dynamic> object) async {
    if (!_operational) {
      throw Exception("Collection $name is closed.");
    }

    await _docLockList.lockWrite(_indicesLockDocName);
    await _docLockList.lockWrite(docId);
    final data = _serializationEngine.encode(object);
    await _storageEngine.write(docId, data);
    _docLockList.releaseWrite(docId);
    _docLockList.releaseWrite(_indicesLockDocName);
  }

  Future<void> addIndex(List<KeySortInfo> sortInfo, {String name = "_unnamed_"}) async {
    await _docLockList.lockWrite(_indicesLockDocName);
    if (_indices.any((i) => i.name == name)) {
      _docLockList.releaseWrite(_indicesLockDocName);
      throw Exception("Index with name `$name` already exists!");
    }
    final index = Index(sortInfo, name: name);
    await _storageEngine.writeMetadata(
        "index-$name", _serializationEngine.encode(index.definition()));
    _indices.add(index);
    await _storeIndicesNames();
    await index.onCreated();
    //TODO: Not sure about read doc locking there, see getDocument()...
    _storageEngine.performSnapshot(
      (docId, {data}) => index.addOrUpdateDocument(docId, _serializationEngine.decode(data!)),
      loadDoc: true,
    );
    _docLockList.releaseWrite(_indicesLockDocName);
  }

  Future<void> removeIndex({String? name, int? indexOfIndex}) async {
    await _docLockList.lockWrite(_indicesLockDocName);
    if (name != null) {
      indexOfIndex = _indices.indexWhere((i) => i.name == name);
      if (indexOfIndex < 0) {
        _docLockList.releaseWrite(_indicesLockDocName);
        return;
      }
    }
    if (indexOfIndex != null) {
      if (indexOfIndex > 0 && indexOfIndex < _indices.length) {
        final index = _indices.removeAt(indexOfIndex);
        index.onDestroy();
        await _storageEngine.deleteMetadata(index.name);
      }
    } else {
      _docLockList.releaseWrite(_indicesLockDocName);
      throw Exception("One of `name` or `indexOfIndex` must not ne null!");
    }
    _docLockList.releaseWrite(_indicesLockDocName);
  }

  Future<Index?> getIndex({String? name, int? indexOfIndex}) async {
    await _docLockList.lockRead(_indicesLockDocName);
    Index? result;
    if (name != null) {
      result = _indices.firstWhereOrNull((i) => i.name == name);
    } else if (indexOfIndex != null) {
      result = indexOfIndex > 0 && indexOfIndex < _indices.length ? _indices[indexOfIndex] : null;
    } else {
      _docLockList.releaseRead(_indicesLockDocName);
      throw Exception("One of `name` or `indexOfIndex` must not ne null!");
    }
    _docLockList.releaseRead(_indicesLockDocName);
    return result;
  }

  Future<bool> removeDocument(String docId) async {
    return _storageEngine.deleteDocument(docId);
  }
}

class CollectionProxy {
  static Future<void> close(Collection collection) async => await collection._close();
}

class CollectionBuilder {
  static final RegExp _regex = RegExp(r'[^\w-_]');

  static Future<Collection> createCollection({
    required String name,
    required String parentDir,
    required List<SerializationEngine> serializationEngines,
    required List<StorageEngine> storageEngines,
  }) async {
    final dirPath = join(parentDir, name.replaceAll(_regex, "_"));

    final dir = Directory(dirPath);
    Collection collection = Collection._(
      name: name,
      path: dirPath,
      serializationEngine: serializationEngines.first,
      storageEngine: storageEngines.first,
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      await _setSerializationEngineFor(dirPath, collection._serializationEngine);
      await _setStorageEngineFor(dirPath, collection._storageEngine);
    } else {
      //Folder already existed, extract used engines from it
      var id = await _getSerializationEngineIdFor(dirPath);
      final serializeEngine = serializationEngines.firstWhereOrNull((e) => e.isCompatible(id));
      if (serializeEngine == null) {
        throw Exception("Collection with name $name requires usage of unknown engine $id");
      }
      collection._serializationEngine = serializeEngine;
      //storage
      id = await _getStorageEngineIdFor(dirPath);
      final storageEngine = storageEngines.firstWhereOrNull((e) => e.isCompatible(id));
      if (storageEngine == null) {
        throw Exception("Collection with name $name requires usage of unknown engine $id");
      }
      collection._storageEngine = storageEngine;
    }
    await collection._open();
    return collection;
  }

  static Future<String> _getSerializationEngineIdFor(String dirPath) async {
    final dir = Directory(join(dirPath, "meta"));
    if (!dir.existsSync()) {
      dir.createSync();
    }
    try {
      File file = File(join(dir.absolute.path, "serialization_engine_id"));
      return file.readAsStringSync();
    } catch (e) {
      throw Exception("Can't access information about engine in collection path: $dirPath");
    }
  }

  static Future<void> _setSerializationEngineFor(String dirPath, SerializationEngine engine) async {
    final dir = Directory(join(dirPath, "meta"));
    if (!dir.existsSync()) {
      dir.createSync();
    }
    try {
      File file = File(join(dir.absolute.path, "serialization_engine_id"));
      file.writeAsStringSync(engine.id, flush: true);
    } catch (e) {
      throw Exception("Can't access information about engine in collection path: $dirPath");
    }
  }

  static Future<void> _setStorageEngineFor(String dirPath, StorageEngine engine) async {
    final dir = Directory(join(dirPath, "meta"));
    if (!dir.existsSync()) {
      dir.createSync();
    }
    try {
      File file = File(join(dir.absolute.path, "store_engine_id"));
      file.writeAsStringSync(engine.id, flush: true);
    } catch (e) {
      throw Exception("Can't access information about engine in collection path: $dirPath");
    }
  }

  static Future<String> _getStorageEngineIdFor(String dirPath) async {
    final dir = Directory(join(dirPath, "meta"));
    if (!dir.existsSync()) {
      dir.createSync();
    }
    try {
      File file = File(join(dir.absolute.path, "store_engine_id"));
      return file.readAsStringSync();
    } catch (e) {
      throw Exception("Can't access information about engine in collection path: $dirPath");
    }
  }
}
