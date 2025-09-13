import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance_app_00/widgets/recurring_payment_form.dart';

void main() {
  group('RecurringPaymentForm', () {
    late Widget testWidget;

    setUp(() {
      testWidget = MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider(
            create: (_) => RecurringPaymentController(),
            child: const RecurringPaymentForm(
              accountId: 1,
              rootCategory: 'Expense',
            ),
          ),
        ),
      );
    });

    testWidgets('renders amount and date fields with suggestions when available', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Initial state
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Next Payment Date'), findsOneWidget);
      expect(find.text('Recalculate Suggestions'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing); // No suggestions yet

      // Get controller from provider
      final controller = Provider.of<RecurringPaymentController>(
        tester.element(find.byType(RecurringPaymentForm)),
      );

      controller.setTestSuggestions(
        amount: 123.45,
        nextDate: DateTime(2025, 10, 15),
        amountReason: 'Last two amounts identical',
        intervalReason: 'Last three intervals identical',
      );
      await tester.pump();

      // Verify suggestions appear
      expect(find.text('Suggested: \$123.45'), findsOneWidget);
      expect(find.text('Suggested: 2025-10-15'), findsOneWidget);
      expect(find.text('Last two amounts identical'), findsOneWidget);
      expect(find.text('Last three intervals identical'), findsOneWidget);
    });

    testWidgets('shows error when saving with empty fields', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      await tester.tap(find.text('Save Recurring Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Please fill in both amount and date'), findsOneWidget);
    });

    testWidgets('validates amount format', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final amountField = find.widgetWithText(TextField, 'Amount');
      await tester.enterText(amountField, 'invalid');
      await tester.tap(find.text('Save Recurring Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Error saving recurring payment'), findsOneWidget);
    });

    testWidgets('applies suggested amount when tapping suggestion chip', (WidgetTester tester) async {
      final controller = RecurringPaymentController();
      testWidget = MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider.value(
            value: controller,
            child: const RecurringPaymentForm(
              accountId: 1,
              rootCategory: 'Expense',
            ),
          ),
        ),
      );

      await tester.pumpWidget(testWidget);

      // Set up a suggestion
      controller.setTestSuggestions(
        amount: 123.45,
        amountReason: 'Last two amounts identical',
      );
      await tester.pump();

      expect(find.text('Suggested: \$123.45'), findsOneWidget);

      await tester.tap(find.byType(ActionChip).first);
      await tester.pump();

      final amountField = find.byType(TextField).first;
      expect((amountField.evaluate().first.widget as TextField).controller?.text, '123.45');
    });

    testWidgets('applies suggested date when tapping suggestion chip', (WidgetTester tester) async {
      final controller = RecurringPaymentController();
      testWidget = MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider.value(
            value: controller,
            child: const RecurringPaymentForm(
              accountId: 1,
              rootCategory: 'Expense',
            ),
          ),
        ),
      );

      await tester.pumpWidget(testWidget);

      // Set up a suggestion
      controller.setTestSuggestions(
        nextDate: DateTime(2025, 10, 15),
        intervalReason: 'Last three intervals identical',
      );
      await tester.pump();

      expect(find.text('Suggested: 2025-10-15'), findsOneWidget);

      await tester.tap(find.byType(ActionChip).last);
      await tester.pump();

      final dateField = find.byType(TextField).last;
      expect((dateField.evaluate().first.widget as TextField).controller?.text, '2025-10-15');
    });

    testWidgets('shows accessibility labels and hints', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final amountField = find.byType(Semantics).first;
      final amountSemantics = tester.getSemantics(amountField);
      expect(amountSemantics.label, contains('Recurring payment amount'));
      expect(amountSemantics.hint, contains('Enter the recurring payment amount'));

      final dateField = find.byType(Semantics).at(1);
      final dateSemantics = tester.getSemantics(dateField);
      expect(dateSemantics.label, contains('Next payment date'));
      expect(dateSemantics.hint, contains('Select the next payment date'));
    });
  });
}