import 'dart:convert';
import 'dart:typed_data';

import 'serialization_engine.dart';

class JsonEngine implements SerializationEngine {
  static const String _dateDecorator = "@date@:";

  @override
  String get id => "Json:1.0.0";

  @override
  bool isCompatible(String engineId) {
    return engineId == id;
  }

  @override
  Uint8List encode(dynamic object) => utf8.encode(jsonEncode(object, toEncodable: _innerEncode));

  dynamic _innerEncode(dynamic item) {
    if (item is DateTime) {
      return "$_dateDecorator${item.toIso8601String()}";
    }
    return item;
  }

  @override
  dynamic decode(Uint8List data) => jsonDecode(utf8.decode(data), reviver: _innerDecoder);

  Object? _innerDecoder(Object? key, Object? value) {
    if ((value is String) && (value.startsWith(_dateDecorator))) {
      value = DateTime.parse(value.substring(_dateDecorator.length));
    }
    return value;
  }
}
