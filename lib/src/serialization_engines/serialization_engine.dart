import 'dart:typed_data';

import '../database_engine.dart';

abstract class SerializationEngine extends DatabaseEngine {
  String get id;

  bool isCompatible(String engineId);

  Uint8List encode(dynamic object);

  dynamic decode(Uint8List data);
}
