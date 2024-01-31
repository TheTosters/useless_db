import 'dart:convert';
import 'dart:typed_data';

import 'serialization_engine.dart';

class JsonEngine implements SerializationEngine {
  @override
  String get id => "Json:1.0.0";

  @override
  bool isCompatible(String engineId) {
    return engineId == id;
  }

  @override
  Uint8List encode(dynamic object) => utf8.encode(jsonEncode(object));

  @override
  dynamic decode(Uint8List data) => jsonDecode(utf8.decode(data));
}
