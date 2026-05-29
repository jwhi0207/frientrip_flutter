import 'package:flutter_test/flutter_test.dart';
import 'package:frientrip/models/supply_item.dart';

SupplyItem _item({String quantity = '', List<String> claimedByUids = const [], String claimedByName = ''}) =>
    SupplyItem(
      id: 'item1',
      name: 'Chips',
      quantity: quantity,
      claimedByUids: claimedByUids,
      claimedByName: claimedByName,
    );

void main() {
  group('SupplyItem.claimEntries', () {
    test('returns empty map for plain quantity string', () {
      expect(_item(quantity: '3 bags').claimEntries, isEmpty);
    });

    test('parses single claim entry', () {
      expect(_item(quantity: 'Alice=2').claimEntries, {'Alice': '2'});
    });

    test('parses multiple claim entries', () {
      expect(
        _item(quantity: 'Alice=2|Bob=3').claimEntries,
        {'Alice': '2', 'Bob': '3'},
      );
    });

    test('ignores malformed parts without =', () {
      expect(_item(quantity: 'Alice=2|garbage|Bob=1').claimEntries, {'Alice': '2', 'Bob': '1'});
    });

    test('returns empty map for empty quantity', () {
      expect(_item(quantity: '').claimEntries, isEmpty);
    });
  });

  group('SupplyItem.displayQuantity', () {
    test('returns raw quantity when no claim encoding', () {
      expect(_item(quantity: '5 cans').displayQuantity, '5 cans');
    });

    test('formats claims as Name: qty pairs', () {
      final display = _item(quantity: 'Alice=2|Bob=3').displayQuantity;
      expect(display, contains('Alice: 2'));
      expect(display, contains('Bob: 3'));
    });
  });

  group('SupplyItem.claimedNames', () {
    test('returns empty list when claimedByName is empty', () {
      expect(_item(claimedByName: '').claimedNames, isEmpty);
    });

    test('parses comma-separated names', () {
      expect(_item(claimedByName: 'Alice,Bob').claimedNames, ['Alice', 'Bob']);
    });

    test('trims whitespace from names', () {
      expect(_item(claimedByName: 'Alice, Bob').claimedNames, ['Alice', 'Bob']);
    });

    test('filters empty segments', () {
      expect(_item(claimedByName: 'Alice,,Bob').claimedNames, ['Alice', 'Bob']);
    });
  });

  group('SupplyItem.isClaimed', () {
    test('false when claimedByUids is empty', () {
      expect(_item().isClaimed, isFalse);
    });

    test('true when claimedByUids is non-empty', () {
      expect(_item(claimedByUids: ['uid1']).isClaimed, isTrue);
    });
  });

  group('SupplyItem.quantityForPerson', () {
    test('returns quantity for known person', () {
      expect(_item(quantity: 'Alice=5').quantityForPerson('Alice'), '5');
    });

    test('returns null for unknown person', () {
      expect(_item(quantity: 'Alice=5').quantityForPerson('Bob'), isNull);
    });

    test('returns null when no claim encoding', () {
      expect(_item(quantity: '3 bags').quantityForPerson('Alice'), isNull);
    });
  });

  group('SupplyItem.addClaim', () {
    test('adds uid, name and quantity to unclaimed item', () {
      final result = _item(quantity: '').addClaim('uid1', 'Alice', '2');
      expect(result.claimedByUids, ['uid1']);
      expect(result.claimedNames, ['Alice']);
      expect(result.claimEntries['Alice'], '2');
    });

    test('appends to existing claims', () {
      final existing = _item(
        quantity: 'Alice=2',
        claimedByUids: ['uid1'],
        claimedByName: 'Alice',
      );
      final result = existing.addClaim('uid2', 'Bob', '3');
      expect(result.claimedByUids, containsAll(['uid1', 'uid2']));
      expect(result.claimEntries, {'Alice': '2', 'Bob': '3'});
    });

    test('preserves other fields unchanged', () {
      final original = SupplyItem(id: 'x', name: 'Soda', category: 'drinks', sortOrder: 5);
      final result = original.addClaim('uid1', 'Alice', '1');
      expect(result.id, 'x');
      expect(result.name, 'Soda');
      expect(result.category, 'drinks');
      expect(result.sortOrder, 5);
    });
  });

  group('SupplyItem.removeClaim', () {
    test('removes uid, name and quantity entry', () {
      final item = _item(
        quantity: 'Alice=2|Bob=3',
        claimedByUids: ['uid1', 'uid2'],
        claimedByName: 'Alice,Bob',
      );
      final result = item.removeClaim('uid1', 'Alice');
      expect(result.claimedByUids, ['uid2']);
      expect(result.claimedNames, ['Bob']);
      expect(result.claimEntries, {'Bob': '3'});
    });

    test('quantity becomes empty string when last claim removed', () {
      final item = _item(
        quantity: 'Alice=2',
        claimedByUids: ['uid1'],
        claimedByName: 'Alice',
      );
      final result = item.removeClaim('uid1', 'Alice');
      expect(result.quantity, '');
      expect(result.isClaimed, isFalse);
    });

    test('removing non-existent uid is a no-op on uids list', () {
      final item = _item(claimedByUids: ['uid1'], claimedByName: 'Alice');
      final result = item.removeClaim('uid_unknown', 'Unknown');
      expect(result.claimedByUids, ['uid1']);
    });
  });
}
