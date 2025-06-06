import 'package:cloud_firestore/cloud_firestore.dart';

class RecordCategoryModel {
  final String id; // 고유 ID
  final String zone; // 기록 분류
  final List<String> units; // 기록 구분 목록
  final String color; // 색상 (Hex 코드 형식)

  RecordCategoryModel({
    required this.id,
    required this.zone,
    required this.units,
    required this.color,
  });

  factory RecordCategoryModel.fromJson(Map<String, dynamic> json) {
    return RecordCategoryModel(
      id: json['id'] as String,
      zone: json['zone'] as String,
      units: List<String>.from(json['units'] as List<dynamic>),
      color: json['color'] as String,
    );
  }

  factory RecordCategoryModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RecordCategoryModel(
      id: doc.id,
      zone: data['zone'] as String,
      units: List<String>.from(data['units'] as List<dynamic>),
      color: data['color'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'zone': zone,
      'units': units,
      'color': color,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'zone': zone,
      'units': units,
      'color': color,
    };
  }
}
