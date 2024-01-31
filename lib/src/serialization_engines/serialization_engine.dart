import 'dart:typed_data';

abstract class SerializationEngine {
  String get id;

  bool isCompatible(String engineId);

  Uint8List encode(dynamic object);

  dynamic decode(Uint8List data);
}
