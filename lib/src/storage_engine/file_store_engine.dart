import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';

import 'storage_engine.dart';

class FileStoreEngine implements StorageEngine {
  static const String docFileExtension = ".dat";
  static const String metaFileExtension = ".meta";
  static const String volatileFileExtension = ".volatile";
  String _workPath = "./";
  bool useRename = false;

  @override
  Future<void> close() async {
    await for (final f in Directory(join(_workPath, "meta")).list()) {
      if (f is File && f.path.endsWith(volatileFileExtension)) {
        print("Removing volatile data ${f.path}");
        await f.delete();
      }
    }
  }

  @override
  String get id => "FileStore:1.0.0";

  @override
  bool isCompatible(String engineId) => id == engineId;

  @override
  Future<FileStoreEngine> open(String workDir) async {
    return FileStoreEngine().._innerOpen(workDir);
  }

  void _innerOpen(String workDir) {
    _workPath = workDir;
    final metaDir = Directory(join(_workPath, "meta"));
    if (!metaDir.existsSync()) {
      metaDir.createSync();
    }
  }

  String _encodeIdToName(String docId, String extension) {
    StringBuffer encoded = StringBuffer();
    for (int i = 0; i < docId.length; i++) {
      String char = docId[i];
      if (char.runes.every((rune) =>
              (rune >= 48 && rune <= 57) || // 0-9
              (rune >= 65 && rune <= 90) || // A-Z
              (rune >= 97 && rune <= 122) ||
              rune == 45 || // -
              rune == 95 // _
          )) {
        encoded.write(char);
      } else {
        // Encode other characters as %XX where XX is the hexadecimal representation
        encoded.write(Uri.encodeQueryComponent(char));
      }
    }
    encoded.write(extension);
    return encoded.toString();
  }

  String _decodeNameToId(String path, String extension) {
    return Uri.decodeQueryComponent(basename(path.substring(0, path.length - extension.length)));
  }

  @override
  Future<void> writeMetadata(String metaId, Uint8List data) async {
    if (useRename) {
      final path = join(_workPath, _encodeIdToName(metaId, metaFileExtension));
      final tmpPath = "${path}_tmp";
      final file = File(tmpPath);
      file.writeAsBytesSync(data);
      try {
        File(path).deleteSync();
      } catch (e) {
        print("Can't remove file: $path, error: $e");
      }
      File(tmpPath).renameSync(path);
    } else {
      final file = File(join(_workPath, _encodeIdToName(metaId, metaFileExtension)));
      file.writeAsBytesSync(data);
    }
  }

  @override
  Future<Uint8List?> readMetadata(String metaId) async {
    final file = File(join(_workPath, _encodeIdToName(metaId, metaFileExtension)));
    Uint8List? result;
    if (file.existsSync()) {
      result = file.readAsBytesSync();
    }
    return result;
  }

  @override
  Future<Uint8List?> read(String docId) async {
    final file = File(join(_workPath, _encodeIdToName(docId, docFileExtension)));
    Uint8List? result;
    if (file.existsSync()) {
      result = file.readAsBytesSync();
    }
    return result;
  }

  @override
  Future<void> write(String docId, Uint8List data) async {
    if (useRename) {
      final path = join(_workPath, _encodeIdToName(docId, docFileExtension));
      final tmpPath = "${path}_tmp";
      final file = File(tmpPath);
      file.writeAsBytesSync(data);
      try {
        File(path).deleteSync();
      } catch (e) {
        print("Can't remove file: $path, error: $e");
      }
      File(tmpPath).renameSync(path);
    } else {
      final file = File(join(_workPath, _encodeIdToName(docId, docFileExtension)));
      file.writeAsBytesSync(data);
    }
  }

  @override
  Future<void> performSnapshot(
    void Function(String docId, {Uint8List? data}) consumer, {
    bool loadDoc = false,
    int? loadOffset,
    int? loadSize,
  }) async {
    if (loadDoc == false) {
      //Just docId
      await for (final f in Directory(_workPath).list()) {
        if (f is File && f.path.endsWith(docFileExtension)) {
          final docId = _decodeNameToId(f.path, docFileExtension);
          consumer(docId);
        }
      }
    } else {
      loadOffset ??= 0;
      await for (final f in Directory(_workPath).list()) {
        if (f is File && f.path.endsWith(docFileExtension)) {
          final docId = _decodeNameToId(f.path, docFileExtension);
          final sink = f.openSync();
          final bufferSize = loadSize ?? sink.lengthSync();
          final buffer = Uint8List(bufferSize);
          sink.readIntoSync(buffer, loadOffset);
          sink.closeSync();
          consumer(docId, data: buffer);
        }
      }
    }
  }

  Future<bool> _genericDelete(File file) async {
    bool result = false;
    if (file.existsSync()) {
      try {
        file.deleteSync();
        result = true;
      } catch (e) {
        print("$e");
      }
    }
    return result;
  }

  @override
  Future<bool> deleteDocument(String docId) async =>
      await _genericDelete(File(join(_workPath, _encodeIdToName(docId, docFileExtension))));

  @override
  Future<bool> deleteMetadata(String metaId) async =>
      await _genericDelete(File(join(_workPath, _encodeIdToName(metaId, metaFileExtension))));
}
