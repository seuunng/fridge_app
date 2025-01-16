import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/models/recipe_model.dart';
import 'package:food_for_later_new/screens/recipe/recipe_review.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddRecipe extends StatefulWidget {
  final Map<String, dynamic>? recipeData; // 수정 시 전달될 레시피 데이터

  AddRecipe({this.recipeData});

  @override
  _AddRecipeState createState() => _AddRecipeState();
}

class _AddRecipeState extends State<AddRecipe> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late DateTime createdDate;
  late TextEditingController recipeNameController;
  late TextEditingController minuteController;
  late TextEditingController stepDescriptionController;
  late TextEditingController stepImageController;
  late TextEditingController ingredientsSearchController;
  late TextEditingController methodsSearchController;
  late TextEditingController themesSearchController;
  late TextEditingController servingsController;
  late TextEditingController difficultyController;

  late int selectedServings = 1;
  late String selectedDifficulty;
  late List<String> ingredients;
  late List<String> themes;
  late List<String> methods;
  late List<Map<String, String>> stepsWithImages;

  List<String> availableIngredients = [];
  List<String> availableMethods = [];
  List<String> availableThemes = [];

  List<String> filteredIngredients = [];
  List<String> filteredMethods = [];
  List<String> filteredThemes = [];

  List<String> selectedIngredients = [];
  List<String> selectedMethods = [];
  List<String> selectedThemes = []; // 선택된 재료 목록

  List<String>? _imageFiles = [];
  List<String> mainImages = [];
  String userRole = '';
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    // 컨트롤러 초기화
    recipeNameController = TextEditingController();
    minuteController = TextEditingController();
    servingsController = TextEditingController();
    difficultyController = TextEditingController();
    stepDescriptionController = TextEditingController();
    ingredientsSearchController = TextEditingController();
    methodsSearchController = TextEditingController();
    themesSearchController = TextEditingController();

    createdDate = DateTime.now();

    if (widget.recipeData != null) {
      // 기존 레시피 데이터가 있을 때 값 설정
      recipeNameController.text =
          widget.recipeData?['recipeName']?.toString() ?? '';
      minuteController.text = widget.recipeData?['cookTime']?.toString() ?? '0';
      servingsController.text =
          widget.recipeData?['serving']?.toString() ?? '1';
      difficultyController.text =
          widget.recipeData?['difficulty']?.toString() ?? '하';
      selectedDifficulty = widget.recipeData?['difficulty']?.toString() ?? '중';

      ingredients = List<String>.from(widget.recipeData?['ingredients'] ?? []);
      themes = List<String>.from(widget.recipeData?['themes'] ?? []);
      methods = List<String>.from(widget.recipeData?['methods'] ?? []);
      stepsWithImages =
          List<Map<String, String>>.from(widget.recipeData?['steps'] ?? []);
      mainImages = List<String>.from(widget.recipeData?['mainImages'] ?? []);

      selectedIngredients = ingredients;
      selectedMethods = methods;
      selectedThemes = themes;
    } else {
      // 새로운 레시피일 때 빈 값으로 초기화
      selectedDifficulty = '중'; // 난이도 기본값 설정
      ingredients = [];
      themes = [];
      methods = [];
      stepsWithImages = [];
      mainImages = [];
    }
    _loadDataFromFirestore();
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
  Future<List<String>> _fetchIngredients() async {
    Set<String> userIngredients = {}; // 사용자가 추가한 재료
    List<String> allIngredients = [];

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      // ✅ 1. 사용자 정의 foods 데이터 가져오기
      final userSnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in userSnapshot.docs) {
        final foodName = doc['foodsName'] as String?;
        if (foodName != null) {
          userIngredients.add(foodName);
        }
      }

      // ✅ 2. 기본 식재료(default_foods) 가져오기
      final defaultSnapshot =
          await FirebaseFirestore.instance.collection('default_foods').get();

      for (var doc in defaultSnapshot.docs) {
        final foodName = doc['foodsName'] as String?;
        if (foodName != null && !userIngredients.contains(foodName)) {
          allIngredients.add(foodName);
        }
      }

      // ✅ 3. 사용자 재료 + 기본 재료 합쳐서 반환
      allIngredients.insertAll(0, userIngredients.toList()); // 사용자 데이터 우선
      return allIngredients;
    } catch (e) {
      print("Error fetching ingredients: $e");
      return [];
    }
  }

  Future<void> _loadDataFromFirestore() async {
    try {
      // ✅ 1. foods + default_foods 합친 데이터 가져오기
      final ingredientsData = await _fetchIngredients();

      // ✅ 2. 조리 방법 가져오기
      final methodsSnapshot =
          await _db.collection('recipe_method_categories').get();
      final List<String> methodsData = methodsSnapshot.docs
          .expand((doc) => (doc['method'] as List<dynamic>).cast<String>())
          .toList();

      // ✅ 3. 테마 데이터 가져오기
      final themesSnapshot =
          await _db.collection('recipe_thema_categories').get();
      final List<String> themesData = themesSnapshot.docs
          .map((doc) => doc['categories'] as String)
          .toList();

      setState(() {
        availableIngredients = ingredientsData;
        availableMethods = methodsData;
        availableThemes = themesData;
        filteredIngredients = [];
        filteredMethods = methodsData;
        filteredThemes = themesData;
      });
    } catch (e) {
      print('데이터 로드 실패: $e');
    }
  }

  // 검색어에 따른 필터링 기능
  void _filterItems(String query, List<String> sourceList, String type) {
    setState(() {
      if (query.trim().isEmpty) {
        if (type == 'ingredients') {
          filteredIngredients = sourceList;
        } else if (type == 'methods') {
          filteredMethods = sourceList;
        } else if (type == 'themes') {
          filteredThemes = sourceList;
        }
      } else {
        final normalizedQuery = query.trim().toLowerCase(); // 공백 제거 및 소문자 변환
        if (type == 'ingredients') {
          filteredIngredients = sourceList.where((item) {
            final normalizedItem = item.trim().toLowerCase();
            return normalizedItem.contains(normalizedQuery);
          }).toList();
        } else if (type == 'methods') {
          filteredMethods = sourceList.where((item) {
            final normalizedItem = item.trim().toLowerCase();
            return normalizedItem.contains(normalizedQuery);
          }).toList();
        } else if (type == 'themes') {
          filteredThemes = sourceList.where((item) {
            final normalizedItem = item.trim().toLowerCase();
            return normalizedItem.contains(normalizedQuery);
          }).toList();
        }
      }
    });
  }

  // 저장 버튼 누르면 레시피 추가 또는 수정 처리
  void _saveRecipe() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (mainImages.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('메인 이미지를 최소 1장 선택해주세요')));
        return;
      }
      if (stepsWithImages.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('조리 단계를 최소 1개 이상 추가해주세요')));
        return;
      }

      if (widget.recipeData == null) {
        final newItem = RecipeModel(
          id: _db.collection('recipe').doc().id,
          userID: userId,
          date: createdDate,
          difficulty: selectedDifficulty,
          serving: int.parse(servingsController.text),
          time: int.parse(minuteController.text),
          foods: selectedIngredients,
          themes: selectedThemes,
          methods: selectedMethods,
          recipeName: recipeNameController.text,
          steps: stepsWithImages.isNotEmpty ? stepsWithImages : [],
          mainImages: mainImages.isNotEmpty ? mainImages : [],
        );

        await _db.collection('recipe').doc(newItem.id).set({
          ...newItem.toFirestore(), // 기존 데이터// 현재 시각 추가
        });
        Navigator.pop(context);
      } else {
        String? recipeId = widget.recipeData?['id'];
        print(recipeId);
        if (recipeId == null && widget.recipeData != null) {
          DocumentReference docRef =
              _db.collection('recipe').doc(widget.recipeData!['id']);
          recipeId = docRef.id;
        }
        await _db.collection('recipe').doc(recipeId).update({
          'recipeName': recipeNameController.text,
          'mainImages': mainImages.isNotEmpty ? mainImages : [],
          'serving': int.parse(servingsController.text),
          'time': int.parse(minuteController.text),
          'difficulty': selectedDifficulty,
          'foods': selectedIngredients,
          'themes': selectedThemes,
          'methods': selectedMethods,
          'steps': stepsWithImages.isNotEmpty ? stepsWithImages : [],
        });

        // 수정 후 화면을 닫음
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('레시피 저장 실패: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('레시피 저장에 실패했습니다. 다시 시도해주세요.')));
    }
  }

  Future<String> uploadStepsImage(File imageFile) async {
    try {
      File compressedFile = await _compressImage(imageFile);

      final storageRef = FirebaseStorage.instance.ref();
      final uniqueFileName =
          'recipe_step_image_${DateTime.now().millisecondsSinceEpoch}';
      final imageRef = storageRef.child('images/recipes/$uniqueFileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg', // 이미지의 MIME 타입 설정
      );
      final uploadTask = imageRef.putFile(compressedFile, metadata);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('이미지 업로드 실패: $e');
      return '';
    }
  }

  Future<String> uploadMainImage(File imageFile) async {
    try {
      File compressedFile = await _compressImage(imageFile);
      final storageRef = FirebaseStorage.instance.ref();
      final uniqueFileName =
          'recipe_main_image_${DateTime.now().millisecondsSinceEpoch}';
      final imageRef = storageRef.child('images/recipes/$uniqueFileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg', // 이미지의 MIME 타입 설정
      );
      final uploadTask = imageRef.putFile(compressedFile, metadata);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('이미지 업로드 실패: $e');
      return '';
    }
  }

  void addStepWithImage(String description, String imageUrl) {
    setState(() {
      stepsWithImages.add({
        'description': description,
        'image': imageUrl,
      });
    });
  }

  // 이미지를 선택하는 메서드
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();

    if (pickedFiles == null || pickedFiles.isEmpty) {
      // 이미지 선택이 취소된 경우
      print('No image selected.');
      return;
    }

    if (_imageFiles == null) {
      _imageFiles = [];
    }

    for (XFile file in pickedFiles) {
      if (!_imageFiles!.contains(file.path)) {
        setState(() {
          _imageFiles!.add(file.path); // 로컬 경로를 XFile 객체로 변환하여 추가
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미 추가된 이미지입니다.'),
          ),
        );
      }
    }
  }

  void _pickMainImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.length + mainImages.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('최대 4장까지 이미지를 선택할 수 있습니다.'),
      ));
      return;
    }

    if (pickedFiles != null) {
      for (XFile file in pickedFiles) {
        String imageUrl = await uploadMainImage(File(file.path));
        if (imageUrl.isNotEmpty) {
          setState(() {
            mainImages.add(imageUrl); // 이미지 URL을 mainImages 리스트에 추가
          });
        }
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeData == null ? '레시피 추가' : '레시피 수정'),
        actions: [
          TextButton(
            child: Text(
              '저장',
              style: TextStyle(
                fontSize: 20, // 글씨 크기를 20으로 설정
              ),
            ),
            onPressed: _saveRecipe,
          ),
          SizedBox(
            width: 20,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('레시피 이름', recipeNameController),
            _buildMainImagePicker(),
            Row(
              children: [
                Icon(Icons.timer, size: 25,
                    color: theme.colorScheme.onSurface), // 아이콘
                SizedBox(width: 5), // 아이콘과 입력 필드 사이 간격
                Container(
                  // flex: 1,
                  child: _buildTimeInputSection(),
                ),
                SizedBox(width: 5),
                Icon(Icons.people, size: 25,
                    color: theme.colorScheme.onSurface),
                SizedBox(width: 5), // 아이콘과 입력 필드 사이 간격
                Expanded(
                  flex: 1,
                  child:
                      _buildTextField('인원', servingsController, isNumber: true),
                ),
                SizedBox(width: 5),
                Icon(Icons.emoji_events, size: 25,
                    color: theme.colorScheme.onSurface),
                SizedBox(width: 5), // 아이콘과 입력 필드 사이 간격
                Expanded(
                  flex: 2,
                  child: _buildDropdown(
                      '난이도', ['상', '중', '하'], selectedDifficulty, (value) {
                    setState(() {
                      selectedDifficulty = value;
                    });
                  }),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildSearchableDropdown(
              '재료', // title
              availableIngredients, // items
              ingredientsSearchController,
              (selectedItem) {
                // onItemSelected
                setState(() {
                  selectedIngredients.add(selectedItem);
                });
              },
              'ingredients',
            ),
            SizedBox(height: 10),
            _buildselectedItems(selectedIngredients), // 선택된 재료 표시
            SizedBox(height: 10),

            _buildHorizontalScrollSection(
              '조리 방법',
              availableMethods,
              filteredMethods,
              methodsSearchController,
              selectedMethods,
              (selectedItem) {
                setState(() {
                  selectedMethods.add(selectedItem);
                });
              },
              'methods',
            ),
            SizedBox(height: 10),
            _buildselectedItems(selectedMethods),
            SizedBox(height: 10),

            _buildHorizontalScrollSection(
                '테마', // title
                availableThemes,
                filteredThemes,
                themesSearchController,
                selectedThemes, (selectedItem) {
              // onItemSelected
              setState(() {
                selectedThemes.add(selectedItem);
              });
            }, 'themes'),
            SizedBox(height: 10),
            _buildselectedItems(selectedThemes),

            SizedBox(height: 10),
            _buildStepsWithImagesSection(),
          ],

        ),
      ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
          mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
          children: [
            if (userRole != 'admin' && userRole != 'paid_user')
              SafeArea(
                bottom: false, // 하단 여백 제거
                child: BannerAdWidget(),
              ),
          ],
        )
    );
  }

  Widget _buildMainImagePicker() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            if (mainImages.length < 4) // 이미지가 4장 미만일 때만 선택 가능
              IconButton(
                icon: Icon(Icons.camera_alt_outlined,
                    color: theme.colorScheme.onSurface),
                onPressed: _pickMainImages, // 이미지 선택 메서드 호출
              ),
            ...mainImages.map((imageUrl) {
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.network(imageUrl,
                        width: 50, height: 50, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          mainImages.remove(imageUrl); // 이미지 삭제
                        });
                      },
                      child: Container(
                        color: theme.colorScheme.primary,
                        child: Icon(Icons.close,
                            size: 18, color: theme.colorScheme.onPrimary),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  // 선택할 수 있는 검색 입력 필드
  Widget _buildSearchableDropdown(
    String title,
    List<String> items,
    TextEditingController searchController,
    Function(String) onItemSelected,
    String type,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            Spacer(),
            SizedBox(
              width: 200,
              child: TextField(
                controller: searchController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: '$title 검색',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      filteredIngredients = [];
                    });
                  } else {
                    _filterItems(value, items, type);
                  }
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (filteredIngredients.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              // spacing: 8,
              children: filteredIngredients.map((item) {
                final theme = Theme.of(context);
                final bool isSelected = selectedIngredients.contains(item);
                return GestureDetector(
                  onTap: () {
                    onItemSelected(item);
                    searchController.clear();
                    setState(() {
                      filteredIngredients = [];
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2.0), // 칩들 간의 간격
                    child: Chip(
                      label: Text(
                        item, // 선택된 항목은 글씨 색을 흰색으로
                style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                ? theme.chipTheme.secondaryLabelStyle!.color
                    : theme.chipTheme.labelStyle!
                    .color,
                        ),
                      ),
                      backgroundColor: isSelected
                          ? theme.chipTheme.selectedColor
                          : theme.chipTheme.backgroundColor,
                      padding: EdgeInsets.symmetric(
                          horizontal: 4.0, vertical: 0.0), // 글자와 테두리 사이의 여백 줄이기
                      labelPadding: EdgeInsets.symmetric(
                          horizontal: 4.0), // 글자와 칩 사이의 여백 줄이기
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

// 선택된 재료 목록을 표시
  Widget _buildselectedItems(List<String> selectedItems) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      children: selectedItems.map((item) {
        return Chip(
          label: Text(item,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.chipTheme.labelStyle!.color)),
          padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
          labelPadding: EdgeInsets.symmetric(horizontal: 1.0),
          deleteIcon: Icon(Icons.close,
              color: theme.colorScheme.onSurface),
          onDeleted: () {
            setState(() {
              selectedItems.remove(item);
            });
          },
        );
      }).toList(),
    );
  }

  // 입력필드
  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: theme.colorScheme.onSurface), // 입력 텍스트 스타일
        decoration: InputDecoration(
          labelText: label,
          // border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 8.0, // 텍스트 필드 내부 좌우 여백 조절
            vertical: 8.0, // 텍스트 필드 내부 상하 여백 조절
          ),
        ),
      ),
    );
  }

// 가로 스크롤 가능한 섹션 (조리 방법 및 테마)
  Widget _buildHorizontalScrollSection(
    String title,
    List<String> items,
    List<String> filteredItems, // 검색된 항목을 필터링해서 보여주기 위한 리스트
    TextEditingController searchController,
    List<String> selectedItems,
    Function(String) onItemSelected,
    String type,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(),
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            Spacer(),
            SizedBox(
              width: 200,
              child: TextField(
                controller: searchController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: '$title 검색',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                ),
                onChanged: (value) {
                  _filterItems(value, items, type); // 검색어 입력 시 항목 필터링
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filteredItems.map((item) {
              final bool isSelected = selectedItems.contains(item);
              return GestureDetector(
                onTap: () {
                  if (!selectedItems.contains(item)) {
                    setState(() {
                      selectedItems.add(item);
                    });
                  }
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 2.0), // 칩들 간의 간격
                  child: Chip(
                    label: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? theme.chipTheme.secondaryLabelStyle!.color
                            : theme.chipTheme.labelStyle!
                                .color, // 선택된 항목은 글씨 색을 흰색으로
                      ),
                    ),
                    backgroundColor: isSelected
                        ? theme.chipTheme.selectedColor
                        : theme.chipTheme.backgroundColor,
                    padding: EdgeInsets.symmetric(
                        horizontal: 4.0, vertical: 0.0), // 글자와 테두리 사이의 여백 줄이기
                    labelPadding: EdgeInsets.symmetric(
                        horizontal: 4.0), // 글자와 칩 사이의 여백 줄이기
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

//시간입력 섹션
  Widget _buildTimeInputSection() {
    return Expanded(
        child: _buildTextField('분', minuteController, isNumber: true));
  }

  // 난이도 드롭다운
  Widget _buildDropdown(String label, List<String> options, String currentValue,
      Function(String) onChanged) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurface)),
          SizedBox(width: 16),
          DropdownButton<String>(
            value: options.contains(currentValue) ? currentValue : options[0],
            items: options.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  //조리방법과이미지 섹션
  Widget _buildStepsWithImagesSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '조리 단계',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface),
        ),
        SizedBox(height: 8.0),
        ListView.builder(
          shrinkWrap: true,
          itemCount: stepsWithImages.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(stepsWithImages[index]['description'] ?? ''),
              leading: stepsWithImages[index]['image'] != null &&
                      stepsWithImages[index]['image']!.isNotEmpty
                  ? Image.network(stepsWithImages[index]['image']!,
                      width: 50, height: 50, fit: BoxFit.cover)
                  : Icon(Icons.image, size: 50,
                  color: theme.colorScheme.onSurface),
              trailing: GestureDetector(
                onTap: () {
                  setState(() {
                    stepsWithImages.removeAt(index);
                  });
                },
                child: Icon(Icons.close, size: 18,
                    color: theme.colorScheme.onSurface),
              ),
            );
          },
        ),
        SizedBox(height: 16.0),
        // 조리 단계와 이미지 추가 입력 필드
        Row(
          children: [
            if (_imageFiles != null && _imageFiles!.isNotEmpty)
              ..._imageFiles!.map((imagePath) {
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
                                    color: theme.colorScheme.onSurface);
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
                          // color: theme.chipTheme.selectedColor,
                          child: Icon(
                            Icons.close,
                            size: 18,
                              color: theme.colorScheme.onSurface
                            // color: theme.chipTheme.labelStyle!.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            if (_imageFiles == null || _imageFiles!.isEmpty)
              IconButton(
                icon: Icon(Icons.camera_alt_outlined,
                    color: theme.colorScheme.onSurface),
                onPressed: _pickImages,
              ),
            Expanded(
              child: _buildTextField('조리 과정 입력', stepDescriptionController),
            ),
            IconButton(
              icon: Icon(Icons.add,
                  color: theme.colorScheme.onSurface),
              onPressed: () async {
                if (stepDescriptionController.text.isNotEmpty &&
                    _imageFiles != null &&
                    _imageFiles!.isNotEmpty) {
                  String imageUrl =
                      await uploadStepsImage(File(_imageFiles!.first));

                  if (imageUrl.isNotEmpty) {
                    setState(() {
                      stepsWithImages.add({
                        'description': stepDescriptionController.text,
                        'image': imageUrl,
                      });
                      stepDescriptionController.clear();
                      _imageFiles!.clear();
                    });
                  } else {
                    // 이미지 업로드 실패 메시지 출력
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('이미지 업로드 실패')));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('조리 과정과 이미지를 입력해 주세요.')));
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
