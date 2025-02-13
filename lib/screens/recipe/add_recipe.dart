import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
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
  int? _selectedStepIndex; // 현재 선택된 항목의 인덱스

  List<String>? _imageFiles = [];
  List<String> mainImages = [];
  String userRole = '';
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isSaving = false;
  bool isUploading = false;

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
      final themesSnapshot = await _db
          .collection('recipe_thema_categories')
          .orderBy('priority', descending: false)
          .get();
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

  void _confirmAddStep() {
    final theme = Theme.of(context);
    if (stepDescriptionController.text.trim().isNotEmpty ||
        (_imageFiles != null && _imageFiles!.isNotEmpty)) {
      // 저장되지 않은 상태인지 확인
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              '저장되지 않은 내용이 있습니다.',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            content: Text(
              '현재 입력된 내용만 저장할까요?',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 팝업 닫기
                },
                child: Text('아니요'),
              ),
              TextButton(
                onPressed: () {
                  // 저장 로직 실행
                  _saveRecipe();
                  Navigator.pop(context); // 팝업 닫기
                },
                child: Text('예'),
              ),
            ],
          );
        },
      );
    } else {
      // 바로 저장 실행 (입력된 내용이 없는 경우)
      _saveRecipe();
    }
  }

  // 저장 버튼 누르면 레시피 추가 또는 수정 처리
  void _saveRecipe() async {
    if (isSaving) {
      print('저장 중입니다. 중복 실행 방지');
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      // 레시피 이름이 비어있는지 확인
      if (recipeNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('레시피 제목을 작성해주세요')),
        );
        return; // 저장 동작 중단
      }
      if (mainImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('메인 이미지를 최소 1장 선택해주세요'),
          duration: Duration(seconds: 2),
        ));
        return;
      }
      final hasEmptyUrls = mainImages.any((url) => url.isEmpty);
      if (hasEmptyUrls) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드된 이미지 중 일부가 비어 있습니다. 다시 업로드해주세요.')),
        );
        return;
      }
      if (stepsWithImages.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('조리 단계를 최소 1개 이상 추가해주세요')));
        return;
      }
      if (selectedDifficulty.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('난이도를 작성해주세요')),
        );
        return; // 저장 동작 중단
      }
      if (servingsController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인원 수를 작성해주세요')),
        );
        return; // 저장 동작 중단
      }
      if (minuteController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('조리시간을 작성해주세요')),
        );
        return; // 저장 동작 중단
      }

      setState(() {
        isSaving = true; // 저장 시작
      });
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
          rating: 0.0,
        );
        await _db.collection('recipe').doc(newItem.id).set({
          ...newItem.toFirestore(), // 기존 데이터// 현재 시각 추가
        });

        Navigator.pop(context, true);
      } else {
        String? recipeId = widget.recipeData?['id'];

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

  Future<String> uploadMainImage(File imageFile) async {
    try {
      File compressedFile = await _compressImage(imageFile);
      final storageRef = FirebaseStorage.instance.ref();
      final uniqueFileName =
          'recipe_main_image_${DateTime.now().millisecondsSinceEpoch}';
      final imageRef = storageRef.child('images/recipes/$uniqueFileName');
      // final metadata = SettableMetadata(
      //   contentType: 'image/jpeg', // 이미지의 MIME 타입 설정
      // );
      final uploadTask = imageRef.putFile(compressedFile);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('이미지 업로드 실패: $e');
      return '';
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

  void addStepWithImage(String description, String imageUrl) {
    setState(() {
      stepsWithImages.add({
        'description': description,
        'image': imageUrl,
      });
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFiles = [pickedFile.path]; // 하나의 이미지만 리스트에 저장
      });
    } else {
      print('이미지 선택이 취소되었습니다.');
    }
  }

  void _pickMainImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      // 중복 방지
      List<String> newImages = [];

      // 이미지를 업로드하고 URL을 가져오는 부분 추가
      for (XFile file in pickedFiles) {
        String imageUrl = await uploadMainImage(File(file.path));
        if (imageUrl.isNotEmpty && !mainImages.contains(imageUrl)) {
          newImages.add(imageUrl); // URL 추가
        }
      }
      // 초과 이미지 제거
      if (mainImages.length + newImages.length > 4) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('최대 4장까지 이미지를 선택할 수 있습니다.'),
        ));

        // 초과분을 자르기
        final int remainingSlots = 4 - mainImages.length;
        newImages = newImages.sublist(0, remainingSlots);
      }
      // if (pickedFiles != null) {
      //   for (XFile file in pickedFiles) {
      //     String imageUrl = await uploadMainImage(File(file.path));
      //     if (imageUrl.isNotEmpty) {
      //       setState(() {
      //         mainImages.add(imageUrl); // 이미지 URL을 mainImages 리스트에 추가
      //       });
      //     }
      //   }
      // 중복 없는 새로운 이미지를 추가
      setState(() {
        mainImages.addAll(newImages);
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
              onPressed: _confirmAddStep,
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
              // _buildTextField('레시피 이름', recipeNameController, maxLength: 20),
              _buildMainImagePicker(),
              Row(
                children: [
                  Icon(Icons.timer,
                      size: 25, color: theme.colorScheme.onSurface), // 아이콘
                  SizedBox(width: 5), // 아이콘과 입력 필드 사이 간격
                  Container(
                    // flex: 1,
                    child: _buildTimeInputSection(),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.people,
                      size: 25, color: theme.colorScheme.onSurface),
                  SizedBox(width: 5), // 아이콘과 입력 필드 사이 간격
                  Expanded(
                    flex: 1,
                    child: _buildTextField('인원', servingsController,
                        isNumber: true, maxLength: 2),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.emoji_events,
                      size: 25, color: theme.colorScheme.onSurface),
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
              // SizedBox(height: 10),
              _buildSearchableDropdown(
                  '재료', // title
                  availableIngredients, // items
                  ingredientsSearchController, (selectedItem) {
                // onItemSelected
                setState(() {
                  selectedIngredients.add(selectedItem);
                });
              }, 'ingredients', 20),
              SizedBox(height: 10),
              _buildselectedItems(selectedIngredients, 10), // 선택된 재료 표시
              // SizedBox(height: 10),

              _buildHorizontalScrollSection(
                  '조리 방법',
                  availableMethods,
                  filteredMethods,
                  methodsSearchController,
                  selectedMethods, (selectedItem) {
                setState(() {
                  selectedMethods.add(selectedItem);
                });
              }, 'methods', 5),
              // SizedBox(height: 10),
              // _buildselectedItems(selectedMethods, 10),
              // SizedBox(height: 10),

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
              }, 'themes', 5),
              // SizedBox(height: 10),
              // _buildselectedItems(selectedThemes, 10),

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
        ));
  }

  Widget _buildMainImagePicker() {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (mainImages.isNotEmpty)
          GestureDetector(
            onTap: () async {
              // 사진을 클릭했을 때 새로운 사진 선택
              final ImagePicker picker = ImagePicker();
              final XFile? pickedFile =
                  await picker.pickImage(source: ImageSource.gallery);

              if (pickedFile != null) {
                // 새 이미지 업로드 및 URL 가져오기
                String imageUrl = await uploadMainImage(File(pickedFile.path));

                if (imageUrl.isNotEmpty) {
                  setState(() {
                    mainImages[0] = imageUrl; // 첫 번째 이미지를 새로운 이미지로 교체
                  });
                }
              }
            }, // 사진 선택 기능
            child: Stack(
              children: [
                Image.network(
                  mainImages.first, // 첫 번째 이미지만 표시
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.error,
                        color: theme.colorScheme.onSurface);
                  },
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        mainImages.clear(); // 기존 이미지 삭제
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
            ),
          )
        else // 이미지가 없을 때 카메라 아이콘 표시
          IconButton(
            icon: Icon(Icons.camera_alt_outlined,
                color: theme.colorScheme.onSurface),
            onPressed: _pickMainImage,
          ),
        SizedBox(width: 8),
        Expanded(
          child: _buildTextField('레시피 이름', recipeNameController, maxLength: 20),
        ),
      ],
    );
  }

  Widget buildImage(String imagePath) {
    if (imagePath.startsWith('http')) {
      return Image.network(imagePath, width: 50, height: 50, fit: BoxFit.cover);
    } else {
      return Image.file(File(imagePath),
          width: 50, height: 50, fit: BoxFit.cover);
    }
  }

  // 선택할 수 있는 검색 입력 필드
  Widget _buildSearchableDropdown(
    String title,
    List<String> items,
    TextEditingController searchController,
    Function(String) onItemSelected,
    String type,
    int maxCount,
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
                    if (isSelected) {
                      // 이미 선택된 경우 알림 메시지 표시
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$item은 이미 추가된 재료입니다.')),
                      );
                      return; // 추가 동작 중단
                    }
                    if (!isSelected && selectedIngredients.length >= maxCount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('$title는 최대 $maxCount개까지만 선택 가능합니다.')),
                      );
                      return;
                    }
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
                        // style: theme.textTheme.bodyMedium?.copyWith(
                        //   color: isSelected
                        //       ? theme.chipTheme.secondaryLabelStyle!.color
                        //       : theme.chipTheme.labelStyle!.color,
                        // ),
                      ),
                      backgroundColor: isSelected
                          ? theme.chipTheme.selectedColor
                          : theme.chipTheme.backgroundColor,
                      padding: EdgeInsets.symmetric(
                          horizontal: 1.0, vertical: 0.0), // 글자와 테두리 사이의 여백 줄이기
                      labelPadding: EdgeInsets.symmetric(
                          horizontal: 1.0), // 글자와 칩 사이의 여백 줄이기
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // 입력필드
  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false, int? maxLength}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: theme.colorScheme.onSurface), // 입력 텍스트 스타일
        decoration: InputDecoration(
          labelText: label,
          counterText: '', // 이 부분을 추가하면 maxLength 카운터가 숨겨짐
          // border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 8.0, // 텍스트 필드 내부 좌우 여백 조절
            vertical: 8.0, // 텍스트 필드 내부 상하 여백 조절
          ),
        ),
      ),
    );
  }

//시간입력 섹션
  Widget _buildTimeInputSection() {
    return Expanded(
        child: _buildTextField('분', minuteController,
            isNumber: true, maxLength: 3));
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

// 선택된 재료 목록을 표시
  Widget _buildselectedItems(List<String> selectedItems, int maxCount) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: -8.0, // 칩 간의 세로 간격을 줄임
      children: selectedItems.map((item) {
        return Chip(
          label: Text(
            item,
            // style: theme.textTheme.bodyMedium
            //     ?.copyWith(color: theme.chipTheme.labelStyle!.color)
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            // side: BorderSide(
            //   color: theme.chipTheme.labelStyle?.color ??
            //       Colors.white, // 테두리 색상 빨간색으로 변경
            //   width: 1, // 테두리 두께 조절
            // ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
          labelPadding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
          deleteIcon: Padding(
            padding: EdgeInsets.all(0.0), // 상하좌우 여백
            child:
                Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface),
          ),
          onDeleted: () {
            setState(() {
              selectedItems.remove(item);
            });
          },
        );
      }).toList(),
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
    int maxCount,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider(),
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

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 1.0), // 칩 간 간격 조정
                child: ChoiceChip(
                  label: Text(
                    item,
                    style: TextStyle(
                      // color: isSelected
                      //     ? Colors.white // 선택된 칩의 글씨 색
                      //     : Colors.black, // 선택되지 않은 칩의 글씨 색
                    ),
                  ),
                  selected: isSelected, // ✅ `selected` 속성 필수
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        if (selectedItems.length < maxCount) {
                          selectedItems.add(item);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('$title는 최대 $maxCount개까지만 선택 가능합니다.'),
                            ),
                          );
                        }
                      } else {
                        selectedItems.remove(item);
                      }
                    });
                  },
                  // selectedColor: Colors.blue, // ✅ 선택된 칩의 배경색
                  // backgroundColor: Colors.grey[200], // ✅ 기본 배경색
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // ✅ 칩의 둥근 모서리
                  //   side: BorderSide(
                  //     color: isSelected
                  //         ? Colors.blue
                  //         : Colors.grey, // ✅ 선택 여부에 따른 테두리 색
                  //     width: 1.5, // ✅ 테두리 두께 조정
                  //   ),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: 0.0, vertical: 0.0), // ✅ 칩 내부 패딩 조정
                  labelPadding:
                      EdgeInsets.symmetric(horizontal: 8.0), // ✅ 글자와 칩 사이 여백 조정
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  //조리방법과이미지 섹션
  Widget _buildStepsWithImagesSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider(),
        Text(
          '조리 단계',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface),
        ),
        SizedBox(height: 8.0),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(), // 스크롤 방지
          itemCount: stepsWithImages.length,
          itemBuilder: (context, index) {
            final step = stepsWithImages[index];
            return ListTile(
              key: ValueKey(step),
              title: Text(stepsWithImages[index]['description'] ?? ''),
              leading: stepsWithImages[index]['image'] != null &&
                      stepsWithImages[index]['image']!.isNotEmpty
                  ? kIsWeb ||
                          stepsWithImages[index]['image']!.startsWith('http')
                      ? Image.network(
                          stepsWithImages[index]['image']!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.error,
                                color: theme.colorScheme.onSurface);
                          },
                        )
                      : Image.file(
                          File(stepsWithImages[index]['image']!),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                  : Icon(Icons.image,
                      size: 50, color: theme.colorScheme.onSurface),
              trailing: GestureDetector(
                onTap: () {
                  setState(() {
                    stepsWithImages.removeAt(index);
                  });
                },
                child: Icon(Icons.close,
                    size: 18, color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                setState(() {
                  _selectedStepIndex = index; // 선택된 항목의 인덱스 저장
                  stepDescriptionController.text = stepsWithImages[index]
                          ['description'] ??
                      ''; // 설명을 입력 필드에 채움
                  _imageFiles = [
                    stepsWithImages[index]['image']!
                  ]; // 이미지 경로를 입력 필드에 채움
                });
              },
            );
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              // ✅ 아이템 순서 재정렬
              final item = stepsWithImages.removeAt(oldIndex);
              stepsWithImages.insert(newIndex, item);
            });
          },
        ),

        SizedBox(height: 16.0),
        // 조리 단계와 이미지 추가 입력 필드
        Row(
          children: [
            if (_imageFiles != null && _imageFiles!.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _imageFiles!.map((imagePath) {
                    return GestureDetector(
                      onTap: () async {
                        // 사진을 클릭했을 때 새로운 사진 선택
                        await _pickImage();
                        setState(() {
                          if (_imageFiles != null && _imageFiles!.isNotEmpty) {
                            // 기존 이미지를 새로운 이미지로 대체
                            imagePath = _imageFiles!.first;
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: kIsWeb || imagePath.startsWith('http')
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
                                child: Icon(Icons.close,
                                    size: 18, color: theme.colorScheme.onSurface
                                    // color: theme.chipTheme.labelStyle!.color,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(), // <-- 여기에 toList()를 추가
                ),
              ),
            if (_imageFiles == null || _imageFiles!.isEmpty)
              IconButton(
                icon: Icon(Icons.camera_alt_outlined,
                    color: theme.colorScheme.onSurface),
                onPressed: _pickImage,
              ),
            Expanded(
              child: _buildTextField('조리 과정 입력', stepDescriptionController,
                  maxLength: 200),
            ),
            // IconButton(
            //   icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
            //   onPressed: _addOrUpdateStep,
            // ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: NavbarButton(
            buttonTitle: '단계 추가하기',
            onPressed: _addOrUpdateStep,
          ),
        ),
      ],
    );
  }

// 조리 단계 추가 또는 수정 메서드
  void _addOrUpdateStep() async {
    if (isUploading) {
      return; // 이미 업로드 중이면 중복 실행 방지
    }
    if (stepDescriptionController.text.isEmpty ||
        (_imageFiles == null || _imageFiles!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('조리 과정과 이미지를 입력해 주세요.')),
      );
      return;
    }
    setState(() {
      isUploading = true; // 업로드 상태 시작
    });

    // 이미지 업로드
    String imageUrl = '';
    if (_imageFiles != null && _imageFiles!.isNotEmpty) {
      String imagePath = _imageFiles!.first;

      if (imagePath.startsWith('http') && _selectedStepIndex != null) {
        // 기존 항목에서 이미 업로드된 이미지를 사용하고 사진 수정이 없을 경우
        imageUrl = imagePath;
      } else {
        // 로컬 이미지 또는 새 이미지로 수정된 경우 업로드
        imageUrl = await uploadStepsImage(File(imagePath));
      }
    }

    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 업로드 실패')),
      );
      return;
    }
    bool isDuplicate = stepsWithImages.any((step) =>
        step['description'] == stepDescriptionController.text.trim() &&
        step['image'] == imageUrl);
    print(imageUrl);
    if (isDuplicate) {
      setState(() {
        isUploading = false; // 업로드 상태 시작
      });
      return;
    }
    setState(() {
      if (_selectedStepIndex != null) {
        // 기존 항목 수정
        stepsWithImages[_selectedStepIndex!] = {
          'description': stepDescriptionController.text,
          'image': imageUrl,
        };
        _selectedStepIndex = null; // 선택 해제
      } else {
        // 새 항목 추가
        if (stepsWithImages.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('조리 과정은 최대 10개까지만 추가할 수 있습니다.')),
          );
          return;
        }
        stepsWithImages.add({
          'description': stepDescriptionController.text,
          'image': imageUrl,
        });
      }

      // 입력 필드 초기화
      stepDescriptionController.clear();
      _imageFiles!.clear();
      isUploading = false;
    });
  }
}
