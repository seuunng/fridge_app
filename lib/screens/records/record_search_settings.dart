import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/services/record_category_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordSearchSettings extends StatefulWidget {
  @override
  _RecordSearchSettingsState createState() => _RecordSearchSettingsState();
}

class _RecordSearchSettingsState extends State<RecordSearchSettings> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<String> selectedCategories = ['모두'];
  String? selectedPeriod = '1년';
  DateTime? startDate;
  DateTime? endDate;
  String userRole = '';

  Map<String, bool> categoryOptions = {};

  List<String> periods = ['사용자 지정', '1주', '1달', '3달', '1년'];

  @override
  void initState() {
    super.initState();
    _loadCategoryFromFirestore();
    _loadSearchSettingsFromLocal();
    endDate = DateTime.now();
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
  void _loadCategoryFromFirestore() async {
    try {
      final snapshot = await _db
          .collection('record_categories')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false) // 최신순 정렬
          .orderBy('order')  // 순서대로 정렬
          .get();

      if (snapshot.docs.isEmpty) {
        // 기본 카테고리 생성
        await _createDefaultCategories();
      } else {
        // Firestore에서 데이터 가져오기
        final categories = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'category': data['zone'] ?? '기록 없음',
            'fields':
                data['units'] != null ? List<String>.from(data['units']) : [],
            'color': data['color'] != null
                ? Color(int.parse(data['color'].replaceFirst('#', '0xff')))
                : Colors.grey,
          };
        }).toList();

        final prefs = await SharedPreferences.getInstance();
        final localSelectedCategories =
            prefs.getStringList('selectedCategories') ?? [];

        // 카테고리를 categoryOptions에 반영
        setState(() {
          categoryOptions = {
            for (var category in categories)
              category['category']:
                  localSelectedCategories.contains(category['category']),
          };

          categoryOptions['모두'] =
              localSelectedCategories.length == categories.length;

          // "모두" 옵션 추가
          selectedCategories = localSelectedCategories.isEmpty
              ? ['모두']
              : localSelectedCategories;
        });
      }
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 불러오는 데 실패했습니다.'),
          duration: Duration(seconds: 2),),
      );
    }
  }

  Future<void> _createDefaultCategories() async {
    await RecordCategoryService.createDefaultCategories(userId, context, _loadCategoryFromFirestore);
  }


  Future<void> _loadSearchSettingsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final localSelectedCategories =
        prefs.getStringList('selectedCategories') ?? [];

    setState(() {
      selectedCategories = localSelectedCategories;
      selectedPeriod = prefs.getString('selectedPeriod') ?? '1년';

      final startDateString = prefs.getString('startDate');
      startDate = startDateString != null && startDateString.isNotEmpty
          ? DateTime.parse(startDateString)
          : DateTime(DateTime.now().year - 1, DateTime.now().month,
              DateTime.now().day);
      final endDateString = prefs.getString('endDate');
      endDate = endDateString != null && endDateString.isNotEmpty
          ? DateTime.parse(endDateString)
          : DateTime.now();
    });
  }

  // 카테고리 모두 선택 또는 해제 함수
  void _toggleSelectAll(bool isSelected) {
    setState(() {
      categoryOptions.updateAll((key, value) => isSelected);

      if (isSelected) {
        selectedCategories = ['모두']; // 모두 선택 시 다른 카테고리는 선택되지 않음
      } else {
        selectedCategories.clear(); // 모두 해제 시 모든 선택 해제
      }
    });
  }

  // 체크박스 상태 변경 시 처리 함수
  void _onCategoryChanged(String category, bool? isSelected) {
    setState(() {
      if (category == '모두') {
        if (isSelected == true) {
          // "모두"를 선택하면 모든 카테고리 선택
          categoryOptions.updateAll((key, value) => true);
          selectedCategories = categoryOptions.keys.toList(); // 모든 카테고리를 추가
        }
        return; // "모두"를 해제할 수 없음
      } else {
        // 개별 카테고리 선택 처리
        categoryOptions[category] = isSelected ?? false;

        if (isSelected == true) {
          selectedCategories.add(category); // 선택된 카테고리 추가

          // 모든 카테고리가 선택되었는지 확인
          if (categoryOptions.values.where((v) => v).length ==
              categoryOptions.length - 1) {
            categoryOptions['모두'] = true; // "모두"도 선택
          }
        } else {
          if (selectedCategories.length <= 1) {
            print('카테고리는 하나 이상 선택해야 합니다.');
            categoryOptions[category] = true; // 해제 방지
            return;
          }

          // 선택 해제 시 처리
          selectedCategories.remove(category);
          categoryOptions['모두'] = false; // "모두"는 선택 해제
        }
      }
    });
  }

  // 날짜 선택 다이얼로그
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final theme = Theme.of(context);

    DateTime initialDate =
        isStart ? DateTime.now() : startDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.onSurface, // 선택된 날짜 및 헤더 색상
              onPrimary: theme.colorScheme.onPrimary, // 헤더 텍스트 색상
              onSurface: theme.colorScheme.onSurface, // 날짜 폰트 색상
              surface: theme.colorScheme.background, // 달력 배경색 설정
              primaryContainer: theme.colorScheme.primary, // 선택된 날짜의 배경색
              onPrimaryContainer: theme.colorScheme.primary, // 선택된 날짜의 텍스트 색상

            ),
            dialogBackgroundColor: theme.colorScheme.background, // 다이얼로그 배경색
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary, // 확인, 취소 버튼 색상
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != (isStart ? startDate : endDate)) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> _saveSearchSettingsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    // "모두" 제외한 선택된 카테고리만 저장
    final categoriesToSave = selectedCategories.toSet()
      ..remove('모두'); // "모두" 제거
    await prefs.setStringList('selectedCategories', categoriesToSave.toList());
    await prefs.setString(
        'startDate', startDate != null ? startDate!.toIso8601String() : '');
    await prefs.setString(
        'endDate', endDate != null ? endDate!.toIso8601String() : '');
    await prefs.setString('selectedPeriod', selectedPeriod ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('기록 검색 상세설정'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '카테고리 선택',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: categoryOptions.entries.map((entry) {
                final category = entry.key;
                final isSelected = entry.value;
                return Theme(
                  data: Theme.of(context).copyWith(
                    // 민트색으로 반짝하는 효과 없애기, 근데 효과는 없음
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                  ),
                  child: ChoiceChip(
                    label: Text(
                      category,
                      style: isSelected
                          ? theme.textTheme.bodyMedium?.copyWith(
                              color: theme.chipTheme.secondaryLabelStyle?.color,
                            )
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: theme.chipTheme.labelStyle?.color,
                            ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: BorderSide(
                        color: theme.chipTheme.labelStyle?.color ??
                            Colors.white, // 테두리 색상 빨간색으로 변경
                        width: 1, // 테두리 두께 조절
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      _onCategoryChanged(category, selected);
                    },
                    pressElevation: 0, // 터치 시 입체감 없애기
                    // splashColor: Colors.transparent,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            // 제외 검색어 선택
            Text(
              '기간 선택',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('사용자 지정'),
                        value: '사용자 지정',
                        groupValue: selectedPeriod,
                        onChanged: (String? value) {
                          setState(() {
                            selectedPeriod = value;
                            // 사용자 지정의 경우 초기값 설정
                            DateTime now = DateTime.now();
                            startDate = now;
                            endDate = now;
                          });
                        },
                        contentPadding: EdgeInsets.zero, // 패딩 제거
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8.0, // 수평 간격
                  // runSpacing: 4.0,
                  children: ['1주', '1달', '3달', '1년'].map((String period) {
                    return SizedBox(
                      width: 80.0,
                      child: RadioListTile<String>(
                        title: Text(period),
                        value: period,
                        groupValue: selectedPeriod,
                        onChanged: (String? value) {
                          setState(() {
                            selectedPeriod = value;
                            // 선택된 기간에 따라 시작 날짜와 끝 날짜 설정
                            DateTime now = DateTime.now();
                            switch (value) {
                              case '사용자 지정':
                                startDate = now;
                                endDate = now;
                                break;
                              case '1주':
                                startDate = now.subtract(Duration(days: 7));
                                endDate = now;
                                break;
                              case '1달':
                                startDate =
                                    DateTime(now.year, now.month - 1, now.day);
                                endDate = now;
                                break;
                              case '3달':
                                startDate =
                                    DateTime(now.year, now.month - 3, now.day);
                                endDate = now;
                                break;
                              case '1년':
                                startDate =
                                    DateTime(now.year - 1, now.month, now.day);
                                endDate = now;
                                break;
                              default:
                                startDate = null;
                                endDate = null;
                            }
                          });
                        },
                        visualDensity:
                            VisualDensity(horizontal: -3.0), // 수평 간격 줄이기
                        contentPadding: EdgeInsets.zero, // 패딩을 제거하여 간격 최소화
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
// 시작 날짜 선택
            Row(
              children: [
                Expanded(
                  child: Text(
                    '시작 날짜',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface),
                  ),
                ),
                Expanded(
                  child: Text(
                    '끝 날짜',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    startDate != null
                        ? DateFormat('yyyy-MM-dd').format(startDate!)
                        : '날짜를 선택하세요',
                    style: TextStyle(
                        fontSize: 16, color: theme.colorScheme.onSurface),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: Icon(Icons.calendar_today,
                        color: theme.colorScheme.onSurface),
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                // 끝 날짜 선택
                Expanded(
                  child: Text(
                    endDate != null
                        ? DateFormat('yyyy-MM-dd').format(endDate!)
                        : '날짜를 선택하세요',
                    style: TextStyle(
                        fontSize: 16, color: theme.colorScheme.onSurface),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: Icon(Icons.calendar_today,
                        color: theme.colorScheme.onSurface),
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
          mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
          children: [
            SizedBox(
              width: double.infinity,
              child: NavbarButton(
                buttonTitle: '저장',
                onPressed: () async {
                  await _saveSearchSettingsToLocal(); // 설정을 로컬에 저장
                  Navigator.pop(context, {
                    'selectedCategories': selectedCategories,
                    'startDate': startDate,
                    'endDate': endDate,
                  });
                },
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
}
