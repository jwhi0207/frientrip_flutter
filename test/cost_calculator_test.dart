import 'package:flutter_test/flutter_test.dart';
import 'package:frientrip/models/shared_expense.dart';
import 'package:frientrip/models/trip.dart';
import 'package:frientrip/models/trip_member.dart';
import 'package:frientrip/utils/cost_calculator.dart';

TripMember _member(String uid,
        {int nightsStayed = 0, bool deactivated = false}) =>
    TripMember(
      uid: uid,
      displayName: uid,
      email: '$uid@test.com',
      nightsStayed: nightsStayed,
      status: deactivated ? 'deactivated' : 'active',
    );

Trip _trip({int totalNights = 3, double totalCost = 300.0}) => Trip(
      id: 'trip1',
      name: 'Test Trip',
      ownerId: 'alice',
      totalNights: totalNights,
      totalCost: totalCost,
    );

SharedExpense _expense(
  String id, {
  double amount = 100.0,
  String splitMethod = 'even',
  bool approved = true,
  String submittedByUid = 'alice',
}) =>
    SharedExpense(
      id: id,
      description: id,
      amount: amount,
      splitMethod: splitMethod,
      submittedByUid: submittedByUid,
      submittedByName: submittedByUid,
      approved: approved,
      createdAt: DateTime(2025),
    );

void main() {
  group('CostCalculator.computeHouseCosts', () {
    test('returns empty map when totalNights is 0', () {
      final trip = _trip(totalNights: 0, totalCost: 300);
      final members = [_member('alice', nightsStayed: 3)];
      expect(CostCalculator.computeHouseCosts(trip, members), isEmpty);
    });

    test('returns empty map when totalCost is 0', () {
      final trip = _trip(totalNights: 3, totalCost: 0);
      final members = [_member('alice', nightsStayed: 3)];
      expect(CostCalculator.computeHouseCosts(trip, members), isEmpty);
    });

    test('splits evenly when all members stay all nights', () {
      final trip = _trip(totalNights: 3, totalCost: 300);
      final members = [
        _member('alice', nightsStayed: 3),
        _member('bob', nightsStayed: 3),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      expect(costs['alice'], closeTo(150.0, 0.01));
      expect(costs['bob'], closeTo(150.0, 0.01));
    });

    test('charges more to member who stays all nights', () {
      final trip = _trip(totalNights: 3, totalCost: 300);
      final members = [
        _member('alice', nightsStayed: 3),
        _member('bob', nightsStayed: 1),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      expect(costs['alice'], closeTo(250.0, 0.01));
      expect(costs['bob'], closeTo(50.0, 0.01));
    });

    test('excludes deactivated members', () {
      final trip = _trip(totalNights: 2, totalCost: 200);
      final members = [
        _member('alice', nightsStayed: 2),
        _member('bob', nightsStayed: 2, deactivated: true),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      expect(costs.containsKey('bob'), isFalse);
      expect(costs['alice'], closeTo(200.0, 0.01));
    });

    test('total cost is distributed fully across members', () {
      final trip = _trip(totalNights: 4, totalCost: 400);
      final members = [
        _member('alice', nightsStayed: 4),
        _member('bob', nightsStayed: 2),
        _member('carol', nightsStayed: 1),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      final total = costs.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(400.0, 0.01));
    });

    test('single member bears full cost', () {
      final trip = _trip(totalNights: 3, totalCost: 300);
      final members = [_member('alice', nightsStayed: 3)];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      expect(costs['alice'], closeTo(300.0, 0.01));
    });

    test('member staying zero nights pays nothing', () {
      final trip = _trip(totalNights: 3, totalCost: 300);
      final members = [
        _member('alice', nightsStayed: 3),
        _member('bob', nightsStayed: 0),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      expect(costs['alice'], closeTo(300.0, 0.01));
      expect(costs['bob'], closeTo(0.0, 0.01));
    });

    test('staggered nights across three members', () {
      // 3 nights, $300 → $100/night
      // night 1: alice+bob+carol → $33.33 each
      // night 2: alice+bob → $50 each
      // night 3: alice only → $100
      final trip = _trip(totalNights: 3, totalCost: 300);
      final members = [
        _member('alice', nightsStayed: 3),
        _member('bob', nightsStayed: 2),
        _member('carol', nightsStayed: 1),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      expect(costs['alice'], closeTo(183.33, 0.01));
      expect(costs['bob'], closeTo(83.33, 0.01));
      expect(costs['carol'], closeTo(33.33, 0.01));
    });

    test('returns empty map when no active members', () {
      final trip = _trip(totalNights: 3, totalCost: 300);
      final members = [
        _member('alice', nightsStayed: 3, deactivated: true),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      expect(costs, isEmpty);
    });

    test('handles all members staying fewer nights than trip total', () {
      // 5 nights, $500 → $100/night
      // nights 1-2: alice+bob → $50 each
      // nights 3-5: nobody present → skipped
      // Total distributed = $200, not $500
      // This is the expected behavior: cost for nights nobody attends is "lost"
      final trip = _trip(totalNights: 5, totalCost: 500);
      final members = [
        _member('alice', nightsStayed: 2),
        _member('bob', nightsStayed: 2),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      expect(costs['alice'], closeTo(100.0, 0.01));
      expect(costs['bob'], closeTo(100.0, 0.01));
      final total = costs.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(200.0, 0.01));
    });
  });

  group('CostCalculator.computeMemberCosts', () {
    test('even-split expense divided equally among active members', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [
        _member('alice', nightsStayed: 0),
        _member('bob', nightsStayed: 0),
      ];
      final expenses = [_expense('e1', amount: 100, splitMethod: 'even')];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs['alice'], closeTo(50.0, 0.01));
      expect(costs['bob'], closeTo(50.0, 0.01));
    });

    test('unapproved expenses are excluded', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [_member('alice'), _member('bob')];
      final expenses = [_expense('e1', amount: 100, approved: false)];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs['alice'], closeTo(0.0, 0.01));
      expect(costs['bob'], closeTo(0.0, 0.01));
    });

    test('byNights expense respects nightsStayed', () {
      final trip = _trip(totalNights: 2, totalCost: 0);
      final members = [
        _member('alice', nightsStayed: 2),
        _member('bob', nightsStayed: 1),
      ];
      final expenses = [_expense('e1', amount: 200, splitMethod: 'byNights')];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs['alice'], closeTo(150.0, 0.01));
      expect(costs['bob'], closeTo(50.0, 0.01));
    });

    test('house cost and expense cost are summed correctly', () {
      final trip = _trip(totalNights: 2, totalCost: 200);
      final members = [
        _member('alice', nightsStayed: 2),
        _member('bob', nightsStayed: 2),
      ];
      final expenses = [_expense('e1', amount: 100, splitMethod: 'even')];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs['alice'], closeTo(150.0, 0.01));
      expect(costs['bob'], closeTo(150.0, 0.01));
    });

    test('deactivated member excluded from all cost splits', () {
      final trip = _trip(totalNights: 2, totalCost: 200);
      final members = [
        _member('alice', nightsStayed: 2),
        _member('bob', nightsStayed: 2, deactivated: true),
      ];
      final expenses = [_expense('e1', amount: 100, splitMethod: 'even')];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs.containsKey('bob'), isFalse);
      expect(costs['alice'], closeTo(300.0, 0.01));
    });

    test('multiple expenses accumulate correctly', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [_member('alice'), _member('bob')];
      final expenses = [
        _expense('e1', amount: 60, splitMethod: 'even'),
        _expense('e2', amount: 40, splitMethod: 'even'),
      ];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs['alice'], closeTo(50.0, 0.01));
      expect(costs['bob'], closeTo(50.0, 0.01));
    });

    test('mix of even and byNights expenses', () {
      final trip = _trip(totalNights: 2, totalCost: 0);
      final members = [
        _member('alice', nightsStayed: 2),
        _member('bob', nightsStayed: 1),
      ];
      // even: 60 → 30 each
      // byNights: 100 / 2 nights = 50/night
      //   night 1: alice+bob → 25 each
      //   night 2: alice only → 50
      // alice total: 30 + 75 = 105
      // bob total: 30 + 25 = 55
      final expenses = [
        _expense('e1', amount: 60, splitMethod: 'even'),
        _expense('e2', amount: 100, splitMethod: 'byNights'),
      ];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs['alice'], closeTo(105.0, 0.01));
      expect(costs['bob'], closeTo(55.0, 0.01));
    });

    test('byNights expense with zero totalNights adds nothing', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [_member('alice', nightsStayed: 3)];
      final expenses = [_expense('e1', amount: 100, splitMethod: 'byNights')];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs['alice'], closeTo(0.0, 0.01));
    });

    test('total member costs equal house cost + expense total', () {
      final trip = _trip(totalNights: 3, totalCost: 300);
      final members = [
        _member('alice', nightsStayed: 3),
        _member('bob', nightsStayed: 3),
        _member('carol', nightsStayed: 3),
      ];
      final expenses = [
        _expense('e1', amount: 90, splitMethod: 'even'),
        _expense('e2', amount: 60, splitMethod: 'even'),
      ];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      final total = costs.values.fold(0.0, (a, b) => a + b);
      // 300 (house) + 90 + 60 (expenses) = 450
      expect(total, closeTo(450.0, 0.01));
    });

    test('single member bears all house and expense costs', () {
      final trip = _trip(totalNights: 2, totalCost: 200);
      final members = [_member('alice', nightsStayed: 2)];
      final expenses = [_expense('e1', amount: 50, splitMethod: 'even')];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      expect(costs['alice'], closeTo(250.0, 0.01));
    });
  });

  group('CostCalculator.computeExpenseSharePerSubmitter', () {
    test('groups even-split expenses by submitter', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [_member('alice'), _member('bob')];
      final expenses = [
        _expense('e1', amount: 100, submittedByUid: 'alice'),
        _expense('e2', amount: 60, submittedByUid: 'bob'),
      ];
      final shares = CostCalculator.computeExpenseSharePerSubmitter(
          trip, members, expenses, 'alice');
      // alice submitted e1 ($100 even → $50 each), alice's share = $50
      expect(shares['alice']!.length, 1);
      expect(shares['alice']![0].myShare, closeTo(50.0, 0.01));
      // bob submitted e2 ($60 even → $30 each), alice's share = $30
      expect(shares['bob']!.length, 1);
      expect(shares['bob']![0].myShare, closeTo(30.0, 0.01));
    });

    test('excludes unapproved expenses', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [_member('alice'), _member('bob')];
      final expenses = [
        _expense('e1', amount: 100, approved: false, submittedByUid: 'bob'),
      ];
      final shares = CostCalculator.computeExpenseSharePerSubmitter(
          trip, members, expenses, 'alice');
      expect(shares, isEmpty);
    });

    test('filters out near-zero shares', () {
      final trip = _trip(totalNights: 2, totalCost: 0);
      final members = [
        _member('alice', nightsStayed: 0),
        _member('bob', nightsStayed: 2),
      ];
      // byNights: alice has 0 nights, so her share is 0 → filtered out
      final expenses = [
        _expense('e1', amount: 100, splitMethod: 'byNights', submittedByUid: 'bob'),
      ];
      final shares = CostCalculator.computeExpenseSharePerSubmitter(
          trip, members, expenses, 'alice');
      expect(shares, isEmpty);
    });

    test('byNights split respects nightsStayed per submitter', () {
      final trip = _trip(totalNights: 2, totalCost: 0);
      final members = [
        _member('alice', nightsStayed: 2),
        _member('bob', nightsStayed: 1),
      ];
      // 200 / 2 nights = 100/night
      // night 1: alice+bob → 50 each
      // night 2: alice only → 100
      // bob's share = 50
      final expenses = [
        _expense('e1', amount: 200, splitMethod: 'byNights', submittedByUid: 'alice'),
      ];
      final shares = CostCalculator.computeExpenseSharePerSubmitter(
          trip, members, expenses, 'bob');
      expect(shares['alice']!.length, 1);
      expect(shares['alice']![0].myShare, closeTo(50.0, 0.01));
    });

    test('multiple expenses from same submitter are grouped', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [_member('alice'), _member('bob')];
      final expenses = [
        _expense('e1', amount: 80, submittedByUid: 'bob'),
        _expense('e2', amount: 40, submittedByUid: 'bob'),
      ];
      final shares = CostCalculator.computeExpenseSharePerSubmitter(
          trip, members, expenses, 'alice');
      expect(shares['bob']!.length, 2);
      final totalMyShare =
          shares['bob']!.fold(0.0, (s, e) => s + e.myShare);
      // (80/2) + (40/2) = 60
      expect(totalMyShare, closeTo(60.0, 0.01));
    });

    test('viewing own submissions shows own share', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [_member('alice'), _member('bob')];
      final expenses = [
        _expense('e1', amount: 100, submittedByUid: 'alice'),
      ];
      final shares = CostCalculator.computeExpenseSharePerSubmitter(
          trip, members, expenses, 'alice');
      // alice submitted it, alice's share of her own expense = $50
      expect(shares['alice']!.length, 1);
      expect(shares['alice']![0].myShare, closeTo(50.0, 0.01));
    });
  });

  group('Edge cases — rounding and large groups', () {
    test('three-way even split does not lose pennies', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = [_member('a'), _member('b'), _member('c')];
      final expenses = [_expense('e1', amount: 100, splitMethod: 'even')];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      final total = costs.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(100.0, 0.01));
    });

    test('seven members even split sums to original amount', () {
      final trip = _trip(totalNights: 0, totalCost: 0);
      final members = List.generate(7, (i) => _member('m$i'));
      final expenses = [_expense('e1', amount: 1000, splitMethod: 'even')];
      final costs = CostCalculator.computeMemberCosts(trip, members, expenses);
      final total = costs.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(1000.0, 0.01));
    });

    test('fractional cost and nights', () {
      final trip = _trip(totalNights: 3, totalCost: 99.99);
      final members = [
        _member('alice', nightsStayed: 3),
        _member('bob', nightsStayed: 1),
      ];
      final costs = CostCalculator.computeHouseCosts(trip, members);
      final total = costs.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(99.99, 0.01));
    });
  });
}
