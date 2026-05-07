import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shared_expense.dart';
import '../repositories/expense_repository.dart';

final expenseRepositoryProvider =
    Provider<ExpenseRepository>((_) => ExpenseRepository());

final expensesProvider =
    StreamProvider.family<List<SharedExpense>, String>((ref, tripId) {
  return ref.watch(expenseRepositoryProvider).getExpensesStream(tripId);
});
