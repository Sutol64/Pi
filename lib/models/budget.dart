class Budget {
  final int? id;
  final String type; // weekly|monthly|yearly stored in 'type' column
  final int accountId; // root or selected account id
  final String accountPath; // human readable path (Root > Child ...)
  final double amount;
  final String createdAt;
  final String updatedAt;
  final bool isActive;

  Budget({
    this.id,
    required this.type,
    required this.accountId,
    required this.accountPath,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'accountId': accountId,
        'accountPath': accountPath,
        'amount': amount,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as int?,
        type: (m['type'] as String?) ?? 'monthly',
        accountId: (m['accountId'] as int?) ?? 0,
        accountPath: (m['accountPath'] as String?) ?? '',
        amount: ((m['amount'] as num?)?.toDouble()) ?? 0.0,
        createdAt: (m['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
        updatedAt: (m['updatedAt'] as String?) ?? DateTime.now().toIso8601String(),
      );
}
