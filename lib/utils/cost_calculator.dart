import '../models/trip.dart';
import '../models/trip_member.dart';
import '../models/shared_expense.dart';

class CostCalculator {
  static Map<String, double> computeHouseCosts(
      Trip trip, List<TripMember> members) {
    if (trip.totalNights == 0 || trip.totalCost == 0) return {};
    final active = members.where((m) => !m.isDeactivated).toList();
    final nightly = trip.totalCost / trip.totalNights;
    final costs = <String, double>{for (final m in active) m.uid: 0.0};

    for (int night = 1; night <= trip.totalNights; night++) {
      final present = active.where((m) => m.nightsStayed >= night).toList();
      if (present.isEmpty) continue;
      final share = nightly / present.length;
      for (final m in present) {
        costs[m.uid] = costs[m.uid]! + share;
      }
    }
    return costs;
  }

  static Map<String, double> computeMemberCosts(
    Trip trip,
    List<TripMember> members,
    List<SharedExpense> expenses,
  ) {
    final houseCosts = computeHouseCosts(trip, members);
    final active = members.where((m) => !m.isDeactivated).toList();
    final expenseCosts = <String, double>{for (final m in active) m.uid: 0.0};

    for (final expense in expenses.where((e) => e.approved)) {
      if (expense.splitMethod == 'even') {
        if (active.isEmpty) continue;
        final share = expense.amount / active.length;
        for (final m in active) {
          expenseCosts[m.uid] = expenseCosts[m.uid]! + share;
        }
      } else if (expense.splitMethod == 'byNights') {
        final byNights =
            _splitByNights(expense.amount, trip.totalNights, active);
        for (final entry in byNights.entries) {
          expenseCosts[entry.key] =
              (expenseCosts[entry.key] ?? 0.0) + entry.value;
        }
      }
    }

    return {
      for (final m in active)
        m.uid: (houseCosts[m.uid] ?? 0.0) + (expenseCosts[m.uid] ?? 0.0)
    };
  }

  static Map<String, List<ExpenseShare>> computeExpenseSharePerSubmitter(
    Trip trip,
    List<TripMember> members,
    List<SharedExpense> expenses,
    String currentUid,
  ) {
    final active = members.where((m) => !m.isDeactivated).toList();
    final result = <String, List<ExpenseShare>>{};

    for (final expense in expenses.where((e) => e.approved)) {
      double myShare = 0.0;
      if (expense.splitMethod == 'even') {
        if (active.isNotEmpty) myShare = expense.amount / active.length;
      } else if (expense.splitMethod == 'byNights') {
        final shares = _splitByNights(expense.amount, trip.totalNights, active);
        myShare = shares[currentUid] ?? 0.0;
      }
      if (myShare < 0.005) continue;

      final submitterUid = expense.submittedByUid;
      result.putIfAbsent(submitterUid, () => []);
      result[submitterUid]!.add(ExpenseShare(
        expense: expense,
        myShare: myShare,
      ));
    }

    return result;
  }

  static Map<String, double> _splitByNights(
    double amount,
    int totalNights,
    List<TripMember> active,
  ) {
    if (totalNights == 0) return {};
    final nightly = amount / totalNights;
    final costs = <String, double>{for (final m in active) m.uid: 0.0};
    for (int night = 1; night <= totalNights; night++) {
      final present = active.where((m) => m.nightsStayed >= night).toList();
      if (present.isEmpty) continue;
      final share = nightly / present.length;
      for (final m in present) {
        costs[m.uid] = costs[m.uid]! + share;
      }
    }
    return costs;
  }
}

class ExpenseShare {
  final SharedExpense expense;
  final double myShare;

  const ExpenseShare({required this.expense, required this.myShare});
}
