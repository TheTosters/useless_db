enum GroupingType { or, and }

class Filter {
  final GroupingType type;
  final List<Filter> childFilters;
  final Map<String, MatchOperation> matchers;

  Filter({
    required this.matchers,
    this.type = GroupingType.or,
    this.childFilters = const <Filter>[],
  });

  bool predicate(String docId, Map<String, dynamic> content) {
    bool result = true;
    for (final entry in matchers.entries) {
      final value = entry.key == "_id" ? docId : content[entry.key];
      result &= entry.value(value);
      if (!result) {
        break;
      }
    }
    final iterator = childFilters.iterator;
    if (type == GroupingType.or) {
      //OR
      while (!result && iterator.moveNext()) {
        result |= iterator.current.predicate(docId, content);
      }
    } else {
      //AND
      while (result && iterator.moveNext()) {
        result &= iterator.current.predicate(docId, content);
      }
    }
    return result;
  }
}

abstract class MatchOperation {
  bool call(Comparable value);
}

class OpEq extends MatchOperation {
  final Comparable? value;

  OpEq(this.value);

  @override
  bool call(Comparable value) => value == this.value;
}

class OpNotEq extends MatchOperation {
  final Comparable? value;

  OpNotEq(this.value);

  @override
  bool call(Comparable value) => value != this.value;
}

class OpGt extends MatchOperation {
  final Comparable value;

  OpGt(this.value);

  @override
  bool call(Comparable value) => value.compareTo(this.value) > 0;
}

class OpGtEq extends MatchOperation {
  final Comparable value;

  OpGtEq(this.value);

  @override
  bool call(Comparable value) => value.compareTo(this.value) >= 0;
}

class OpLt extends MatchOperation {
  final Comparable value;

  OpLt(this.value);

  @override
  bool call(Comparable value) => value.compareTo(this.value) < 0;
}

class OpLtEq extends MatchOperation {
  final Comparable value;

  OpLtEq(this.value);

  @override
  bool call(Comparable value) => value.compareTo(this.value) <= 0;
}

class OpIn extends MatchOperation {
  final List<Object> values;

  OpIn(this.values);

  @override
  bool call(Comparable value) => values.contains(value);
}
