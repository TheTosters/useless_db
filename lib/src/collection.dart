import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart';
import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/v7.dart';

import 'database_structure.dart';
import 'index.dart';
import 'lock_list.dart';
import 'serialization_engines/serialization_engine.dart';
import 'storage_engine/storage_engine.dart';

class Collection {
  static const String _indicesLockDocName = "\x00\x02\x00";
  static const String idField = "_id";
  final GlobalOptions _uuidOptions = GlobalOptions(MathRNG());
  final String name;
  final String _path;
  final SerializationEngine _serializationEngine;
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
      final index =
          data != null ? SortedIndex.fromDefinition(_serializationEngine.decode(data)) : null;
      if (index != null) {
        _indices.add(index);
        await index.onCreated();
      }
    }
    //feed data into indices
    _storageEngine.performSnapshot(
      (docId, {data}) {
        final decoded = _serializationEngine.decode(data!);
        for (final index in _indices) {
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

  Future<void> setDocument(Map<String, dynamic> object) async {
    if (!_operational) {
      throw Exception("Collection $name is closed.");
    }
    final docId = object[idField] ?? UuidV7(goptions: _uuidOptions).generate();
    await _docLockList.lockWrite(_indicesLockDocName);
    await _docLockList.lockWrite(docId);
    for(final index in _indices) {
      index.addOrUpdateDocument(docId, object);
    }
    final data = _serializationEngine.encode(object);
    await _storageEngine.write(docId, data);
    _docLockList.releaseWrite(docId);
    _docLockList.releaseWrite(_indicesLockDocName);
  }

  Future<void> addIndex({required List<KeySortInfo> sortInfo, String name = "_unnamed_"}) async {
    await _docLockList.lockWrite(_indicesLockDocName);
    if (_indices.any((i) => i.name == name)) {
      _docLockList.releaseWrite(_indicesLockDocName);
      throw Exception("Index with name `$name` already exists!");
    }
    final index = SortedIndex(sortInfo, name: name);
    await _storageEngine.writeMetadata(
        "index-$name", _serializationEngine.encode(index.definition()));
    _indices.add(index);
    await _storeIndicesNames();
    await index.onCreated();
    //TODO: Not sure about read doc locking there, see getDocument()...
    await _storageEngine.performSnapshot(
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
    final result = _storageEngine.deleteDocument(docId);
    await _docLockList.lockRead(_indicesLockDocName);
    for(final index in _indices) {
      index.deleteDocument(docId);
    }
    _docLockList.releaseRead(_indicesLockDocName);
    return result;
  }

  Future<Index> primaryIndex() async {
    return await _storageEngine.getPrimaryIndex();
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
    required DatabaseStructure structure,
  }) async {
    final colMeta = structure.getCollection(name);
    Collection collection;
    if (colMeta == null) {
      //create
      final dirPath = join(parentDir, name.replaceAll(_regex, "_"));
      final dir = Directory(dirPath);
      collection = Collection._(
        name: name,
        path: dirPath,
        serializationEngine: serializationEngines.first,
        storageEngine: storageEngines.first,
      );
      dir.createSync(recursive: true);
      structure.addCollection(
        CollectionMeta(
          name: name,
          storagePath: dir.absolute.path,
          storageEngine: collection._storageEngine.id,
          serializationEngine: collection._serializationEngine.id,
        ),
      );
    } else {
      //open
      final serializeEngine =
          serializationEngines.firstWhereOrNull((e) => e.isCompatible(colMeta.serializationEngine));
      if (serializeEngine == null) {
        throw Exception("Collection with name $name requires usage of unknown "
            "serialization engine: ${colMeta.serializationEngine}");
      }
      final storageEngine =
          storageEngines.firstWhereOrNull((e) => e.isCompatible(colMeta.storageEngine));
      if (storageEngine == null) {
        throw Exception("Collection with name $name requires usage of unknown "
            "storage engine ${colMeta.storageEngine}");
      }
      collection = Collection._(
        name: name,
        path: colMeta.storagePath,
        serializationEngine: serializeEngine,
        storageEngine: storageEngine,
      );
      final dir = Directory(colMeta.storagePath);
      if (!dir.existsSync()) {
        dir.createSync();
      }
    }

    await collection._open();
    return collection;
  }

  static Future<void> deleteCollection({
    required Collection collection,
    required DatabaseStructure structure,
  }) async {
    await collection._close();
    structure.removeCollection(name: collection.name);
    Directory(collection._path).deleteSync(recursive: true);
  }
}
