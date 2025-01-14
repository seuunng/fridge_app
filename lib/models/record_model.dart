import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecordModel {
  String id;
  DateTime date;
  String zone;
  String color;
  List<RecordDetail> records;
  String userId; // 추가된 userId 필드

  RecordModel({
    required this.id,
    required this.date,
    required this.zone,
    required this.color,
    required this.records,
    required this.userId, // 생성자에 추가
  });

  factory RecordModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return RecordModel(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      zone: data['zone'] ?? '',
      color: data['color'] ?? '',
      records: (data['records'] as List)
          .map((item) => RecordDetail.fromMap(item))
          .toList(),
      userId: data['userId'] ?? '', // userId 추가
    );
  }

  factory RecordModel.fromJson(Map<String, dynamic> json,
      {required String id}) {
    List<RecordDetail> recordDetails = [];
    if (json['records'] != null && json['records'] is List) {
      recordDetails = (json['records'] as List<dynamic>)
          .map((e) => RecordDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return RecordModel(
      id: id,
      date: json['date'] != null
          ? (json['date'] as Timestamp).toDate()
          : DateTime.now(), // 기본값 설정
      zone: json['zone'] ?? '미지정',
      color: json['color'] ?? '#000000',
      records: (json['records'] != null)
          ? (json['records'] as List<dynamic>)
          .map((e) => RecordDetail.fromJson(e))
          .toList()
          : [],
      userId: json['userId'] ?? '', // userId 추가
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'zone': zone,
      'color': color,
      'records': records.map((item) => item.toMap()).toList(),
      'userId': userId,
    };
  }

  Color get colorAsColor => Color(int.parse(color.replaceFirst('#', '0xff')));

  @override
  String toString() {
    return 'RecordModel{id: $id, zone: $zone, date: $date, color: $color, records: $records}';
  }
}

class RecordDetail {
  String unit;
  String contents;
  List<String> images;

  RecordDetail({
    required this.unit,
    required this.contents,
    required this.images,
  });

  factory RecordDetail.fromMap(Map<String, dynamic> data) {
    return RecordDetail(
      unit: data['unit'] ?? '',
      contents: data['contents'] ?? '',
      images: List<String>.from(data['images'] ?? []),
    );
  }

  factory RecordDetail.fromJson(Map<String, dynamic> json) {
    return RecordDetail(
      unit: json['unit'] ?? 'Unknown Unit',
      contents: json['contents'] ?? 'No description',
      images: json['images'] != null && json['images'] is List
          ? List<String>.from(json['images'])
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'unit': unit,
      'contents': contents,
      'images': images,
    };
  }
}
