import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';

class CSVUploader extends StatefulWidget {
  @override
  _CSVUploaderState createState() => _CSVUploaderState();
}

class _CSVUploaderState extends State<CSVUploader> {
  Future<void> _uploadCSV() async {
    try {
      // 🔹 파일 선택
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // 웹 환경에서 bytes를 가져오기 위해 설정
      );

      if (result == null) return; // 파일 선택 취소 시 종료

      String fileContent;

      if (result.files.single.bytes != null) {
        // 🔹 웹 환경에서는 bytes를 사용
        fileContent = utf8.decode(result.files.single.bytes!);
      } else {
        // 🔹 모바일 환경에서는 path를 사용하여 파일 읽기
        fileContent = await File(result.files.single.path!).readAsString();
      }

      // 🔹 CSV 데이터 파싱
      List<List<dynamic>> rowsAsListOfValues =
      const CsvToListConverter().convert(fileContent);

      // 🔹 Firestore에 데이터 업로드
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        List<dynamic> row = rowsAsListOfValues[i];

        if (row.length < 6 || row.any((element) => element.toString().trim().isEmpty)) {
          continue;
        }

        await FirebaseFirestore.instance.collection('default_foods').add({
          'defaultCategory': row[0].toString(),
          'foodsName': row[1].toString(),
          'imageFileName': row[2].toString(),
          'defaultFridgeCategory': row[3].toString(),
          'shoppingListCategory': row[4].toString(),
          'shelfLife': int.tryParse(row[5].toString()) ?? 0,

        });
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("✅ CSV 업로드 완료!")));
    } catch (e) {
      print("❌ CSV 업로드 오류: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ CSV 업로드 중 오류 발생!")));
    }
  }
  @override
  Widget build(BuildContext context) {
    return BasicElevatedButton(
        onPressed: _uploadCSV,
        iconTitle: Icons.file_copy_outlined,
        buttonTitle: "CSV 파일 업로드",
      );
  }
}
