import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../recurring_payments_logic_auto.dart';
import '../database_helper.dart';
import '../recurring_computation.dart';

class RecurringPaymentController extends ChangeNotifier {
  final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final _dateFormat = DateFormat('yyyy-MM-dd');
  
  double? _suggestedAmount;
  DateTime? _suggestedNextDate;
  String? _amountReason;
  String? _intervalReason;
  bool _isLoading = false;

  // For testing purposes only
  @visibleForTesting
  void setTestSuggestions({
    double? amount,
    DateTime? nextDate,
    String? amountReason,
    String? intervalReason,
  }) {
    _suggestedAmount = amount;
    _suggestedNextDate = nextDate;
    _amountReason = amountReason;
    _intervalReason = intervalReason;
    notifyListeners();
  }
  
  String? get suggestedAmountText => _suggestedAmount != null 
    ? _currencyFormat.format(_suggestedAmount)
    : null;
  String? get suggestedNextDateText => _suggestedNextDate != null
    ? _dateFormat.format(_suggestedNextDate!)
    : null;
  String? get amountReason => _amountReason;
  String? get intervalReason => _intervalReason;
  bool get isLoading => _isLoading;

  Future<void> recalculateSuggestions(int accountId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = DatabaseHelper.instance;
      final accountPath = await db.buildAccountPath(accountId);
      final dbTransactions = await db.getTransactionsForRecurringCalculation(accountPath);
      
      if (dbTransactions.isEmpty) {
        _suggestedAmount = null;
        _suggestedNextDate = null;
        _amountReason = 'No transaction history found';
        _intervalReason = 'No transaction history found';
        return;
      }

      // Convert database transactions to the auto-calculation format
      final transactions = dbTransactions.map((t) => Transaction(
        accountId: accountPath,
        amount: t.amount,
        postedAt: t.postedAt,
      )).toList();

      final suggestion = await getSuggestedRecurringAmountAndDate(
        accountPath,
        transactions,
        now: DateTime.now(),
      );

      _suggestedAmount = suggestion.amount;
      _suggestedNextDate = suggestion.nextDate;
      _amountReason = suggestion.amountReason;
      _intervalReason = suggestion.intervalReason;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class RecurringPaymentForm extends StatefulWidget {
  final int accountId;
  final String rootCategory;
  final Function(Map<String, dynamic>)? onSave;
  
  const RecurringPaymentForm({
    super.key,
    required this.accountId,
    required this.rootCategory,
    this.onSave,
  });

  @override
  State<RecurringPaymentForm> createState() => _RecurringPaymentFormState();
}

class _RecurringPaymentFormState extends State<RecurringPaymentForm> {
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    // Initialize suggestions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecurringPaymentController>().recalculateSuggestions(widget.accountId);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecurringPaymentController>(
      builder: (context, controller, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Recurring payment amount field',
              hint: controller.amountReason ?? 'Enter the recurring payment amount',
              child: TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$',
                  suffixIcon: controller.suggestedAmountText != null
                    ? Semantics(
                        button: true,
                        label: 'Use suggested amount ${controller.suggestedAmountText}',
                        hint: controller.amountReason ?? 'Suggested based on history',
                        child: Tooltip(
                          message: controller.amountReason ?? 'Suggested based on history',
                          child: ActionChip(
                            label: Text('Suggested: ${controller.suggestedAmountText}'),
                            onPressed: () {
                              _amountController.text = controller.suggestedAmountText!
                                  .replaceAll('\$', '')
                                  .trim();
                            },
                          ),
                        ),
                      )
                    : null,
                  helperText: controller.amountReason ?? 'Enter the recurring payment amount',
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Next payment date field',
              hint: controller.intervalReason ?? 'Select the next payment date',
              child: TextField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Next Payment Date',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Open date picker',
                        child: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(context),
                          tooltip: 'Select date',
                        ),
                      ),
                      if (controller.suggestedNextDateText != null)
                        Semantics(
                          button: true,
                          label: 'Use suggested date ${controller.suggestedNextDateText}',
                          hint: controller.intervalReason ?? 'Suggested based on history',
                          child: Tooltip(
                            message: controller.intervalReason ?? 'Suggested based on history',
                            child: ActionChip(
                              label: Text('Suggested: ${controller.suggestedNextDateText}'),
                              onPressed: () {
                                _dateController.text = controller.suggestedNextDateText!;
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  helperText: controller.intervalReason ?? 'Select the next payment date',
                  helperMaxLines: 2,
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (controller.isLoading)
                  const CircularProgressIndicator()
                else
                  Semantics(
                    button: true,
                    label: 'Recalculate payment suggestions',
                    hint: 'Update amount and date suggestions based on recent transactions',
                    child: TextButton.icon(
                      onPressed: () => controller.recalculateSuggestions(widget.accountId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recalculate Suggestions'),
                    ),
                  ),
                Semantics(
                  button: true,
                  label: 'Save recurring payment',
                  hint: 'Save the entered amount and date as a recurring payment',
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_amountController.text.isEmpty || _dateController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Semantics(
                              label: 'Missing required fields',
                              child: const Text('Please fill in both amount and date'),
                            ),
                          ),
                        );
                        return;
                      }
                      
                      try {
                        // Validate input formats before saving
                        final amount = double.parse(_amountController.text.replaceAll(RegExp(r'[^\d.]'), ''));
                        final nextDate = DateFormat('yyyy-MM-dd').parse(_dateController.text);
                        final intervalDays = nextDate.difference(DateTime.now()).inDays;

                        final recurringPayment = await DatabaseHelper.instance.computeRecurringPayment(
                          accountId: widget.accountId,
                          rootCategory: widget.rootCategory,
                          method: ComputationMethod.manual,
                          manualAmount: amount,
                          manualIntervalDays: intervalDays,
                        );

                        if (recurringPayment != null && widget.onSave != null) {
                          widget.onSave!(recurringPayment);
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Semantics(
                              label: 'Payment saved',
                              child: const Text('Recurring payment saved successfully'),
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Semantics(
                              label: 'Error saving payment',
                              child: Text('Error saving recurring payment: ${e.toString()}'),
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Save Recurring Payment'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}