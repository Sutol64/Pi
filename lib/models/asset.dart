
import 'package:equatable/equatable.dart';

class Asset extends Equatable {
  final String id;
  final String name;
  final double investmentAmount;
  final double withdrawalAmount;
  final double currentValue;
  final double absoluteReturn;
  final List<Asset> children;
  final bool isExpanded;

  const Asset({
    required this.id,
    required this.name,
    this.investmentAmount = 0.0,
    this.withdrawalAmount = 0.0,
    this.currentValue = 0.0,
    this.absoluteReturn = 0.0,
    this.children = const [],
    this.isExpanded = false,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        investmentAmount,
        withdrawalAmount,
        currentValue,
        absoluteReturn,
        children,
        isExpanded,
      ];

  Asset copyWith({
    String? id,
    String? name,
    double? investmentAmount,
    double? withdrawalAmount,
    double? currentValue,
    double? absoluteReturn,
    List<Asset>? children,
    bool? isExpanded,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      investmentAmount: investmentAmount ?? this.investmentAmount,
      withdrawalAmount: withdrawalAmount ?? this.withdrawalAmount,
      currentValue: currentValue ?? this.currentValue,
      absoluteReturn: absoluteReturn ?? this.absoluteReturn,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}
