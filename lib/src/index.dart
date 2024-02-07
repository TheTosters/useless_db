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

class SortedIndex implements Index {
  ///This is public but DO NOT MODIFY after creation. Bad things will happen!
  /// (keyName,ascending)
  final List<KeySortInfo> sortInfo;
  final _items = SplayTreeMap<_KeysWrapper, Set<String>>();

  ///this allow to get set from [_items] knowing only docId. We share this same set instance!
  final _docToSet = <String, Set<String>>{};

  @override
  final String name;

  SortedIndex(this.sortInfo, {this.name = "_unnamed_"});

  @override
  void deleteDocument(String docId) {
    final set = _docToSet.remove(docId);
    if (set != null) {
      set.remove(docId);
    }
  }

  @override
  void addOrUpdateDocument(String docId, Map<String, dynamic> content) {
    final wrapper = _KeysWrapper(content, sortInfo);
    var set = _docToSet[docId];
    if (set != null) {
      //this document is already in index, check if we need to move it somewhere else
      var iSet = _items[wrapper]!;
      if (!iSet.contains(docId)) {
        //using keys and values from content we got set from ordered items but this set doesn't
        //contain docId this mean data changes. We need to update entries
        set.remove(docId); //remove docId from old place in sorted _items
        _docToSet[docId] = iSet; //store mapping docId to new set which will contain docId
        iSet.add(docId); //in this place we will have now our docId
      }
    } else {
      //If we are here, this mean document is not present in index, we will add it
      //First check if there is a set for such wrapper since it might be
      var iSet = _items[wrapper];
      if (iSet != null) {
        //Yes it is, add new doc here and store reference to this set
        _docToSet[docId] = iSet;
        iSet.add(docId);
      } else {
        set = {docId}; //Important: use this same instance of set in both collections!
        _docToSet[docId] = set;
        _items[wrapper] = set;
      }
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
      final name = definition.removeAt(0);
      final sortInfo = definition
          .map((e) => (e.substring(0, e.length - 1), e.runes.last == 43))
          .toList(growable: false);
      result = SortedIndex(sortInfo, name: name);
    }

    return result;
  }
}
