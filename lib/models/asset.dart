import 'package:equatable/equatable.dart';

class Asset extends Equatable {
  final int id;
  final String name;
  final int? parentId;
  final double value;
  final List<Asset> children;
  final bool isExpanded;

  const Asset({
    required this.id,
    required this.name,
    this.parentId,
    this.value = 0.0,
    this.children = const [],
    this.isExpanded = false,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        parentId,
        value,
        children,
        isExpanded,
      ];

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as int,
      name: map['name'] as String,
      parentId: map['parent_id'] as int?,
      value: (map['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'balance': value,
    };
  }

  Asset copyWith({
    int? id,
    String? name,
    int? parentId,
    double? value,
    List<Asset>? children,
    bool? isExpanded,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      value: value ?? this.value,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}
