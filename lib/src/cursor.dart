import 'package:useless_db/src/collection.dart';

import 'filter.dart';
import 'index.dart';

class Cursor {
  final Index index;
  final Filter? filter;
  final Set<String>? selector;
  final Collection collection;
  List<String> _snapshot = <String>[];
  int _keyIndex = -1;

  Cursor({required this.collection, required this.index, this.filter, this.selector});

  Future<void> reset() async {
    _snapshot = await index.performSnapshot();
    _keyIndex = -1;
  }

  Future<int> get length async => _snapshot.length;

  Future<(String?, Map<String, dynamic>?)> getNextDocument() async {
    String? docId;
    Map<String, dynamic>? data;
    bool accepted = false;
    if (_keyIndex < _snapshot.length) {
      do {
        _keyIndex++;
        docId = _snapshot[_keyIndex];
        data = await collection.getDocument(docId);
        if (data != null) {
          accepted = filter?.predicate(docId, data) ?? true;
        }
      } while (_keyIndex < _snapshot.length && !accepted);
      final innerSelector = selector;
      if (accepted && innerSelector != null && data != null) {
        data = Map.fromIterable(data.entries.where((entry) => innerSelector.contains(entry.key)));
      }
    }
    return accepted ? (docId, data) : (null, null);
  }

  Future<String?> deleteNextDocument() async {
    String? docId;
    bool accepted = false;
    if (_keyIndex < _snapshot.length) {
      do {
        _keyIndex++;
        docId = _snapshot[_keyIndex];
        final data = await collection.getDocument(docId);
        if (data != null) {
          accepted = filter?.predicate(docId, data) ?? true;
        }
      } while (_keyIndex < _snapshot.length && !accepted);
      if (accepted) {
        await collection.removeDocument(docId);
      }
    }
    return accepted ? docId : null;
  }
}
