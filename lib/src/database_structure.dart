import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart';

import 'serialization_engines/serialization_engine.dart';

class CollectionMeta {
  final String name;
  final String storagePath;
  final String storageEngine;
  final String serializationEngine;

  CollectionMeta({
    required this.name,
    required this.storagePath,
    required this.storageEngine,
    required this.serializationEngine,
  });

  factory CollectionMeta.fromMap(Map<String, dynamic> data) => CollectionMeta(
        name: data["name"],
        storagePath: data["path"],
        storageEngine: data["storageEngine"],
        serializationEngine: data["serializationEngine"],
      );

  Map<String, String> toMap() => {
        "name": name,
        "path": storagePath,
        "storageEngine": storageEngine,
        "serializationEngine": serializationEngine,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionMeta && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return 'CollectionMeta{name: $name, storagePath: $storagePath, '
        'storageEngine: $storageEngine, serializationEngine: $serializationEngine}';
  }
}

class DatabaseStructure {
  final List<CollectionMeta> _collections = [];
  final String _workFile;
  final SerializationEngine serializationEngine;

  DatabaseStructure({required String workDir, required this.serializationEngine})
      : _workFile = join(workDir, "_db_struct.meta") {
    _loadStructure();
  }

  void addCollection(CollectionMeta meta) {
    if (_collections.contains(meta)) {
      throw Exception("Collection with name ${meta.name} already exists!");
    } else {
      _collections.add(meta);
      _saveStructure();
    }
  }

  void removeCollection({CollectionMeta? meta, String? name}) {
    if (meta == null && name != null) {
      meta ??= CollectionMeta(
        name: name,
        storagePath: "",
        storageEngine: "",
        serializationEngine: "",
      );
    }
    if (meta == null) {
      throw Exception("Meta or Name must not be null");
    }
    if (!_collections.contains(meta)) {
      throw Exception("Collection with name ${meta.name} don't exists!");
    } else {
      _collections.remove(meta);
      _saveStructure();
    }
  }

  void updateCollection(CollectionMeta meta) {
    if (!_collections.contains(meta)) {
      throw Exception("Collection with name ${meta.name} don't exists!");
    } else {
      _collections.remove(meta); //NOTE equality operator!
      _collections.add(meta);
      _saveStructure();
    }
  }

  List<String> getCollectionNames() => _collections.map((e) => e.name).toList(growable: false);

  CollectionMeta? getCollection(String name) {
    final col = _collections.firstWhereOrNull((element) => element.name == name);
    return col != null ? CollectionMeta.fromMap(col.toMap()) : null;
  }

  void _saveStructure() async {
    final list = _collections.map((e) => e.toMap()).toList(growable: false);
    final data = serializationEngine.encode(list);
    final file = File(_workFile);
    file.writeAsBytesSync(data);
  }

  void _loadStructure() async {
    final file = File(_workFile);
    if (file.existsSync()) {
      final data = file.readAsBytesSync();
      final colList = serializationEngine.decode(data);
      for (final c in colList) {
        _collections.add(CollectionMeta.fromMap(c));
      }
    }
  }

  void dispose() => _collections.clear();
}
