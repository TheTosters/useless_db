import 'dart:collection';

///#1 key name, #2 true if ascending
typedef KeySortInfo = (String, bool);

class _KeysWrapper implements Comparable<_KeysWrapper> {
  final _keyValues = <String, dynamic>{};
  final List<KeySortInfo> sortInfo;

  _KeysWrapper(Map<String, dynamic> content, this.sortInfo) {
    for (final (key, _) in sortInfo) {
      _keyValues[key] = content[key];
    }
  }

  @override
  int compareTo(_KeysWrapper other) {
    for (final (key, ascending) in sortInfo) {
      final myValue = _keyValues[key] as Comparable;
      final otherValue = other._keyValues[key] as Comparable;
      final result = myValue.compareTo(otherValue);
      if (result != 0) {
        return ascending ? result : -result;
      }
    }
    return 0;
  }
}

abstract class Index {
  String get name;

  void deleteDocument(String docId);

  void addOrUpdateDocument(String docId, Map<String, dynamic> content);

  Future<List<String>> performSnapshot();

  Future<void> onCreated();

  Future<void> onDestroy();

  List<String> definition();
}

typedef WrapperAndSet = (_KeysWrapper, Set<String>);

class SortedIndex implements Index {
  ///This is public but DO NOT MODIFY after creation. Bad things will happen!
  /// (keyName,ascending)
  final List<KeySortInfo> sortInfo;
  final _items = SplayTreeMap<_KeysWrapper, Set<String>>();

  ///this allow to get set from [_items] knowing only docId. We share this same set instance!
  final _docIdToRef = <String, WrapperAndSet>{};

  @override
  final String name;

  SortedIndex(this.sortInfo, {this.name = "_unnamed_"});

  @override
  void deleteDocument(String docId) {
    final record = _docIdToRef.remove(docId);
    if (record != null) {
      final (keyWrapper, set) = record;
      set.remove(docId);
      if (set.isEmpty) {
        _items.remove(keyWrapper);
      }
    }
  }

  void _innerAddNew(_KeysWrapper wrapper, String docId, Map<String, dynamic> content) {
    var set = _items[wrapper];
    if (set != null) {
      set.add(docId);
    } else {
      set = {docId};
      _items[wrapper] = set;
    }
    _docIdToRef[docId] = (wrapper, set);
  }

  @override
  void addOrUpdateDocument(String docId, Map<String, dynamic> content) {
    final wrapper = _KeysWrapper(content, sortInfo);
    var record = _docIdToRef[docId];
    if (record != null) {
      //this document is already in index, check if we need to move it somewhere else
      final (keyWrapper, set) = record;
      if (keyWrapper.compareTo(wrapper) != 0) {
        //we need to move it
        final b = set.remove(docId);
        assert(b, "Document should be in this set!");
        if (set.isEmpty) {
          _items.remove(keyWrapper);
        }
        _innerAddNew(wrapper, docId, content);
      }
    } else {
      _innerAddNew(wrapper, docId, content);
    }
  }

  @override
  Future<List<String>> performSnapshot() async {
    final result = <String>[];
    for (final d in _items.values) {
      result.addAll(d);
    }
    return result;
  }

  @override
  Future<void> onCreated() async {
    //Currently nothing but who knows...
  }

  @override
  Future<void> onDestroy() async {
    //Currently nothing but who knows...
  }

  @override
  List<String> definition() =>
      ["SortedIndex", name, ...sortInfo.map((e) => "${e.$1}${e.$2 ? "+" : "-"}")];

  static Index? fromDefinition(List<String> definition) {
    Index? result;
    if (definition.length > 2 && definition.first == "SortedIndex") {
      definition.removeAt(0); //dispose type info "SortedIndex"
      final name = definition.removeAt(0);
      final sortInfo = definition
          .map((e) => (e.substring(0, e.length - 1), e.runes.last == 43))
          .toList(growable: false);
      result = SortedIndex(sortInfo, name: name);
    }

    return result;
  }
}
