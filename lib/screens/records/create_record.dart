import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/record_model.dart';
import 'package:food_for_later_new/services/record_category_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateRecord extends StatefulWidget {
  final String? recordId; // recordId를 받을 수 있도록 수정
  final bool isEditing;

  CreateRecord({this.recordId, this.isEditing = false});
  @override
  _CreateRecordState createState() => _CreateRecordState();
}

class _CreateRecordState extends State<CreateRecord> {
  late TextEditingController categoryController;
  late TextEditingController fieldController;
  late TextEditingController contentsController;
  late TextEditingController dateController;
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late String selectedCategory = '식단';
  late String selectedField = '아침';
  late Color selectedColor = Colors.grey;
  late String selectedContents = '양배추 참치덮밥';
  late List<Map<String, dynamic>> recordsWithImages = <Map<String, dynamic>>[];
  DateTime selectedDate = DateTime.now();
  bool isSaving = false;
  int? selectedRecordIndex;
  String userRole = '';

  // 분류와 그에 따른 구분 데이터를 정의
  Map<String, Map<String, dynamic>> categoryFieldMap = {};

  // 이미지 선택을 위한 ImagePicker 인스턴스
  List<AssetEntity> images = [];
  List<String>? _imageFiles = [];

  @override
  void initState() {
    super.initState();
    categoryController = TextEditingController();
    fieldController = TextEditingController();
    dateController = TextEditingController();
    contentsController = TextEditingController();
    // stepDescriptionController = TextEditingController();

    if (widget.isEditing && widget.recordId != null) {
      // 기록 수정 모드일 때, recordId를 통해 데이터를 불러와서 초기화
      _loadRecordData(widget.recordId!);
    } else {
      // 추가 모드일 경우 현재 날짜 및 기본값 초기화
      dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate);
    }
    _initializeValues();
    _loadCategories();
    _loadUserRole();
  }

  void _loadUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userRole = userDoc['role'] ?? 'user'; // 기본값은 'user'
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }

  void _initializeValues() {
    if (categoryFieldMap.isNotEmpty) {
      selectedCategory = categoryFieldMap.keys.first;
      List<String> fields = categoryFieldMap[selectedCategory]?['fields'] ?? [];

      selectedField = fields.isNotEmpty ? fields.first : '';
      selectedColor =
          categoryFieldMap[selectedCategory]?['color'] ?? Colors.grey;
    } else {
      selectedCategory = '식단'; // 기본 카테고리
      selectedField = ''; // 기본 필드
      selectedColor = Colors.grey; // 기본 색상
    }
  }

  // Firestore에서 카테고리 데이터를 불러오는 함수
  void _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('record_categories')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true) // 최신순 정렬
          .get();

      if (snapshot.docs.isEmpty) {
        // 기본 카테고리 생성
        await _createDefaultCategories();
      } else {
        // Firestore에서 데이터 가져오기
        final categories = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'category': data['zone'] ?? '기록 없음',
            'fields':
                data['units'] != null ? List<String>.from(data['units']) : [],
            'color': data['color'] != null
                ? Color(int.parse(data['color'].replaceFirst('#', '0xff')))
                : Colors.grey,
          };
        }).toList();

        setState(() {
          categoryFieldMap = {
            for (var category in categories)
              category['category']: {
                'fields': category['fields'],
                'color': category['color'],
              }
          };
          // 🔹 기존에 선택된 `selectedCategory` 유지
          if (!categoryFieldMap.containsKey(selectedCategory)) {
            selectedCategory = categoryFieldMap.keys.isNotEmpty
                ? categoryFieldMap.keys.first
                : '식단';
          }

          // 🔹 기존에 선택된 `selectedField` 유지
          List<String> availableFields =
              categoryFieldMap[selectedCategory]?['fields'] ?? [];
          selectedField = availableFields.contains(selectedField)
              ? selectedField
              : (availableFields.isNotEmpty ? availableFields.first : '');
        });
      }
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 불러오는 데 실패했습니다.')),
      );
    }
  }

  Future<void> _createDefaultCategories() async {
    await RecordCategoryService.createDefaultCategories(
        userId, context, _loadCategories);
  }

  //수정모드일때 데이터를 받아옴
  void _loadRecordData(String recordId) async {
    final documentSnapshot = await FirebaseFirestore.instance
        .collection('record')
        .doc(recordId)
        .get();

    if (documentSnapshot.exists) {
      final data = documentSnapshot.data() as Map<String, dynamic>;
      final record = RecordModel.fromJson(data, id: recordId);

      setState(() {
        selectedCategory = record.zone ?? '식단';
        selectedDate = record.date;
        selectedColor =
            Color(int.parse(record.color.replaceFirst('#', '0xff')));
        dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate);
        recordsWithImages = record.records.map((rec) {
          return {
            'field': rec.unit as String? ?? '',
            'contents': rec.contents as String? ?? '',
            'images': List<String>.from(rec.images ?? <String>[]),
          };
        }).toList();
      });
      // 🔹 `categoryFieldMap`이 로드된 이후 `selectedField` 유지
      Future.delayed(Duration(milliseconds: 200), () {
        setState(() {
          List<String> availableFields =
              categoryFieldMap[selectedCategory]?['fields'] ?? [];
          selectedField = availableFields.contains(record.records.first.unit)
              ? record.records.first.unit
              : (availableFields.isNotEmpty ? availableFields.first : '');
        });
      });
    }
  }

  Future<File> _compressImage(File file) async {
    final compressedImage = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 800, // 원하는 너비 (예: 800px)
      minHeight: 800, // 원하는 높이 (예: 800px)
      quality: 85, // 압축 품질 (1-100, 100은 품질 유지)
    );

    // 압축된 이미지 파일을 저장할 경로 지정
    final tempDir = await getTemporaryDirectory();
    final compressedFile =
        File('${tempDir.path}/compressed_${file.path.split('/').last}');
    compressedFile.writeAsBytesSync(compressedImage!);

    return compressedFile;
  }

  // 이미지를 선택하는 메서드
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();

    if (pickedFiles == null || pickedFiles.isEmpty) {
      print('No image selected.');
      return;
    }

    setState(() {
      if (_imageFiles == null) {
        _imageFiles = [];
      }

      // 한 기록에 최대 4개의 사진만 추가할 수 있도록 제한
      for (XFile file in pickedFiles) {
        if (_imageFiles!.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('한 기록당 최대 4개의 사진만 추가할 수 있습니다.'),
            ),
          );
          break;
        }
        _imageFiles!.add(file.path); // 새로 추가된 이미지를 리스트에 반영
      }

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          if (selectedRecordIndex != null) {
            final images =
                recordsWithImages[selectedRecordIndex!]['images'] ?? [];
            recordsWithImages[selectedRecordIndex!]['images'] = [
              ...images,
              ...pickedFiles.map((file) => file.path).toList(),
            ];
          } else {
            _imageFiles?.addAll(pickedFiles.map((file) => file.path).toList());
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 선택하지 않았습니다.')),
        );
      }
    });
  }

// 이미지 업로드 메서드
  Future<List<String>> _uploadImages() async {
    List<String> downloadUrls = [];

    if (_imageFiles == null || _imageFiles!.isEmpty) {
      print('No images to upload.');
      return downloadUrls; // 빈 배열 반환
    }

    for (var imagePath in _imageFiles!) {
      File file = File(imagePath);
      File compressedFile = await _compressImage(file);
      try {
        final uniqueFileName =
            'record_image_${DateTime.now().millisecondsSinceEpoch}';
        final ref = FirebaseStorage.instance
            .ref()
            .child('images/records/$uniqueFileName');

        final SettableMetadata metadata = SettableMetadata(
          contentType: 'image/jpeg', // 이미지 형식에 맞게 설정
        );

        await ref.putFile(compressedFile, metadata);
        final downloadUrl = await ref.getDownloadURL();
        downloadUrls.add(downloadUrl);
      } catch (e) {
        print('이미지 업로드 실패: $e');
      }
    }
    return downloadUrls;
  }

// 저장 버튼 누르면 레시피 추가 또는 수정 처리
  void _saveRecord() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (selectedField.isEmpty || selectedContents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('필수 입력 항목을 입력하세요.')),
      );
      return;
    }

    List<String> imageUrls = await _uploadImages();

    if (imageUrls.isEmpty && _imageFiles!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
      );
      return;
    }

    List<RecordDetail> recordDetails = recordsWithImages.map((record) {
      return RecordDetail(
        unit: record['field'] as String,
        contents: record['contents'] as String,
        images: List<String>.from(record['images'] as List<dynamic>),
      );
    }).toList();

    final record = RecordModel(
      id: widget.recordId ?? Uuid().v4(),
      // 고유 ID 생성, 수정 모드일 때 기존 ID 사용
      date: selectedDate,
      color: '#${selectedColor.value.toRadixString(16).padLeft(8, '0')}',
      zone: selectedCategory,
      records: recordDetails,
      userId: userId,
    );

    try {
      // Firestore에 Record 객체를 저장
      await FirebaseFirestore.instance
          .collection('record') // 'records' 컬렉션에 저장
          .doc(record.id) // 고유 ID를 사용하여 문서 생성
          .set(record.toMap(),
              SetOptions(merge: true)); // Record 객체를 Map으로 변환하여 저장

      // 성공 메시지 표시 및 이전 화면으로 이동
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기록이 저장되었습니다.')),
      );
      Navigator.pop(context);
    } catch (e) {
      // 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기록 저장에 실패했습니다. 다시 시도해주세요.')),
      );
      print('Error saving record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // null 체크 추가
    if (categoryFieldMap.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('기록하기')),
        body: Center(
          child: Text('카테고리 데이터가 없습니다.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '기록 수정' : '기록하기'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField('날짜', dateController, onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        selectedDate = pickedDate; // selectedDate를 업데이트
                        dateController.text = DateFormat('yyyy-MM-dd')
                            .format(selectedDate); // dateController 업데이트
                      });
                    }
                  }),
                ),
                SizedBox(width: 30),
                Padding(
                  padding: const EdgeInsets.only(top: 28.0),
                  child: _buildDropdown(
                    '',
                    categoryFieldMap.keys.toList(), // 카테고리 목록을 드롭다운에 전달
                    selectedCategory,
                    (value) {
                      setState(() {
                        selectedCategory = value;
                        List<String> availableFields =
                            categoryFieldMap[selectedCategory]?['fields'] ?? [];
                        // 분류 변경 시 구분을 첫 번째 값으로 초기화
                        selectedField = availableFields.contains(selectedField)
                            ? selectedField
                            : (availableFields.isNotEmpty
                                ? availableFields.first
                                : '');
                        selectedColor =
                            categoryFieldMap[selectedCategory]!['color'];
                        // fieldController.text = selectedField;
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            _buildRecordsSection(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
          mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
          children: [
            SizedBox(
              width: double.infinity,
              child: NavbarButton(
                buttonTitle: '저장하기',
                onPressed: _saveRecord,
              ),
            ),
            if (userRole != 'admin' && userRole != 'paid_user')
              SafeArea(
                child: BannerAdWidget(),
              ),
          ],
        ),
      ),
    );
  }

  // 입력필드
  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          // border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 8.0, // 텍스트 필드 내부 좌우 여백 조절
            vertical: 8.0, // 텍스트 필드 내부 상하 여백 조절
          ),
        ),
        onTap: onTap, // 필요 시 추가된 onTap 이벤트
      ),
    );
  }

  // 드롭다운
  Widget _buildDropdown(String label, List<String> options, String currentValue,
      Function(String) onChanged) {
    final theme = Theme.of(context);
    // 현재 선택된 값이 목록에 없는 경우 기본값을 설정
    print(options);
    print(currentValue);
    if (!options.contains(currentValue)) {
      currentValue = options.isNotEmpty ? options.first : '';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(label),
          SizedBox(width: 16),
          DropdownButton<String>(
            value: currentValue, // 현재 선택된 값을 드롭다운의 value로 사용
            items: options.isNotEmpty
                ? options.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ));
                  }).toList()
                : null,
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            hint: Text("선택 없음"),
          ),
        ],
      ),
    );
  }

  //기록과이미지 섹션
  Widget _buildRecordsSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기록',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface),
        ),
        // SizedBox(height: 8.0),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: recordsWithImages.length,
          itemBuilder: (context, index) {
            final List<String> imagePaths =
                List<String>.from(recordsWithImages[index]['images'] ?? []);

            return ListTile(
              onTap: () {
                setState(() {
                  selectedRecordIndex = index; // 선택한 기록의 인덱스를 저장
                  selectedField = recordsWithImages[index]['field'] as String;
                  contentsController.text =
                      recordsWithImages[index]['contents'] as String;
                  _imageFiles = List<String>.from(
                      recordsWithImages[index]['images'] ?? []);
                });
              },
              title: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        recordsWithImages[index]['field'] ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface),
                      ),
                      SizedBox(width: 4),
                      Text(' | ',
                          style: TextStyle(color: theme.colorScheme.onSurface)),
                      SizedBox(width: 4),
                      Text(recordsWithImages[index]['contents'] ?? '',
                          style: TextStyle(color: theme.colorScheme.onSurface)),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                ],
              ),
              subtitle: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: (recordsWithImages[index]['images'] as List<dynamic>)
                    .map((imagePath) {
                  final String imagePathStr = imagePath as String; // 명시적 타입 변환
                  // URL과 로컬 파일 구분
                  if (imagePath.startsWith('http') ||
                      imagePath.startsWith('https')) {
                    return Image.network(
                      imagePathStr,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.error); // 로드 실패 시 아이콘 표시
                      },
                    );
                  } else {
                    return Image.file(
                      File(imagePathStr),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    );
                  }
                }).toList(),
              ),
              trailing: GestureDetector(
                onTap: () {
                  setState(() {
                    recordsWithImages.removeAt(index);
                    if (selectedRecordIndex == index) {
                      selectedRecordIndex = null;
                      contentsController.clear();
                      _imageFiles = [];
                    }
                  });
                },
                child: Icon(Icons.close,
                    size: 18, color: theme.colorScheme.onSurface),
              ),
            );
          },
        ),
        SizedBox(height: 16.0),
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 28.0),
              child: _buildDropdown(
                  '',
                  categoryFieldMap[selectedCategory]!['fields'],
                  selectedField, (value) {
                setState(() {
                  selectedField = value;
                });
              }),
            ),
            SizedBox(width: 5.0),
            Expanded(
              child: _buildTextField('기록 내용 입력', contentsController),
            ),
          ],
        ),
        // 조리 단계와 이미지 추가 입력 필드
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.camera_alt_outlined,
                  color: theme.colorScheme.onSurface),
              onPressed: _pickImages, // _pickImages 메서드 호출
            ),
            if (_imageFiles != null && _imageFiles!.isNotEmpty) ...[
              Expanded(
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _imageFiles!.map((imagePath) {
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: kIsWeb
                              ? Image.network(
                                  imagePath,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.error,
                                        color: theme.colorScheme
                                            .onSurface); // 로드 실패 시 아이콘 표시
                                  },
                                )
                              : Image.file(
                                  File(imagePath), // 개별 이미지의 경로에 접근
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _imageFiles!.remove(imagePath);
                              });
                            },
                            child: Container(
                              color: Colors.black54,
                              child: Icon(Icons.close,
                                  size: 18, color: theme.colorScheme.onSurface),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
            Spacer(),
            IconButton(
              icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
              onPressed: () {
                if (recordsWithImages.length >= 10) {
                  // 최대 10개의 기록만 추가 가능하도록 제한
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('기록은 최대 10개까지만 추가할 수 있습니다.'),
                    ),
                  );
                  return;
                }
                if (contentsController.text.isNotEmpty) {
                  setState(() {
                    final newRecord = {
                      'field': selectedField,
                      'contents': contentsController.text,
                      'images':
                          List<String>.from(_imageFiles ?? []), // 명시적 타입 변환
                    };

                    if (selectedRecordIndex != null) {
                      // 선택된 항목 업데이트
                      recordsWithImages[selectedRecordIndex!] =
                          Map<String, Object>.from(newRecord);
                      selectedRecordIndex = null;
                    } else {
                      // 새로운 항목 추가
                      recordsWithImages
                          .add(Map<String, Object>.from(newRecord));
                    }

                    // 입력 필드와 이미지 초기화
                    contentsController.clear();
                    _imageFiles = [];
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('기록 내용을 입력하세요.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
