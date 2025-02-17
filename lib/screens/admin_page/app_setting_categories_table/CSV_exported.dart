import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

Future<void> exportFirestoreToCSV() async {
  try {
    // 🔹 Firestore 데이터 가져오기
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('foods').get();

    List<List<String>> csvData = [
      ["id", "foodsName", "category", "shelfLife", "userId"] // 헤더 추가
    ];

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      csvData.add([
        doc.id,
        data["foodsName"] ?? "",
        data["category"] ?? "",
        data["shelfLife"].toString(),
        data["userId"] ?? ""
      ]);
    }

    // 🔹 CSV 변환
    String csvString = const ListToCsvConverter().convert(csvData);

    // 🔹 저장할 경로 가져오기
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/foods_data.csv";
    final File file = File(path);

    // 🔹 파일 저장
    await file.writeAsString(csvString);

    print("✅ CSV 파일 저장 완료: $path");
  } catch (e) {
    print("⚠️ Firebase 데이터를 CSV로 내보내는 중 오류 발생: $e");
  }
}
