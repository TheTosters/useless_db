import 'dart:typed_data';

import '../database_engine.dart';
import '../index.dart';

abstract class StorageEngine extends DatabaseEngine {
  String get id;

  bool isCompatible(String engineId);

  Future<StorageEngine> open(String workDir);

  Future<void> close();

  Future<void> write(String docId, Uint8List data);

  Future<Uint8List?> read(String docId);

  Future<bool> deleteDocument(String docId);

  Future<void> writeMetadata(String metaId, Uint8List data);

  Future<Uint8List?> readMetadata(String metaId);

  Future<bool> deleteMetadata(String metaId);

  Future<void> performSnapshot(
    void Function(String docId, {Uint8List? data}) consumer, {
    bool loadDoc = false,
    int? loadOffset,
    int? loadSize,
  });

  Future<Index> getPrimaryIndex();
}
