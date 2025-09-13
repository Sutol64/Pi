class Account {
  final int? id;
  final String name;
  final int? parentId;
  final String accountType;
  final double balance;

  Account({
    this.id,
    required this.name,
    this.parentId,
    required this.accountType,
    this.balance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'account_type': accountType,
      'balance': balance,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      parentId: map['parent_id'],
      accountType: map['account_type'],
      balance: map['balance'],
    );
  }
}

class Transaction {
  final int? id;
  final DateTime date;
  final String description;
  final List<TransactionLine> lines;

  Transaction({
    this.id,
    required this.date,
    required this.description,
    this.lines = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      date: DateTime.parse(map['date']),
      description: map['description'],
    );
  }
}

class TransactionLine {
  final int? id;
  final int transactionId;
  final String account;
  final double debit;
  final double credit;

  TransactionLine({
    this.id,
    required this.transactionId,
    required this.account,
    this.debit = 0.0,
    this.credit = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'account': account,
      'debit': debit,
      'credit': credit,
    };
  }

  factory TransactionLine.fromMap(Map<String, dynamic> map) {
    return TransactionLine(
      id: map['id'],
      transactionId: map['transaction_id'],
      account: map['account'],
      debit: map['debit'],
      credit: map['credit'],
    );
  }
}

class Budget {
  final int? id;
  final String type;
  final int accountId;
  final String accountPath;
  final double amount;
  final String createdAt;
  final String updatedAt;

  Budget({
    this.id,
    required this.type,
    required this.accountId,
    required this.accountPath,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'accountId': accountId,
      'accountPath': accountPath,
      'amount': amount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      type: map['type'],
      accountId: map['accountId'],
      accountPath: map['accountPath'],
      amount: map['amount'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
}

enum RootCategory {
  income,
  expense,
  asset,
  liability;

  String get displayName {
    switch (this) {
      case RootCategory.income:
        return 'Income';
      case RootCategory.expense:
        return 'Expense';
      case RootCategory.asset:
        return 'Assets';
      case RootCategory.liability:
        return 'Liabilities';
    }
  }
}

