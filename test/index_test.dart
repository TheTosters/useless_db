import 'package:test/test.dart';
import 'package:useless_db/src/index.dart';

void main() {
  group('Index test', () {
    test('Single Key sort - ascending', () async {
      final index = Index([("id", true)]);
      final expectedOrder = <String>[];
      for (int t = 0; t < 10; t++) {
        index.addOrUpdateDocument("$t", {"id": t});
        expectedOrder.add("$t");
      }
      final list = await index.performSnapshot();
      expect(list, equals(expectedOrder));
    });

    test('Single Key sort - descending', () async {
      final index = Index([("id", false)]);
      final expectedOrder = <String>[];
      for (int t = 0; t < 10; t++) {
        index.addOrUpdateDocument("$t", {"id": t});
        expectedOrder.add("${9 - t}");
      }
      final list = await index.performSnapshot();
      expect(list, equals(expectedOrder));
    });

    test('Multi Key sort', () async {
      final index = Index([("a", true), ("b", false)]);
      final expectedOrder = <String>["1-2", "1-1", "3-1", "4-8", "4-5"];

      index.addOrUpdateDocument("1-1", {"a": 1, "b": 1});
      index.addOrUpdateDocument("1-2", {"a": 1, "b": 2});
      index.addOrUpdateDocument("3-1", {"a": 3, "b": 1});
      index.addOrUpdateDocument("4-8", {"a": 4, "b": 8});
      index.addOrUpdateDocument("4-5", {"a": 4, "b": 5});

      final list = await index.performSnapshot();
      expect(list, equals(expectedOrder));
    });

    test('Single Key sort - deletion', () async {
      final index = Index([("id", true)]);
      final expectedOrder = <String>["0", "1", "2", "5"];
      for (int t = 0; t < 6; t++) {
        index.addOrUpdateDocument("$t", {"id": t});
      }
      index.deleteDocument("3");
      index.deleteDocument("4");
      final list = await index.performSnapshot();
      expect(list, equals(expectedOrder));
    });

    test('Single Key sort - deletion and reinsert', () async {
      final index = Index([("id", true)]);
      final expectedOrder = <String>["0", "1", "2", "3", "4", "5"];
      for (int t = 0; t < 6; t++) {
        index.addOrUpdateDocument("$t", {"id": t});
      }
      index.deleteDocument("3");
      index.deleteDocument("4");
      index.addOrUpdateDocument("3", {"id": 3});
      index.addOrUpdateDocument("4", {"id": 4});
      final list = await index.performSnapshot();
      expect(list, equals(expectedOrder));
    });

    test('Multiple insert with same index value', () async {
      final index = Index([("a", true), ("b", false)]);
      final expectedOrder = <String>["1-2", "1-1", "1-1a", "1-1b", "4-8"];

      index.addOrUpdateDocument("1-1", {"a": 1, "b": 1});
      index.addOrUpdateDocument("1-2", {"a": 1, "b": 2});
      index.addOrUpdateDocument("1-1a", {"a": 1, "b": 1});
      index.addOrUpdateDocument("4-8", {"a": 4, "b": 8});
      index.addOrUpdateDocument("1-1b", {"a": 1, "b": 1});

      final list = await index.performSnapshot();
      expect(list, equals(expectedOrder));
    });

    test('Index on DateTime - ascending', () async {
      final index = Index([("date", true)]);
      final expectedOrder = <String>["-1d", "-10m", "d", "+20m", "+1d"];
      final d = DateTime(1990, 4, 12, 0, 0, 0);
      index.addOrUpdateDocument("d", {"date": d});
      index.addOrUpdateDocument("-1d", {"date": d.subtract(Duration(days: 1))});
      index.addOrUpdateDocument("+1d", {"date": d.add(Duration(days: 1))});
      index.addOrUpdateDocument("-10m", {"date": d.subtract(Duration(minutes: 10))});
      index.addOrUpdateDocument("+20m", {"date": d.add(Duration(minutes: 20))});

      final list = await index.performSnapshot();
      expect(list, equals(expectedOrder));
    });
  });

}
