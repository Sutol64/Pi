import 'package:flutter/material.dart';
import 'package:personal_finance_app_00/recurring_payment_api.dart';
import 'package:personal_finance_app_00/recurring_payment_service.dart';
import 'package:personal_finance_app_00/database_helper.dart';
import 'dart:convert';

class RecurringPanel extends StatefulWidget {
  final bool expandAll; // Added for consistency, though not directly used for expansion here
  const RecurringPanel({super.key, this.expandAll = false});

  @override
  State<RecurringPanel> createState() => _RecurringPanelState();
}

class _RecurringPanelState extends State<RecurringPanel> {
  Future<List<Map<String, dynamic>>>? _computedPaymentsFuture;
  late final RecurringPaymentApi _recurringApi;

  @override
  void initState() {
    super.initState();
    _recurringApi = RecurringPaymentApi(RecurringPaymentService(DatabaseHelper.instance));
    _loadRecurringPayments();
  }

  Future<void> _loadRecurringPayments() async {
    print('Fetching all recurring payments...');
    try {
      final paymentsJson = await _recurringApi.fetchAll();
      print('Received payments JSON: $paymentsJson');

      final payments = List<Map<String, dynamic>>.from(jsonDecode(paymentsJson));
      print('Decoded payments: $payments');

      Future<List<Map<String, dynamic>>> createComputedFuture() async {
        print('Creating computed future for ${payments.length} payments');
        return Future.wait(payments.map((p) async {
          print('Recomputing for account: ${p['accountId']}');
          final resultJson = await _recurringApi.recompute(p['accountId'] as String);
          final result = jsonDecode(resultJson) as Map<String, dynamic>? ?? <String, dynamic>{};
          print('Recompute result: $result');
          return {
            'payment': p,
            'computed': result,
          };
        }).toList());
      }

      if (mounted) {
        setState(() {
          _computedPaymentsFuture = createComputedFuture();
        });
        print('State updated with ${payments.length} payments');
      }
    } catch (e, stackTrace) {
      print('Error loading recurring payments: $e');
      print('Stack trace: $stackTrace');
       if (mounted) {
        setState(() {
          _computedPaymentsFuture = Future.value([]); // Set to empty list on error
        });
      }
    }
  }

  Future<void> _deleteRecurringPayment(String accountId) async {
    try {
      await _recurringApi.delete(accountId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring payment deleted.')),
      );
      _loadRecurringPayments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete recurring payment: $e')),
      );
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year.toString().padLeft(4, "0")}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _computedPaymentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                 return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('No recurring payments saved.')),
                );
              }

              final combinedList = snapshot.data!;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Account')),
                    DataColumn(label: Text('Amount'), numeric: true),
                    DataColumn(label: Text('Next Date')),
                    DataColumn(label: Text('Last Date')),
                    DataColumn(label: Text('Interval')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('')), // For delete button
                  ],
                  rows: List.generate(combinedList.length, (i) {
                    final combined = combinedList[i];
                    final p = combined['payment'] as Map<String, dynamic>;
                    final computed = combined['computed'] as Map<String, dynamic>;
                    final accountId = p['accountId'] as String;
                    final amount = computed['calculatedAmount']?.toStringAsFixed(2) ?? '--';
                    final interval = computed['intervalDays']?.toString() ?? '--';
                    final nextOccurrence = _formatDate(computed['nextOccurrence'] as String?);
                    final lastOccurrence = _formatDate(computed['lastOccurrence'] as String?);
                    final method = computed['method'] ?? '--';
                    return DataRow(
                      cells: [
                        DataCell(Tooltip(message: accountId, child: Text(accountId, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(amount)),
                        DataCell(Text(nextOccurrence)),
                        DataCell(Text(lastOccurrence)),
                        DataCell(Text(interval)),
                        DataCell(Chip(label: Text(method))),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteRecurringPayment(accountId),
                            tooltip: 'Delete Recurring Payment',
                            splashRadius: 20,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}