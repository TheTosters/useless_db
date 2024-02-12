import 'dart:typed_data';

import 'package:bson/bson.dart';

import 'serialization_engine.dart';

List<T> listFromBsonMap<T>(Map<String, dynamic>? map) {
  final result = <T>[];
  if (map != null) {
    for (int t = 0; t < map.length; t++) {
      final item = map["$t"];
      if (item != null) {
        result.add(item);
      }
    }
  }
  return result;
}

class BsonEngine implements SerializationEngine {
  @override
  String get id => "Bson:1.0.0";

  @override
  bool isCompatible(String engineId) {
    return engineId == id;
  }

  @override
  Uint8List encode(dynamic object) => BsonCodec.serialize(object).byteList;

  @override
  dynamic decode(Uint8List data) => BsonCodec.deserialize(BsonBinary.from(data));
}
