import 'package:flutter_test/flutter_test.dart';
import 'package:frientrip/models/shared_expense.dart';
import 'package:frientrip/models/trip.dart';
import 'package:frientrip/models/trip_member.dart';
import 'package:frientrip/utils/cost_calculator.dart';

TripMember _member(String uid, {int nightsStayed = 0, bool deactivated = false}) =>
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
}) =>
    SharedExpense(
      id: id,
      description: id,
      amount: amount,
      splitMethod: splitMethod,
      submittedByUid: 'alice',
      submittedByName: 'alice',
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
      // alice stays all 3, bob only stays 1
      // night 1: alice+bob share 100 → 50 each
      // night 2: only alice → 100
      // night 3: only alice → 100
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
      // 200 / 2 nights = 100/night
      // night 1: alice+bob → 50 each
      // night 2: only alice → 100
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
      // house: 100 each, expense: 50 each
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
  });
}
